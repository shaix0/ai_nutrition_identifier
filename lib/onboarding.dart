import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const OnboardingPage());
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int currentPage = 0;

  final List<Map<String, String>> pages = [
    {
      'title': '歡迎使用營養追蹤系統',
      'desc': '這裡可以幫助你紀錄每日飲食，追蹤營養攝取狀況。',
    },
    {
      'title': '拍照上傳你的餐點',
      'desc': '只要上傳圖片，AI 就能幫你估算營養素。',
    },
    {
      'title': '開始健康飲食旅程',
      'desc': '立即登入，設定你的健康目標吧！',
    },
  ];

  void nextPage() {
    if (currentPage < pages.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
    } else {
      Navigator.pushReplacementNamed(context, '/'); // ✅ 結束教學 → 進登入頁
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _controller,
        itemCount: pages.length,
        onPageChanged: (index) {
          setState(() {
            currentPage = index;
          });
        },
        itemBuilder: (context, index) {
          final page = pages[index];
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(page['title']!,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Text(page['desc']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, color: Colors.grey)),
                const SizedBox(height: 50),
                ElevatedButton(
                  onPressed: nextPage,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 16)),
                  child: Text(index == pages.length - 1 ? '開始使用' : '下一步'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
