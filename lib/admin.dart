// lib/admin.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool? isAdmin;
  String? adminEmail;

  List<dynamic> users = [];
  List<dynamic> filteredUsers = [];

  Map<String, dynamic>? selectedUser; // 🔴 詳細資料顯示（右側同區域）

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  // 🔵 搜尋 + 過濾
  final TextEditingController searchController = TextEditingController();
  bool filterAdmin = false;
  bool filterAnonymous = false;

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
      Uri.parse("$apiBaseUrl/admin/verify_admin"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      setState(() => isAdmin = true);
      _getUsers();
    } else {
      setState(() => isAdmin = false);
    }
  }

  Future<void> _getUsers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await user.getIdToken();
    final response = await http.get(
      Uri.parse("$apiBaseUrl/admin/get_users"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      users = data["users"];
      _applyFilters(); // 🔵 自動套用搜尋/過濾
    }
  }

  // 🔵 搜尋、篩選邏輯（Email / UID）
  void _applyFilters() {
    final keyword = searchController.text.trim().toLowerCase();

    filteredUsers = users.where((u) {
      // 搜尋 email 或 uid
      final email = (u["email"] ?? "").toLowerCase();
      final uid = (u["uid"] ?? "").toLowerCase();

      bool matchKeyword = keyword.isEmpty ||
          email.contains(keyword) ||
          uid.contains(keyword);

      // 篩選 admin
      bool matchAdmin = !filterAdmin || (u["admin"] == true);

      // 篩選匿名
      bool matchAnon = !filterAnonymous || (u["email"] == null);

      return matchKeyword && matchAdmin && matchAnon;
    }).toList();

    setState(() {});
  }

  // 🔵 刪除使用者
  Future<void> deleteUser(String uid) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
    if (token == null) return;

    final resp = await http.delete(
      Uri.parse("$apiBaseUrl/admin/delete_user/$uid"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (resp.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("已刪除使用者 $uid")),
      );
      _getUsers();
      setState(() => selectedUser = null);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("刪除失敗")),
      );
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
      backgroundColor: cs.primary,
      body: Row(
        children: [
          // 左側 Sidebar —— 保持不變
          _buildSidebar(cs),

          // 右側使用者列表 + 詳細資料
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(cs),      // 🔵 搜尋 + 過濾
                  const SizedBox(height: 12),

                  Expanded(
                    child: Row(
                      children: [
                        // 🔵 左：搜尋結果列表
                        Expanded(
                          flex: 2,
                          child: _buildUserList(cs),
                        ),

                        const SizedBox(width: 16),

                        // 🔵 右：詳細資料
                        Expanded(
                          flex: 3,
                          child: _buildUserDetailPanel(cs),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------
  // 左側 Sidebar（你原本的）
  // ---------------------------
  Widget _buildSidebar(ColorScheme cs) {
    return SizedBox(
      width: 260,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _adminInfo(cs),

            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
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
            ),

            ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text("登出"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminInfo(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: cs.primary,
            child: Icon(Icons.person, color: cs.onPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("管理員", style: TextStyle(fontWeight: FontWeight.w600)),
                Text(adminEmail ?? "unknown",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ---------------------------
  // 搜尋 + 過濾
  // ---------------------------
  Widget _buildSearchBar(ColorScheme cs) {
    return Row(
      children: [
        // 搜尋框
        Expanded(
          child: TextField(
            controller: searchController,
            onChanged: (_) => _applyFilters(),
            decoration: InputDecoration(
              filled: true,
              fillColor: cs.surfaceVariant,
              hintText: "搜尋 Email / UID",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // 🔵 篩選：Admin
        FilterChip(
          label: const Text("Admin"),
          selected: filterAdmin,
          onSelected: (v) {
            setState(() {
              filterAdmin = v;
              _applyFilters();
            });
          },
        ),

        const SizedBox(width: 8),

        // 🔵 篩選：匿名
        FilterChip(
          label: const Text("匿名"),
          selected: filterAnonymous,
          onSelected: (v) {
            setState(() {
              filterAnonymous = v;
              _applyFilters();
            });
          },
        ),
      ],
    );
  }

  // ---------------------------
  // 使用者列表
  // ---------------------------
  Widget _buildUserList(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        itemCount: filteredUsers.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final u = filteredUsers[index];

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: cs.primary,
              child: Text(
                (u["email"] ?? "?")[0].toUpperCase(),
                style: TextStyle(color: cs.onPrimary),
              ),
            ),
            title: Text(u["email"] ?? "(匿名)"),
            subtitle: Text("UID: ${u["uid"]}"),
            trailing: Icon(Icons.chevron_right, color: cs.primary),
            onTap: () => _showUserDetail(context, u["uid"]), // 🔴 詳情顯示於右側
          );
        },
      ),
    );
  }


  // ---------------------------
  // 使用者詳細資料顯示（右側）
  // ---------------------------
  void _showUserDetail(BuildContext context, String uid) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
    if (token == null) return;

    final resp = await http.get(
      Uri.parse("$apiBaseUrl/admin/get_user/$uid"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (resp.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("取得使用者資料失敗")),
      );
      return;
    }

    final user = jsonDecode(resp.body);

    setState(() {
      selectedUser = user;
    });

  }

  Widget _buildUserDetailPanel(ColorScheme cs) {
    if (selectedUser == null) {
      return Center(child: Text("請選擇一位使用者"));
    }

    final u = selectedUser!;
    final meta = u["metadata"] ?? {};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("詳細資訊", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),

          Text("Email: ${u["email"] ?? "null"}"),
          Text("UID: ${u["uid"]}"),
          Text("Admin: ${u["admin"]}"),
          Text("Email 驗證: ${u["email_verified"]}"),
          Text(
            "註冊時間：${meta["creation_time"] != null
                ? DateFormat('yyyy/MM/dd').format(
                    DateTime.fromMillisecondsSinceEpoch(meta["creation_time"])
                  )
                : "未知"}"
          ),
          Text(
            "最後登入：${meta["last_sign_in_time"] != null
                ? DateFormat('yyyy/MM/dd').format(
                    DateTime.fromMillisecondsSinceEpoch(meta["last_sign_in_time"])
                  )
                : "未知"}"
          ),

          const Spacer(),

          // 🔴 刪除按鈕
          ElevatedButton.icon(
            icon: const Icon(Icons.delete),
            label: const Text("刪除使用者"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => deleteUser(u["uid"]),
          )
        ],
      ),
    );
  }
  
  // ---------------------------
  // 左側統計卡片（你原本的）
  // ---------------------------
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
              color: cs.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: cs.onPrimary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }
}
