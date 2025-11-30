// lib/admin.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool? isAdmin;
  String? adminEmail;
  List<dynamic> users = [];

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

    adminEmail = user.email;

    await user.getIdToken(true);
    final token = await user.getIdToken();

    final response = await http.get(
      Uri.parse("http://127.0.0.1:8000/admin/verify_admin"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      setState(() => isAdmin = true);
      _getUsers(); // 自動載入使用者列表
    } else {
      setState(() => isAdmin = false);
    }
  }

  Future<void> _getUsers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await user.getIdToken();
    final response = await http.get(
      Uri.parse("http://127.0.0.1:8000/admin/get_users"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        users = data["users"];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isAdmin == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (isAdmin == false) {
      Future.microtask(() {
        Navigator.pushReplacementNamed(context, "/");
      });
      return const Scaffold();
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("管理頁（${adminEmail ?? ''}）"),
        centerTitle: true,
      ),
      body: Row(
        children: [
          // -----------------------------
          // 左側：統計欄位
          // -----------------------------
          Container(
            width: 260,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -------------------------------------
                // 管理員資訊卡片（依你提供的樣式）
                // -------------------------------------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      // 頭像（替代你原本的 primaryLight/primaryDeep）
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.background.withOpacity(0.2)),
                        ),
                        child: Icon(
                          Icons.person,
                          color: cs.background,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 管理員 Email
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "管理員",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              adminEmail ?? "unknown",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // -------------------------------------
                // 統計卡片
                // -------------------------------------
                _statCard("使用者總數", "${users.length}", Icons.people, cs),
                const SizedBox(height: 14),
                _statCard("上傳數", "5,678", Icons.upload_file, cs),
                const SizedBox(height: 14),
                _statCard("活躍日", "87%", Icons.show_chart, cs),
                const SizedBox(height: 14),
                _statCard("錯誤回報", "3", Icons.bug_report, cs),
              ],
            ),
          ),

          const SizedBox(width: 20),

          // -----------------------------
          // 右側：使用者列表
          // -----------------------------
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
                  const Text(
                    '使用者列表',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const Divider(height: 12),
                      itemBuilder: (context, index) {
                        final u = users[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: cs.primaryContainer,
                            child: Text(
                              u["email"] != null
                                  ? u["email"][0].toUpperCase()
                                  : "?",
                              style:
                                  TextStyle(color: cs.onPrimaryContainer),
                            ),
                          ),
                          title: Text(u["email"] ?? "無 email"),
                          subtitle: Text("UID: ${u["uid"]}"),
                          onTap: () => _showUserDetail(context, u["uid"]),
                          trailing: Icon(Icons.chevron_right, color: cs.primary),
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
    );
  }

  // -------------------------------------------------------------
  // 使用者詳細資料 - 彈出視窗
  // -------------------------------------------------------------
  void _showUserDetail(BuildContext context, String uid) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("無法取得 token")),
      );
      return;
    }

    final url = Uri.parse("http://127.0.0.1:8000/admin/get_user/$uid");

    try {
      final resp = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      if (resp.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("取得使用者資料失敗：${resp.body}")),
        );
        return;
      }

      final user = jsonDecode(resp.body);

      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text("使用者詳細資料"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Email：${user["email"] ?? "無"}"),
                Text("UID：${user["uid"]}"),
                Text("權限：admin = ${user["admin"]}"),
                Text("email 驗證：${user["email_verified"]}"),
                const SizedBox(height: 10),
                Text("註冊時間：${user["metadata"]["creation_time"]}"),
                Text("最後登入：${user["metadata"]["last_sign_in_time"]}"),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("關閉"),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("錯誤：$e")),
      );
    }
  }

  /// 左側統計卡片
  Widget _statCard(String title, String value, IconData icon, ColorScheme cs) {
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
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
