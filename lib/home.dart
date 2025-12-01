// lib/home.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

final user = FirebaseAuth.instance.currentUser;
final uid = user?.uid ?? 'unknown_user';

class NutritionDashboardApp extends StatelessWidget {
  const NutritionDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardPage();
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('營養追蹤儀表板'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/settings');// 前往設定頁
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // ====== 營養報告卡片 ======
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 日期與日曆
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text("2025.09.30",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          Text("📅"), // 暫代 icon
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Donut 圓環圖 (簡化成圓圈)
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.teal, width: 10),
                              ),
                            ),
                            Text(uid),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Text(
                        "成人每日建議營養攝取量",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: TextButton(
                          onPressed: () {},
                          child: const Text("設定健康目標 查看完整報告 →"),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 進度條
                      Column(
                        children: [
                          _progressItem("碳水", Colors.red),
                          _progressItem("蛋白質", Colors.blue),
                          _progressItem("脂肪", Colors.green),
                          _progressItem("卡路里", Colors.orange),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ====== 食物紀錄卡 ======
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _foodEntry("薯條", "123 kcal", "assets/french_fries.jpg"),
                      _foodEntry("飯", "123 kcal", "assets/rice.jpg"),
                      const SizedBox(height: 20),

                      // + 按鈕
                      Align(
                        alignment: Alignment.center,
                        child: FloatingActionButton(
                          onPressed: () {
                            _showActionMenu(context);
                          },
                          backgroundColor: Colors.teal,
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== 小元件們 =====
  static Widget _progressItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(label)),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: color.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _foodEntry(String name, String kcal, String imagePath) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 20, fontFamily: 'Cursive', color: Colors.black)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: AssetImage(imagePath),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kcal, style: const TextStyle(fontSize: 16)),
                  const Text("......", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static void _showActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text("照片圖庫"),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text("拍照"),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text("選擇檔案"),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
