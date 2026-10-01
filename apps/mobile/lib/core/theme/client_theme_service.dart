import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';
import 'alpha_x_design_system.dart';
import 'app_theme.dart';

enum ClientThemeMode {
  light,
  dark,
  system,
}

/// Centralized Client-Only Theme Service.
/// Handles theme selection (Light, Dark, System Default), persistence via SharedPreferences,
/// and provides theme-aware colors specifically for the Client application.
class ClientThemeService extends ChangeNotifier {
  static final ClientThemeService _instance = ClientThemeService._internal();
  factory ClientThemeService() => _instance;
  ClientThemeService._internal();

  static const String _prefKey = 'alpha_x_client_theme_mode';
  ClientThemeMode _themeMode = ClientThemeMode.dark;
  bool _isInitialized = false;

  ClientThemeMode get themeMode => _themeMode;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_prefKey);
      if (savedMode == 'light') {
        _themeMode = ClientThemeMode.light;
      } else if (savedMode == 'dark') {
        _themeMode = ClientThemeMode.dark;
      } else if (savedMode == 'system') {
        _themeMode = ClientThemeMode.system;
      } else {
        // Default to dark mode for Alpha X Gym branding
        _themeMode = ClientThemeMode.dark;
      }
    } catch (e) {
      debugPrint('[ClientThemeService] Error initializing theme mode: $e');
      _themeMode = ClientThemeMode.dark;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ClientThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode.name);
    } catch (e) {
      debugPrint('[ClientThemeService] Error saving theme mode: $e');
    }
  }

  /// Determines if current effective appearance is dark
  bool isDarkMode(BuildContext context) {
    switch (_themeMode) {
      case ClientThemeMode.light:
        return false;
      case ClientThemeMode.dark:
        return true;
      case ClientThemeMode.system:
        final brightness = MediaQuery.maybePlatformBrightnessOf(context) ??
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        return brightness == Brightness.dark;
    }
  }

  /// Resolves the appropriate ThemeData for the Client application
  ThemeData resolveTheme(BuildContext context) {
    final dark = isDarkMode(context);
    return dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  }
}

/// Dynamic Theme-Aware Color Accessor for Client screens
class ClientThemeColors {
  final BuildContext context;
  ClientThemeColors(this.context);

  static ClientThemeColors of(BuildContext context) => ClientThemeColors(context);

  bool get isDark => ClientThemeService().isDarkMode(context);

  // Background & Surfaces
  Color get background => isDark ? AppColors.background : const Color(0xFFF7F8FA);
  Color get surface => isDark ? AppColors.surface : const Color(0xFFFFFFFF);
  Color get surfaceCard => isDark ? AppColors.surfaceCard : const Color(0xFFFFFFFF);
  Color get surfaceElevated => isDark ? AppColors.surfaceElevated : const Color(0xFFF3F4F6);
  Color get surfaceGlass => isDark ? AppColors.surfaceGlass : const Color(0xF2FFFFFF);

  // Borders & Dividers
  Color get border => isDark ? AppColors.border : const Color(0xFFE5E7EB);
  Color get borderSubtle => isDark ? AppColors.borderSubtle : const Color(0xFFF3F4F6);
  Color get borderActive => AppColors.borderActive;

  // Typography
  Color get textPrimary => isDark ? AppColors.textPrimary : const Color(0xFF111827);
  Color get textSecondary => isDark ? AppColors.textSecondary : const Color(0xFF4B5563);
  Color get textTertiary => isDark ? AppColors.textTertiary : const Color(0xFF9CA3AF);
  Color get textDisabled => isDark ? AppColors.textDisabled : const Color(0xFFD1D5DB);

  // Brand Red & Accents
  Color get primaryRed => AppColors.primaryRed;
  Color get accentRed => AppColors.accentRed;
  Color get glowRed => isDark ? AppColors.glowRed : const Color(0x22E53935);
  Color get redSubtle => isDark ? AlphaXColors.redSubtle : const Color(0x14E50914);

  // Status
  Color get success => AppColors.success;
  Color get warning => AppColors.warning;
  Color get error => AppColors.error;
  Color get info => AppColors.info;

  // Input & Card helpers
  Color get inputFill => isDark ? AppColors.surface : const Color(0xFFF9FAFB);
  Color get cardShadow => isDark ? const Color(0x40000000) : const Color(0x0D000000);
}
