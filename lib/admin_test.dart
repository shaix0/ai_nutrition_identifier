import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AdminTestPage extends StatelessWidget {
  const AdminTestPage({super.key});

  Future<void> callAdminApi() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("❌ 使用者未登入");
      return;
    }

    final token = await user.getIdToken(true); // 確保拿到最新 token
    print("🔥 要送出的 token: $token");

    final response = await http.get(
      Uri.parse("http://127.0.0.1:8000/admin"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("🔵 後端狀態碼: ${response.statusCode}");
    print("🔵 後端回傳內容: ${response.body}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Admin 測試")),
      body: Center(
        child: ElevatedButton(
          onPressed: callAdminApi,
          child: Text("呼叫 Admin API"),
        ),
      ),
    );
  }
}
