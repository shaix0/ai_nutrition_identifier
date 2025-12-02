// settings.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // UI-only states
  bool notifications = true;
  bool darkPreview = false;
  String preferredUnit = 'metric';

  String? gender;
  int? age;
  double? height;
  double? weight;

  DocumentReference<Map<String, dynamic>>? userDoc;

  @override
  void initState() {
    super.initState();
    _setupUserDoc();
  }

  Future<void> _setupUserDoc() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      userDoc = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      await _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    if (userDoc == null) return;
    try {
      final snapshot = await userDoc!.get();
      if (snapshot.exists) {
        final data = snapshot.data()!;
        setState(() {
          // 只初始化未輸入的欄位，保留本地 UI 覆蓋資料
          gender ??= data['gender'];
          age ??= data['age'] != null ? (data['age'] as num).toInt() : null;
          height ??= data['height'] != null ? (data['height'] as num).toDouble() : null;
          weight ??= data['weight'] != null ? (data['weight'] as num).toDouble() : null;
        });
      }
    } catch (e) {
      print('讀取個人資料失敗: $e');
    }
  }

  // 登出功能
  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();

      // 清空 UI 狀態
      setState(() {
        gender = null;
        age = null;
        height = null;
        weight = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已登出')),
      );

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          content: const Text('登出成功'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登出失敗：$e')),
      );
    }
  }

  // 修改密碼
  void _confirmResetPassword() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || currentUser.email == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Text("系統將寄出密碼重設信件至：\n${currentUser.email}\n\n是否繼續？"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("取消"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("確定"),
            ),
          ],
        );
      },
    );

    if (result == true) {
      _sendPasswordResetEmail();
    }
  }

  void _sendPasswordResetEmail() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("無法取得使用者 Email")),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: currentUser!.email!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("已寄出密碼重設信至：${currentUser.email}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("寄信失敗，請稍後再試")),
      );
    }
  }

  Future<void> _saveUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('尚未登入，無法儲存資料')),
      );
      return;
    }

    userDoc ??= FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

    try {
      await userDoc!.set({
        'gender': gender,
        'age': age,
        'height': height,
        'weight': weight,
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已儲存健康資料')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存失敗: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primaryDeep = cs.primary;
    final primaryLight = cs.background;

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Card
              StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  final isLoggedIn = user != null;

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: primaryLight,
                            shape: BoxShape.circle,
                            border: Border.all(color: primaryDeep.withOpacity(0.2)),
                          ),
                          child: Icon(Icons.person, size: 38, color: primaryDeep),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isLoggedIn ? user!.email! : "未登入使用者",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              if (isLoggedIn)
                                GestureDetector(
                                  onTap: _confirmResetPassword,
                                  child: Text(
                                    '✎ 修改密碼',
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              if (!isLoggedIn)
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushNamed(context, "/auth");
                                  },
                                  child: Text(
                                    '> 登入/註冊帳號',
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 18),
              const Text(
                '個人健康資料',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _sectionLabel('性別'),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            value: 'male',
                            groupValue: gender,
                            onChanged: (v) => setState(() => gender = v),
                            title: const Text('男'),
                            activeColor: primaryDeep,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            value: 'female',
                            groupValue: gender,
                            onChanged: (v) => setState(() => gender = v),
                            title: const Text('女'),
                            activeColor: primaryDeep,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    _sectionLabel('年齡'),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '請輸入年齡'),
                      onChanged: (v) => setState(() => age = int.tryParse(v)),
                      controller: TextEditingController(text: age?.toString()),
                    ),
                    const SizedBox(height: 16),

                    _sectionLabel('身高 (cm)'),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '請輸入身高'),
                      onChanged: (v) => setState(() => height = double.tryParse(v)),
                      controller: TextEditingController(text: height?.toString()),
                    ),
                    const SizedBox(height: 16),

                    _sectionLabel('體重 (kg)'),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '請輸入體重'),
                      onChanged: (v) => setState(() => weight = double.tryParse(v)),
                      controller: TextEditingController(text: weight?.toString()),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveUserData,
                      child: const Text('儲存設定'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              _sectionTitle('應用資訊'),
              _infoRow('版本', '1.0.0'),
              _infoRow('條款', '隱私權政策與使用條款'),

              const SizedBox(height: 20),
              StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  if (user == null) return const SizedBox.shrink();

                  return Column(
                    children: [
                      const SizedBox(height: 20),
                      Center(
                        child: TextButton(
                          onPressed: logout,
                          child: const Text('登出'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ===== UI Components =====
  Widget _sectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );

  Widget _infoRow(String title, String value) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(value, style: TextStyle(color: cs.primary)),
        ],
      ),
    );
  }
}
