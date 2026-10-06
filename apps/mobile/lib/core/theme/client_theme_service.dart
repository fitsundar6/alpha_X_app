import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';
import 'app_theme.dart';

enum ClientThemeMode {
  light,
  dark,
  system,
}

/// Centralized Alpha X Theme Service.
/// Handles theme selection (Light, Dark, System Default), persistence via SharedPreferences,
/// and provides theme-aware styling for both Client and Admin applications.
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
        // Default to dark mode for Alpha X Gym Athletic Premium branding
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

  /// Resolves the appropriate ThemeData
  ThemeData resolveTheme(BuildContext context) {
    final dark = isDarkMode(context);
    return dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  }
}

/// Dynamic Theme-Aware Color Accessor for Alpha X screens
class ClientThemeColors {
  final BuildContext context;
  ClientThemeColors(this.context);

  static ClientThemeColors of(BuildContext context) => ClientThemeColors(context);

  bool get isDark => ClientThemeService().isDarkMode(context);

  // Background & Surfaces
  Color get background => isDark ? AppColors.background : AppColors.lightBackground;
  Color get secondaryBackground => isDark ? AppColors.secondaryBackground : AppColors.lightSecondaryBackground;
  Color get surface => isDark ? AppColors.surface : AppColors.lightSurface;
  Color get card => isDark ? AppColors.card : AppColors.lightCard;
  Color get surfaceCard => isDark ? AppColors.surfaceCard : AppColors.lightSurfaceCard;
  Color get secondaryCard => isDark ? AppColors.secondaryCard : AppColors.lightSecondaryCard;
  Color get surfaceElevated => isDark ? AppColors.surfaceElevated : AppColors.lightSurfaceElevated;
  Color get surfaceGlass => isDark ? AppColors.surfaceGlass : const Color(0xF2FFFFFF);

  // Borders & Dividers
  Color get border => isDark ? AppColors.border : AppColors.lightBorder;
  Color get borderSubtle => isDark ? AppColors.borderSubtle : AppColors.lightBorder;
  Color get borderActive => isDark ? AppColors.borderActive : AppColors.lightBorderActive;

  // Typography
  Color get textPrimary => isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get textSecondary => isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
  Color get textTertiary => isDark ? AppColors.textTertiary : AppColors.lightTextSecondary;
  Color get textMuted => isDark ? AppColors.textMuted : AppColors.lightTextMuted;
  Color get textDisabled => isDark ? AppColors.textDisabled : AppColors.lightTextDisabled;

  // Primary Gold Brand Accent & CTAs
  Color get primary => isDark ? AppColors.primary : AppColors.lightPrimary;
  Color get primaryGold => isDark ? AppColors.primaryGold : AppColors.lightPrimary;
  Color get brightGold => isDark ? AppColors.brightGold : AppColors.lightBrightGold;
  Color get lightGold => isDark ? AppColors.lightGold : AppColors.lightLightGold;
  Color get primaryPressed => isDark ? AppColors.primaryPressed : AppColors.lightPrimaryPressed;
  Color get onPrimary => isDark ? AppColors.onPrimary : AppColors.lightOnPrimary;
  Color get secondary => isDark ? AppColors.secondary : AppColors.lightSecondary;
  Color get success => isDark ? AppColors.success : AppColors.lightSuccess;
  Color get warning => isDark ? AppColors.warning : AppColors.lightWarning;
  Color get danger => isDark ? AppColors.danger : AppColors.lightDanger;
  Color get error => isDark ? AppColors.error : AppColors.lightError;
  Color get info => isDark ? AppColors.info : AppColors.lightInfo;
  Color get glow => isDark ? AppColors.glow : AppColors.lightGlow;

  // Backward-compatibility aliases
  Color get primaryRed => AppColors.primaryRed;
  Color get accentRed => AppColors.primaryRed;
  Color get glowRed => glow;
  Color get redSubtle => isDark ? const Color(0x26D4AF37) : const Color(0x1FB89620);

  // Input & Card helpers
  Color get inputFill => isDark ? AppColors.surfaceCard : AppColors.lightSurface;
  Color get cardShadow => isDark ? const Color(0x33000000) : const Color(0x0A000000);
}

// App-wide aliases
typedef AppThemeMode = ClientThemeMode;
typedef AppThemeService = ClientThemeService;
typedef AppThemeColors = ClientThemeColors;
