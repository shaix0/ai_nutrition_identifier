// 匯入 Flutter 的 Material UI 函式庫
import 'package:flutter/material.dart';
import 'dart:async'; // 管理StreamSubscription(監聽器的開關)
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fl_chart/fl_chart.dart'; //圓餅圖套件
import 'package:firebase_core/firebase_core.dart'; //Firebase核心
import 'package:cloud_firestore/cloud_firestore.dart'; // 引入Firestore資料庫功能
import 'firebase_options.dart'; // 引入Firebase設定檔(由FlutterFire CLI產生)
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert'; // 添加這行，為了 base64Decode
import 'dart:typed_data'; // 添加這行，為了 Uint8List

// 加註解來進行pull request
// ----------------------------------------------
// 資料模型區(Models)：定義資料的樣子
// ----------------------------------------------

// 每個"食物"的資料結構
// 對應Firebase的路徑：users/uid/analysis_records/{document}
class FoodItem {
  String id; // 文件ID(刪除、修改用的)
  DocumentReference? reference; // 用來記住這筆資料在 Firebase 的準確位置
  String name; // 食物名稱
  String calories; // 總熱量
  String imagePath; // 圖片網址(Firebase Storage URL或外部連結)
  String grams; // 總熱量
  String protein; // 總蛋白質
  String carbs; // 總碳水化合物
  String fat; // 總脂肪
  List<Ingredient> ingredients; // 食材清單(從子集合中去讀取)
  String remark; // 備註(使用者可編輯)
  String aiSuggestion; // AI分析建議(唯讀，不可編輯)

  FoodItem({
    this.reference,
    required this.id,
    required this.name,
    required this.calories,
    required this.imagePath,
    this.grams = '0', // 給預設值
    this.protein = '0',
    this.carbs = '0',
    this.fat = '0',
    required this.ingredients,
    this.remark = '',
    this.aiSuggestion = '',
  });
}

// 每個"食材"的資料結構
// 對應Firebase的路徑：users/uid/analysis_records/{document}/ingredients/{sub_doc}
class Ingredient {
  final String? id;
  final String name; // 食材名稱
  final double grams; // 重量
  final double calories; // 熱量
  final double carbs; // 碳水化合物
  final double protein; // 蛋白質
  final double fat; // 脂肪

  Ingredient({
    this.id,
    required this.name,
    required this.grams,
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
  });
}

// 用來暫存"今日總營養素"的小工具類別
class _DailyTotals {
  double calories = 0;
  double protein = 0;
  double carbs = 0;
  double fat = 0;
}

// ----------------------------------------------
// 首頁(儀表板+列表)
// ----------------------------------------------

class NutritionHomePage extends StatefulWidget {
  const NutritionHomePage({super.key});

  @override
  State<NutritionHomePage> createState() => _NutritionHomePageState();
}

class _NutritionHomePageState extends State<NutritionHomePage> {
  // 狀態變數
  late DateTime _selectedDate; // 目前選到的日期
  final ImagePicker _picker = ImagePicker();
  // Firebase監聽控制器(用來切換日期時關閉舊連線)
  StreamSubscription? _foodSubscription;

  // ！！！每日營養目標(目前根據國人膳食營養素參考攝取量 / 19-30歲 / 女性)！！！
  final double _targetCalories = 2050; // 大卡
  final double _targetProtein = 50; // 克
  final double _targetCarbs = 130; // 克
  // 脂肪無RDA，採AMDR 20-30% 。此處取 25% * 2050大卡 / 9 = 57克
  final double _targetFat = 57; // 克 (由AMDR 20-30%推算)

  // UI顯示用的資料清單(會隨著Firebase更新而自動變動)
  List<FoodItem> _foodList = [];
  bool _isLoading = true; // 是否正在讀取資料

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    // 呼叫函式來處理登入邏輯
    _checkLoginAndListen();
  }

  // 負責處理匿名登入
  Future<void> _checkLoginAndListen() async {
    User? user = FirebaseAuth.instance.currentUser;

    // 如果目前沒有登入使用者 (第一次開啟App)
    if (user == null) {
      try {
        print("系統：偵測到未登入，正在進行匿名登入...");
        // 這行指令會向 Firebase 請求一個隨機的匿名 UID
        UserCredential userCredential = await FirebaseAuth.instance
            .signInAnonymously();
        user = userCredential.user;
        print("系統：匿名登入成功！UID: ${user?.uid}");
      } catch (e) {
        print("系統：登入失敗: $e");
      }
    } else {
      print("系統：已登入，UID: ${user.uid}");
    }

    // 登入完成後，才開始監聽資料
    if (user != null) {
      _listenToFirebaseData(); // 把 UID 傳進去
    }
  }

  // 此區域有改!!!
  // 移除參數，改用 _selectedDate 進行精準查詢
  void _listenToFirebaseData() {
    // 1. 切斷舊的連線，避免重複監聽
    _foodSubscription?.cancel();

    print("系統：切換日期至 ${_selectedDate.toString().split(' ')[0]}");
    print("系統：正在向 Firebase 請求該日期的資料...");

    // 2. 設定當天的「開始時間」與「結束時間」
    // 例如：2025-11-24 00:00:00.000
    final DateTime startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      0,
      0,
      0,
    );
    // 例如：2025-11-24 23:59:59.999
    final DateTime endOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      23,
      59,
      59,
      999,
    );

    // 3. 建立帶有時間範圍過濾的查詢
    _foodSubscription = FirebaseFirestore.instance
        .collectionGroup('analysis_records')
        //  關鍵：只抓取 created_at 介於這段時間的資料
        .where('created_at', isGreaterThanOrEqualTo: startOfDay)
        .where('created_at', isLessThanOrEqualTo: endOfDay)
        .snapshots()
        .listen(
          (snapshot) async {
            List<FoodItem> newFoodList = [];

            try {
              // 4. 因為 Firebase 已經幫我們篩選好日期了，這裡直接讀取即可
              // 不需要再寫 if (!isSameDay) continue; 了！
              for (var doc in snapshot.docs) {
                var data = doc.data();

                // 過濾垃圾資料 "string"
                String foodName = data['食物名'] ?? '未命名';
                if (foodName == 'string' || foodName == '未命名') continue;

                // --- 以下是原本的讀取邏輯 (直接複製您的原本代碼即可) ---
                String docId = doc.id;
                String suggestion = data['AI分析建議'] ?? '';
                String imgUrl =
                    data['圖片_base64'] ?? data['圖片網址'] ?? ''; // 12/1有改

                List<Ingredient> ingredientsList = [];
                double totalGrams = 0;
                double totalCalories = 0;
                double totalProtein = 0;
                double totalCarbs = 0;
                double totalFat = 0;

                try {
                  var ingredientSnapshot = await doc.reference
                      .collection('ingredients')
                      .get();
                  for (var ingDoc in ingredientSnapshot.docs) {
                    var ingData = ingDoc.data();
                    double g = _parseToDouble(ingData['重量(g)']);
                    double cal = _parseToDouble(ingData['熱量(kcal)']);
                    double p = _parseToDouble(ingData['蛋白質(g)']);
                    double c = _parseToDouble(ingData['碳水化合物(g)']);
                    double f = _parseToDouble(ingData['脂肪(g)']);
                    String name = ingData['食材名'] ?? '未知食材';

                    totalGrams += g;
                    totalCalories += cal;
                    totalProtein += p;
                    totalCarbs += c;
                    totalFat += f;

                    ingredientsList.add(
                      Ingredient(
                        id: ingDoc.id,
                        name: name,
                        grams: g,
                        calories: cal,
                        carbs: c,
                        protein: p,
                        fat: f,
                      ),
                    );
                  }
                } catch (e) {
                  print("讀取食材錯誤: $e");
                }

                newFoodList.add(
                  FoodItem(
                    reference: doc.reference,
                    id: docId,
                    name: foodName,
                    calories: '${totalCalories.toStringAsFixed(0)} 大卡',
                    imagePath: imgUrl,
                    grams: totalGrams.toStringAsFixed(1),
                    protein: totalProtein.toStringAsFixed(1),
                    carbs: totalCarbs.toStringAsFixed(1),
                    fat: totalFat.toStringAsFixed(1),
                    ingredients: ingredientsList,
                    remark: data['備註'] ?? '',
                    aiSuggestion: suggestion,
                  ),
                );
                // --- 原本邏輯結束 ---
              }
            } catch (e) {
              print("處理資料錯誤: $e");
            }

            if (mounted) {
              setState(() {
                _foodList = newFoodList;
                _isLoading = false; // 讀取完成，關閉轉圈
              });
            }
          },
          // 加上錯誤監聽
          onError: (error) {
            print("Firebase 查詢錯誤: $error");
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        );
  }
  // 以上有改

  // 把任何形態的數字轉乘double，防止資料庫格式錯誤導致App崩潰
  double _parseToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _pickImage(ImageSource source) async {
    // 呼叫 image_picker 的 pickImage 方法
    // 網頁版會開啟檔案總管，並篩選圖片
    final XFile? image = await _picker.pickImage(source: source);

    // XFile? 表示 image 可能是 XFile 或 null (如果使用者取消選擇)
    if (image != null) {
      // 如果有選到
      print('成功選取照片！');
      print('照片路徑 (在網頁上是 blob URL): ${image.path}');
    } else {
      // 如果使用者按了「取消」
      print('使用者取消選取');
    }
  }

  // 計算目前所有食物的總營養(左邊圓餅圖使用)
  _DailyTotals _calculateCurrentTotals() {
    final totals = _DailyTotals();
    // 迭代 _foodList 中的每一個食物
    for (final item in _foodList) {
      // 從 FoodItem 中讀取字串並轉換為 double
      final calString = item.calories.replaceAll(' 大卡', '');
      totals.calories += double.tryParse(calString) ?? 0;
      totals.protein += double.tryParse(item.protein) ?? 0;
      totals.carbs += double.tryParse(item.carbs) ?? 0;
      totals.fat += double.tryParse(item.fat) ?? 0;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 157, 198, 194),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/settings');// 前往設定頁
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      // 解決Overflow的關鍵：使用 Column+Expanded 限制高度
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          // 使用 LayoutBuilder 判斷螢幕寬度
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 如果螢幕寬度小於 900 像素，就改成垂直堆疊 (手機/平板直立模式)
              if (constraints.maxWidth < 900) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, // 讓 Column 僅佔用其內容所需的垂直空間
                    children: [
                      // 左邊的圓餅圖和進度條 (移除 Expanded/Flex)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _buildLeftColumn(context),
                      ),
                      const SizedBox(height: 16),
                      // 右邊的歷史紀錄 (移除 Expanded/Flex)
                      _buildRightColumn(context),
                    ],
                  ),
                );
              }

              // 如果螢幕寬度夠大 (>= 900 像素)，則維持左右並排
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左邊(圓餅圖)
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: _buildLeftColumn(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 右邊(歷史紀錄)
                  Expanded(flex: 2, child: _buildRightColumn(context)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // 左邊UI
  Widget _buildLeftColumn(BuildContext context) {
    // 在build時自動計算總合
    final _DailyTotals currentTotals = _calculateCurrentTotals();

    // 計算百分比(0.0-1.0之間)
    // 加上 .clamp(0, 1) 確保百分比不會超過 100% (不會溢出進度條)
    final double calPercent = (currentTotals.calories / _targetCalories).clamp(
      0,
      1,
    );
    final double proteinPercent = (currentTotals.protein / _targetProtein)
        .clamp(0, 1);
    final double carbPercent = (currentTotals.carbs / _targetCarbs).clamp(0, 1);
    final double fatPercent = (currentTotals.fat / _targetFat).clamp(0, 1);

    // 計算圓餅圖的占比
    // 從 currentTotals (單位: g) 轉換成熱量 (單位: kcal)
    final double proteinCalories = currentTotals.protein * 4;
    final double carbCalories = currentTotals.carbs * 4;
    final double fatCalories = currentTotals.fat * 9;
    // 加總"巨量營養素"的總熱量
    final double totalMacroCalories =
        proteinCalories + carbCalories + fatCalories;
    // 計算各自在環圈圖中的佔比 (0.0 ~ 1.0)
    // 處理 totalMacroCalories 為 0 的情況 (避免除以零)
    final double proteinRingPercent = totalMacroCalories == 0
        ? 0
        : proteinCalories / totalMacroCalories;
    final double carbRingPercent = totalMacroCalories == 0
        ? 0
        : carbCalories / totalMacroCalories;
    final double fatRingPercent = totalMacroCalories == 0
        ? 0
        : fatCalories / totalMacroCalories;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期選擇工具
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "${_selectedDate.year}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.day.toString().padLeft(2, '0')}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.calendar_month_outlined,
                    color: Colors.grey[700],
                  ),
                  onPressed: () async {
                    final DateTime now = DateTime.now();
                    final DateTime fiveYearsAgo = DateTime(
                      now.year - 5,
                      now.month,
                      now.day,
                    );

                    // 彈出日曆
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate.isAfter(now)
                          ? now
                          : _selectedDate,
                      firstDate: fiveYearsAgo,
                      lastDate: now,
                    );

                    if (picked != null && picked != _selectedDate) {
                      setState(() {
                        _selectedDate = picked;
                        _isLoading = true; // 切換日期時，先轉圈圈
                      });

                      // 選完日期後，重新去Firebase中抓取那天的資料
                      // --- 修正開始 ---
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        // 已經移除 UID 參數，改用全域查詢
                        _listenToFirebaseData();
                      }
                      // --- 修正結束 ---
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),

            // 圓餅圖
            Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 0,
                        centerSpaceRadius: 80,
                        sections: [
                          PieChartSectionData(
                            color: Colors.blue,
                            value: proteinRingPercent * 100,
                            radius: 40,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            color: Colors.green,
                            value: carbRingPercent * 100,
                            radius: 40,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            color: Colors.orange,
                            value: fatRingPercent * 100,
                            radius: 40,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            color: Colors.grey[200],
                            value: totalMacroCalories == 0
                                ? 100
                                : (100 -
                                          (proteinRingPercent +
                                                  carbRingPercent +
                                                  fatRingPercent) *
                                              100)
                                      .clamp(0, 100),
                            radius: 20,
                            showTitle: false,
                          ),
                        ],
                      ),
                    ),
                    Center(
                      child: totalMacroCalories == 0
                          ? Text(
                              '尚未攝取\n(0%)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '蛋白質: ${(proteinRingPercent * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  '碳水: ${(carbRingPercent * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  '脂肪: ${(fatRingPercent * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            /* Row(
              children: [
                const Text(
                  '成人每日建議營養攝取量',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    print('設定健康目標以查看完整報告');
                  },
                  style: ButtonStyle(
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.pressed)) {
                        return Colors.red.shade900;
                      }
                      return Colors.red;
                    }),
                  ),
                  child: const Text(
                    '設定健康目標以查看完整報告',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),*/
            Row(
              children: [
                Expanded(
                  // 添加 Expanded
                  child: Text(
                    '成人每日建議營養攝取量',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8), // 添加一些間距
                TextButton(
                  onPressed: () {
                    print('設定健康目標以查看完整報告');
                  },
                  style: ButtonStyle(
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.pressed)) {
                        return Colors.red.shade900;
                      }
                      return Colors.red;
                    }),
                  ),
                  child: const Text(
                    '設定目標', // 缩短文本
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),

            //新增解決溢出問題
            const SizedBox(height: 15),

            // 營養進度條
            _buildNutrientBar('熱量 (Calories)', Colors.red, calPercent),
            const SizedBox(height: 15),
            _buildNutrientBar('蛋白質 (Protein)', Colors.blue, proteinPercent),
            const SizedBox(height: 15),
            _buildNutrientBar('碳水化合物 (Carbs)', Colors.green, carbPercent),
            const SizedBox(height: 15),
            _buildNutrientBar('脂肪 (Fat)', Colors.orange, fatPercent),
          ],
        ),
      ),
    );
  }

  // 營養進度條 (輔助)
  Widget _buildNutrientBar(String label, Color color, double percentage) {
    final String percentageString = '${(percentage * 100).toStringAsFixed(0)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4), // 加上一點間距
        // 把進度條和 % 數放在一個Row裡面
        Row(
          children: [
            // 1. 進度條
            Expanded(
              // 讓進度條填滿所有可用空間
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: percentage,
                  minHeight: 15,
                  backgroundColor: Colors.grey[300],
                  color: color,
                ),
              ),
            ),

            // 2. 百分比文字
            const SizedBox(width: 12), // 進度條和文字的間距
            Text(
              percentageString,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 右邊UI
  Widget _buildRightColumn(BuildContext context) {
    return Card(
      elevation: 5,
      shadowColor: Colors.grey.withOpacity(0.5),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              '今日紀錄',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Divider(), // 標題下的分隔線

            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  ) // 如果正在讀取，顯示轉圈
                : _foodList.isEmpty
                ? const Center(child: Text("還沒有紀錄喔！"))
                : ListView.builder(
                    shrinkWrap: true, // 讓 ListView 僅佔用內容所需的空間
                    physics: const NeverScrollableScrollPhysics(), // 禁用內層捲動
                    padding: const EdgeInsets.only(top: 8.0),
                    itemCount: _foodList.length,
                    itemBuilder: (context, index) {
                      final item = _foodList[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _buildFoodItem(context, item),
                      );
                    },
                  ),

            // 新增按鈕
            Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton(
                onPressed: null,
                child: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 單一食物項目
  Widget _buildFoodItem(BuildContext context, FoodItem item) {
    print("檢查圖片資料：[${item.imagePath}]");

    // 解碼 Base64 圖片（如果存在）
    Uint8List? imageBytes;
    Widget imageWidget;

    // 檢查是否是 Base64 圖片
    if (item.imagePath.startsWith('data:image') ||
        (item.imagePath.length > 1000 && !item.imagePath.startsWith('http'))) {
      // 可能是 Base64 圖片
      try {
        final base64String = item.imagePath.replaceFirst(
          'data:image/jpeg;base64,',
          '',
        );
        imageBytes = base64Decode(base64String);
        imageWidget = Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          width: 60,
          height: 60,
        );
        print('✅ 顯示 Base64 圖片');
      } catch (e) {
        print('❌ Base64 解碼錯誤: $e');
        imageWidget = _buildImagePlaceholder();
      }
    } else if (item.imagePath.startsWith('http')) {
      // 網路圖片
      imageWidget = Image.network(
        item.imagePath,
        fit: BoxFit.cover,
        width: 60,
        height: 60,
        errorBuilder: (context, error, stackTrace) {
          return _buildImagePlaceholder();
        },
      );
    } else {
      // 預設圖標
      imageWidget = _buildImagePlaceholder();
    }

    return InkWell(
      onTap: () async {
        // 點擊後跳出彈窗顯示詳情
        final FoodItem? updatedItem = await _showFoodEditDialog(
          context,
          item,
          _selectedDate,
        );
        if (updatedItem != null) {
          // TODO: 如果之後要實作「修改資料」，要與 Firebase update 連接
          print("修改功能預留中");
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 60,
                height: 60,
                color: Colors.grey[200],
                child: imageWidget,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name, // 顯示名稱
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    item.calories, // 顯示大卡
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // 垃圾桶按鈕的修正區塊
            SizedBox(
              // 解決水平溢位 (RenderFlex Overflow)
              width: 40, // 限制按鈕的最小寬度
              child: IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color.fromARGB(255, 26, 24, 23),
                ),
                onPressed: () {
                  // 點擊垃圾桶標示，跳出確認 Dialog
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: const Text('刪除'),
                        content: Text('您確定要永久刪除「${item.name}」嗎？'),
                        actions: <Widget>[
                          // 取消按鈕
                          TextButton(
                            child: const Text('取消'),
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                          ),
                          // 確認按鈕
                          TextButton(
                            child: const Text('確認'),
                            onPressed: () async {
                              // 1. 先關閉彈窗
                              Navigator.of(dialogContext).pop();

                              // 2. 執行 Firebase 刪除指令 (使用 FoodItem 儲存的 reference)
                              if (item.reference != null) {
                                try {
                                  await item.reference!.delete();
                                  print("已成功從 Firebase 刪除文件: ${item.name}");
                                  // 💡 UI 會因為 Firebase Stream 自動更新！
                                } catch (e) {
                                  print("刪除失敗: $e");
                                  // 可選：顯示一個 Snackbar 提示使用者刪除失敗
                                }
                              }
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 圖片佔位符
  Widget _buildImagePlaceholder() {
    return const Icon(Icons.restaurant, color: Colors.grey);
  }

  Future<FoodItem?> _showFoodEditDialog(
    BuildContext context,
    FoodItem item,
    DateTime selectedDate,
  ) {
    return showDialog<FoodItem>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Container(
            width: 400, // 限制寬度，讓它變成「縱向」
            padding: const EdgeInsets.all(24.0),
            // Dialog的內容在FoodEditDialogContent這個Widget裡
            child: FoodEditDialogContent(
              item: item,
              selectedDate: selectedDate,
            ),
          ),
        );
      },
    );
  }
} // 結束 _NutritionHomePageState

// ----------------------------------------------
// 彈出視窗內容(詳情頁面)
// ----------------------------------------------

class FoodEditDialogContent extends StatefulWidget {
  // 接收從主頁面傳來的「原始」食物資料
  final FoodItem item;
  final DateTime selectedDate;

  const FoodEditDialogContent({
    super.key,
    required this.item,
    required this.selectedDate,
  });

  @override
  State<FoodEditDialogContent> createState() => _FoodEditDialogContentState();
}

class _FoodEditDialogContentState extends State<FoodEditDialogContent> {
  late TextEditingController _nameController;
  late TextEditingController _gramController;
  late TextEditingController _calController;
  late TextEditingController _proteinController;
  late TextEditingController _carbController;
  late TextEditingController _fatController;
  late TextEditingController _remarksController;

  // 宣告_ingredients
  late List<Ingredient> _ingredients;
  // 宣告_isEditingName並給予初始值
  bool _isEditingName = false;
  // 用來暫存「準備要刪除」的食材 ID
  final List<String> _ingredientsToDelete = [];

  // 建立一個可自動計算所有食材總和的函式
  void _calculateTotals() {
    // 1. 先歸零
    double totalGrams = 0;
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    // 2. 迭代 _ingredients List 進行加總
    for (final ingredient in _ingredients) {
      totalGrams += ingredient.grams;
      totalCalories += ingredient.calories;
      totalProtein += ingredient.protein;
      totalCarbs += ingredient.carbs;
      totalFat += ingredient.fat;
    }

    // 3. 更新 Controller 的文字
    // (熱量用整數計算，其他會計算到小數點後1位)
    _gramController.text = totalGrams.toStringAsFixed(1);
    _calController.text = totalCalories.toStringAsFixed(0);
    _proteinController.text = totalProtein.toStringAsFixed(1);
    _carbController.text = totalCarbs.toStringAsFixed(1);
    _fatController.text = totalFat.toStringAsFixed(1);
  }

  @override
  void initState() {
    super.initState();
    // 在 Widget 建立時，用傳進來的資料初始化所有 Controller
    _nameController = TextEditingController(text: widget.item.name);
    _gramController = TextEditingController();
    _calController = TextEditingController();
    _proteinController = TextEditingController();
    _carbController = TextEditingController();
    _fatController = TextEditingController();
    _remarksController = TextEditingController(text: widget.item.remark);

    _ingredients = List.from(widget.item.ingredients);
    _calculateTotals(); // 呼叫計算函式，填入初始總和
  }

  @override
  void dispose() {
    // dispose 所有 Controller
    _nameController.dispose();
    _gramController.dispose();
    _calController.dispose();
    _proteinController.dispose();
    _carbController.dispose();
    _fatController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  // 輔助函式：建立一個帶有標籤的輸入框
  Widget _buildLabeledTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.number,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: TextField(
            controller: controller, // 綁定Controller
            keyboardType: keyboardType,
            enabled: enabled,

            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16, // 字體大小
            ),

            decoration: InputDecoration(
              hintText: '0',
              filled: !enabled,
              fillColor: enabled ? Colors.transparent : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientRow(Ingredient ingredient, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：食材名稱
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ingredient.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                // 視覺調整(讓按鈕更貼齊)
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: Colors.grey[400],
                  size: 20,
                ),
                onPressed: () {
                  // 點擊時，在視窗中暫時刪除食材(目前還不會真正刪除Firebase中的資料)
                  setState(() {
                    // 刪除前，如果它有 ID，就加入「待刪除清單」
                    if (ingredient.id != null) {
                      _ingredientsToDelete.add(ingredient.id!);
                    }
                    _ingredients.removeAt(index);
                    // 刪除後會立刻重新計算總合
                    _calculateTotals();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 4),

          // 第二行：克數與熱量
          Text(
            '${ingredient.grams} g • ${ingredient.calories} kcal',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),

          // 第三行：三個營養素(分別有各自代表的符號)
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildMacroInfo('🌾', ingredient.carbs), // 碳水化合物
              const SizedBox(width: 16),
              _buildMacroInfo('🥩', ingredient.protein), // 蛋白質
              const SizedBox(width: 16),
              _buildMacroInfo('🧈', ingredient.fat), // 脂肪
            ],
          ),
          Divider(height: 16, color: Colors.grey[300]), // 加分隔線
        ],
      ),
    );
  }

  Widget _buildMacroInfo(String icon, double value) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 4),
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // SingleChildScrollView可確保鍵盤彈出時內容不會溢位
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min, // 讓Column符合內容高度
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 圖片與名稱
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[200],
                  // 顯示網路圖片
                  child: widget.item.imagePath.startsWith('http')
                      ? Image.network(
                          widget.item.imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                        )
                      : const Icon(Icons.restaurant, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _isEditingName
                              ? SizedBox(
                                  height: 40,
                                  child: TextField(
                                    controller: _nameController,
                                    autofocus: true,
                                    decoration: const InputDecoration(
                                      hintText: '食物名稱',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : Text(
                                  _nameController.text,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                        // 編輯/完成按鈕
                        IconButton(
                          icon: Icon(
                            _isEditingName ? Icons.check : Icons.edit, // 切換圖示
                            color: Colors.grey[700],
                            size: 20,
                          ),
                          onPressed: () {
                            // 點擊圖示時，切換狀態
                            setState(() {
                              _isEditingName = !_isEditingName;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 時間
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          // 使用 widget.selectedDate 來動態格式化
                          "${widget.selectedDate.year}/${widget.selectedDate.month.toString().padLeft(2, '0')}/${widget.selectedDate.day.toString().padLeft(2, '0')}",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2. 數值顯示區
          Row(
            children: [
              Expanded(
                child: _buildLabeledTextField(
                  '總克數 (g)',
                  _gramController,
                  enabled: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildLabeledTextField(
                  '熱量 (kcal)',
                  _calController,
                  enabled: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildLabeledTextField(
                  '蛋白質 (g)',
                  _proteinController,
                  enabled: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildLabeledTextField(
                  '碳水化合物 (g)',
                  _carbController,
                  enabled: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildLabeledTextField(
                  '脂肪 (g)',
                  _fatController,
                  enabled: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 3. AI營養分析建議
          const Text(
            'AI 總結食材清單',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),

          // 食材清單
          ListView.builder(
            shrinkWrap: true, // 讓 ListView 符合內容高度
            physics:
                const NeverScrollableScrollPhysics(), // 由 SingleChildScrollView 滾動
            itemCount: _ingredients.length,
            itemBuilder: (context, index) {
              return _buildIngredientRow(_ingredients[index], index);
            },
          ),

          const Text(
            'AI分析建議',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),

          Container(
            width: double.infinity, // 填滿寬度
            padding: const EdgeInsets.all(12), // 內距，讓文字不要貼著框
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black), //黑色邊框
              borderRadius: BorderRadius.circular(12), // 邊框變為圓角
            ),
            child: Text(
              widget.item.aiSuggestion.isEmpty
                  ? "暫無 AI 分析建議"
                  : widget.item.aiSuggestion,
              style: const TextStyle(
                color: Colors.black87,
                height: 1.5,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 4. 使用者備註
          const Text(
            '備註',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _remarksController, // 綁定新的Controller
            decoration: InputDecoration(
              hintText: '新增備註...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            maxLines: 3, // 可以輸入多行
          ),
          const SizedBox(height: 24),

          // 5. 取消/確定按鈕
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 157, 198, 194),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('取消'),
                onPressed: () {
                  // 關閉 Dialog，回傳 null
                  Navigator.of(context).pop();
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 157, 198, 194),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('確定'),
                // 連動 Firebase 的核心邏輯
                onPressed: () async {
                  if (widget.item.reference != null) {
                    try {
                      // 1. 從資料庫刪除食材
                      for (String deleteId in _ingredientsToDelete) {
                        print("正在從資料庫刪除食材 ID: $deleteId");
                        await widget.item.reference!
                            .collection('ingredients')
                            .doc(deleteId)
                            .delete();
                      }

                      // 2. 更新主文件 (名稱、備註)
                      // 注意：如果您的資料庫有 'total_calories' 等欄位，請在這裡加上更新
                      await widget.item.reference!.update({
                        '食物名': _nameController.text,
                        '備註': _remarksController.text,
                        'total_calories':
                            double.tryParse(_calController.text) ?? 0,
                        'total_protein':
                            double.tryParse(_proteinController.text) ?? 0,
                        'total_carbs':
                            double.tryParse(_carbController.text) ?? 0,
                        'total_fat': double.tryParse(_fatController.text) ?? 0,
                        // 強制觸發更新的時間戳記，確保 App 一定會收到通知
                        'last_updated': FieldValue.serverTimestamp(),
                      });

                      print("資料庫更新成功！");
                    } catch (e) {
                      print("更新失敗: $e");
                    }
                  }
                  if (mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}