// lib/routes.dart
import 'package:flutter/material.dart';
import 'home.dart';
import 'auth.dart';
import 'admin.dart';
import 'onboarding.dart';
import 'admin_test.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => const NutritionDashboardApp(),      // 主畫面
  '/auth': (context) => const AuthPage(),  // 登入/註冊頁
  '/admin': (context) => const AdminPage(),       // 管理頁
  '/onboarding': (context) => const OnboardingPage(), // 教學頁
  '/admin_test': (context) => const AdminTestPage(), // Admin 測試頁
};