// lib/routes.dart
import 'package:flutter/material.dart';
import 'home.dart';
import 'auth.dart';
import 'onboarding.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => const NutritionDashboardApp(),      // 主畫面
  '/auth': (context) => const AuthPage(),  // 登入/註冊頁
  '/onboarding': (context) => const OnboardingPage(), // 教學頁
};