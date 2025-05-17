import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode;

  ThemeProvider(this._isDarkMode);

  bool get isDarkMode => _isDarkMode;

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();

    // Save the theme preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.darkModeKey, _isDarkMode);
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode != value) {
      _isDarkMode = value;
      notifyListeners();

      // Save the theme preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.darkModeKey, _isDarkMode);
    }
  }
}
