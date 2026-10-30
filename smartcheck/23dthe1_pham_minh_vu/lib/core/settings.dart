import 'package:flutter/material.dart' show Color;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cỡ chữ toàn app, nhân với cỡ chữ hệ thống của máy.
enum AppTextSize {
  small('Nhỏ', 0.9),
  normal('Vừa', 1.0),
  large('Lớn', 1.15),
  xlarge('Rất lớn', 1.3);

  const AppTextSize(this.label, this.factor);
  final String label;
  final double factor;

  static AppTextSize parse(String? name) => values.firstWhere((e) => e.name == name, orElse: () => normal);
}

/// Màu nền do người dùng chọn. [page] là nền các trang, [sheet] là tờ bo tròn ở trang chủ và màn đăng nhập.
/// Chỉ dùng các màu sáng nên chữ và thẻ trắng hiện tại vẫn đọc rõ.
enum AppBackground {
  fog('Xám xanh', 0xFFF1F3F8, 0xFFFFFFFF),
  white('Trắng', 0xFFFFFFFF, 0xFFFFFFFF),
  cream('Kem', 0xFFFBF5E6, 0xFFFFFBF0),
  mint('Bạc hà', 0xFFE8F6EE, 0xFFF3FBF7),
  sky('Xanh trời', 0xFFE6F3FC, 0xFFF2F9FE),
  blush('Hồng phấn', 0xFFFBEAF0, 0xFFFEF5F8);

  const AppBackground(this.label, this._page, this._sheet);
  final String label;
  final int _page;
  final int _sheet;

  Color get page => Color(_page);
  Color get sheet => Color(_sheet);

  static AppBackground parse(String? name) => values.firstWhere((e) => e.name == name, orElse: () => fog);
}

abstract interface class SettingsStore {
  Future<Map<String, String>> read();
  Future<void> write(String key, String value);
  Future<void> clear();
}

class PrefsSettingsStore implements SettingsStore {
  static const _keys = ['textSize', 'background'];
  static String _k(String key) => 'smartcheck.settings.$key';

  @override
  Future<Map<String, String>> read() async {
    final p = await SharedPreferences.getInstance();
    return {for (final k in _keys) if (p.getString(_k(k)) != null) k: p.getString(_k(k))!};
  }

  @override
  Future<void> write(String key, String value) async => (await SharedPreferences.getInstance()).setString(_k(key), value);

  @override
  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    for (final k in _keys) {
      await p.remove(_k(k));
    }
  }
}

class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([Map<String, String>? initial]) : data = {...?initial};
  final Map<String, String> data;
  @override
  Future<Map<String, String>> read() async => {...data};
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> clear() async => data.clear();
}

/// Tuỳ chọn giao diện của máy này (không theo tài khoản). Đọc một lần lúc mở app, đổi là có hiệu lực ngay và được lưu lại.
class SettingsController extends ChangeNotifier {
  SettingsController(this._store);
  final SettingsStore _store;

  AppTextSize _textSize = AppTextSize.normal;
  AppBackground _background = AppBackground.fog;

  AppTextSize get textSize => _textSize;
  AppBackground get background => _background;
  bool get isDefault => _textSize == AppTextSize.normal && _background == AppBackground.fog;

  Future<void> load() async {
    try {
      final saved = await _store.read();
      _textSize = AppTextSize.parse(saved['textSize']);
      _background = AppBackground.parse(saved['background']);
    } catch (_) {
      // đọc lỗi thì dùng mặc định
    }
    notifyListeners();
  }

  Future<void> setTextSize(AppTextSize v) async {
    if (v == _textSize) return;
    _textSize = v;
    notifyListeners();
    await _store.write('textSize', v.name);
  }

  Future<void> setBackground(AppBackground v) async {
    if (v == _background) return;
    _background = v;
    notifyListeners();
    await _store.write('background', v.name);
  }

  Future<void> reset() async {
    _textSize = AppTextSize.normal;
    _background = AppBackground.fog;
    notifyListeners();
    await _store.clear();
  }
}
