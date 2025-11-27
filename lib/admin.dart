// lib/admin.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool? isAdmin;

  @override
  void initState() {
    super.initState();
    checkAdmin();
  }

  Future<void> checkAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => isAdmin = false);
      return;
    }

    await user.getIdToken(true); // <-- 強制刷新 token！

    final token = await user.getIdToken();

    final response = await http.post(
      Uri.parse("http://127.0.0.1:8000/auth/admin"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (!mounted) return;

    setState(() => isAdmin = response.statusCode == 200);
  }

  // 非 admin 使用者自動導回首頁
  @override
  Widget build(BuildContext context) {
    if (isAdmin == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (isAdmin == false) {
      Future.microtask(() {
        Navigator.pushReplacementNamed(context, "/");
      });

      return const Scaffold(); // 空白即可
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('管理頁'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // top stats
            Row(
              children: [
                Expanded(child: _statCard('使用者總數', '1,234', Icons.people, cs)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('上傳數', '5,678', Icons.upload_file, cs)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _statCard('活躍日', '87%', Icons.show_chart, cs)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('錯誤回報', '3', Icons.bug_report, cs)),
              ],
            ),
            const SizedBox(height: 18),

            // user list
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('使用者列表',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: 6,
                        separatorBuilder: (_, __) => const Divider(height: 12),
                        itemBuilder: (context, index) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: cs.primaryContainer,
                              child: Text(
                                'U${index + 1}',
                                style: TextStyle(color: cs.onPrimaryContainer),
                              ),
                            ),
                            title: Text('user${index + 1}@example.com'),
                            subtitle: Text('註冊：2025-09-${10 + index}'),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline, color: cs.primary),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('刪除使用者（模擬）'),
                                    content: const Text('此操作僅為示範，無實際刪除。'),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('取消')),
                                      TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('確定')),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 統計卡片元件
  Widget _statCard(
    String title,
    String value,
    IconData icon,
    ColorScheme cs,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}