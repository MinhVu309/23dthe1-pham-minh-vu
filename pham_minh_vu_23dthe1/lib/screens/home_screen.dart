import 'package:flutter/material.dart';

import 'market_screen.dart';
import 'news_feed_screen.dart';

/// Khung chính: BottomNavigationBar chuyển giữa Chợ và Bảng tin.
/// IndexedStack giữ trạng thái từng tab (không tải lại khi chuyển qua lại).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [MarketScreen(), NewsFeedScreen()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Chợ'),
          BottomNavigationBarItem(icon: Icon(Icons.dynamic_feed), label: 'Bảng tin'),
        ],
      ),
    );
  }
}
