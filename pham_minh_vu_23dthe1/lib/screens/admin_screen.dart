import 'package:flutter/material.dart';

import '../widgets/logout_button.dart';
import 'category_management_screen.dart';
import 'market_screen.dart';

/// Trang dành cho Admin: quản lý sản phẩm (thêm/sửa/xóa) và danh mục sản phẩm.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? 'Admin - Sản phẩm' : 'Admin - Danh mục'),
        actions: const [LogoutButton()],
      ),
      // Không dùng IndexedStack: mỗi lần đổi tab sẽ tải lại để danh mục/sản phẩm luôn mới
      body: _index == 0
          ? const MarketScreen(canEdit: true, embedded: true)
          : const CategoryManagementScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'Sản phẩm'),
          BottomNavigationBarItem(icon: Icon(Icons.category_outlined), label: 'Danh mục'),
        ],
      ),
    );
  }
}
