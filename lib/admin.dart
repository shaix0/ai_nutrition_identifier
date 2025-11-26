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

    final response = await http.get(
      Uri.parse("http://127.0.0.1:8000/admin-only"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (!mounted) return;

    setState(() => isAdmin = response.statusCode == 200);
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

      return const Scaffold(); // 空白即可
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Admin Page")),
      body: const Center(child: Text("Welcome Admin")),
    );
  }
}
