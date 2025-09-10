import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isDarkMode = false;

  ThemeProvider() {
    _loadThemePreference();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _isDarkMode;

  // 加载主题偏好设置
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeIndex = prefs.getInt('theme_mode') ?? ThemeMode.system.index;
      _themeMode = ThemeMode.values[themeModeIndex];
      _isDarkMode = _themeMode == ThemeMode.dark;
      notifyListeners();
    } catch (e) {
      print('加载主题设置失败: $e');
    }
  }

  // 切换主题模式
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
      _isDarkMode = true;
    } else {
      _themeMode = ThemeMode.light;
      _isDarkMode = false;
    }

    // 保存设置
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_mode', _themeMode.index);
    } catch (e) {
      print('保存主题设置失败: $e');
    }

    notifyListeners();
  }

  // 设置特定主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _isDarkMode = mode == ThemeMode.dark;

    // 保存设置
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_mode', _themeMode.index);
    } catch (e) {
      print('保存主题设置失败: $e');
    }

    notifyListeners();
  }

  // 获取当前主题数据
  ThemeData getCurrentTheme(BuildContext context) {
    return _isDarkMode ? _darkTheme : _lightTheme;
  }

  // 获取暗黑主题（供外部使用）
  ThemeData get darkTheme => _darkTheme;

  // 浅色主题
  static final ThemeData _lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );

  // 深色主题
  static final ThemeData _darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );
}
