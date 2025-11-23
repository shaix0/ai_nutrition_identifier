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
  bool? isAdminUser; // null = loading, true / false = result

  @override
  void initState() {
    super.initState();
    checkAdmin();
  }

  Future<void> checkAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => isAdminUser = false);
      return;
    }

    final idToken = await user.getIdToken(true);

    final response = await http.get(
      Uri.parse("http://127.0.0.1:8000/admin-only"),
      headers: {
        "Authorization": "Bearer $idToken",
      },
    );

    if (response.statusCode == 200) {
      setState(() => isAdminUser = true);
    } else {
      setState(() => isAdminUser = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading 狀態
    if (isAdminUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 不是管理員 → 退回上一頁
    if (isAdminUser == false) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("您沒有管理員權限"),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("返回"),
              ),
            ],
          ),
        ),
      );
    }

    // 是管理員 → 顯示真正管理頁面
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Page")),
      body: const Center(
        child: Text("Welcome to the Admin Page"),
      ),
    );
  }
}
