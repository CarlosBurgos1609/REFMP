import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  bool _useSystemTheme =
      true; // Nueva variable para saber si usa tema del sistema
  Brightness? _systemBrightness;

  bool get isDarkMode => _isDarkMode;
  bool get useSystemTheme => _useSystemTheme;

  ThemeProvider() {
    _loadTheme(); // Cargar el tema guardado al iniciar la app
  }

  // Actualizar el brillo del sistema
  void updateSystemBrightness(Brightness brightness) {
    _systemBrightness = brightness;
    if (_useSystemTheme) {
      _isDarkMode = brightness == Brightness.dark;
      notifyListeners();
    }
  }

  void toggleTheme() async {
    // Al cambiar manualmente, desactivar el uso del tema del sistema
    _useSystemTheme = false;
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    _saveTheme(); // Guardar el estado del tema
  }

  // Restablecer al tema del sistema
  void useSystemThemeMode(Brightness systemBrightness) async {
    _useSystemTheme = true;
    _systemBrightness = systemBrightness;
    _isDarkMode = systemBrightness == Brightness.dark;
    notifyListeners();
    _saveTheme();
  }

  ThemeData get currentTheme =>
      _isDarkMode ? ThemeData.dark() : ThemeData.light();

  // Guardar el estado del tema en SharedPreferences
  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    await prefs.setBool('useSystemTheme', _useSystemTheme);
  }

  // Cargar el estado del tema desde SharedPreferences
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _useSystemTheme = prefs.getBool('useSystemTheme') ?? true;

    if (_useSystemTheme) {
      // Si usa tema del sistema, esperar a que se actualice desde main.dart
      // Por ahora usar false como default hasta que se actualice
      _isDarkMode = false;
    } else {
      // Si no usa tema del sistema, cargar la preferencia guardada
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    }
    notifyListeners();
  }
}
