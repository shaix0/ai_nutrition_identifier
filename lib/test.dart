import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth_test_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Auth Test',
      home: AuthTestPage(),
    );
  }
}

// 登入 Firebase 並驗證使用者
Future<void> signInAndVerify(String email, String password) async {
  try {
    // 1️⃣ 登入 Firebase
    final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCredential.user;
    if (user == null) {
      print("登入失敗，使用者為空");
      return;
    }

    // 2️⃣ 取得 idToken
    final idToken = await user.getIdToken();

    // 3️⃣ 發送給後端驗證
    final response = await http.post(
      Uri.parse('http://localhost:8000/verify_user'), // 改成你的後端 URL
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'idToken': idToken ?? '',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'verified') {
        print("使用者驗證成功，UID: ${data['uid']}, Email: ${data['email']}");
      } else {
        print("使用者驗證失敗: ${data['message']}");
      }
    } else {
      print('後端驗證失敗: ${response.statusCode} ${response.body}');
    }
  } on FirebaseAuthException catch (e) {
    print('Firebase 登入失敗: ${e.message}');
  } catch (e) {
    print('其他錯誤: $e');
  }
}
