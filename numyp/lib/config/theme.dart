import 'package:flutter/material.dart';

/// アプリ全体で使用する色定義（ライト / ダーク対応）
class AppColors {
  const AppColors({
    required this.midnightBackground,
    required this.cardSurface,
    required this.magicGold,
    required this.deepGold,
    required this.lanternOrange,
    required this.fantasyPurple,
    required this.textPrimary,
    required this.textSecondary,
    required this.glassWhite,
  });

  // --- ベースカラー (夜空・背景) ---
  final Color midnightBackground;
  final Color cardSurface;

  // --- アクセントカラー (魔法・輝き) ---
  final Color magicGold;
  final Color deepGold;

  // --- サブカラー (温かみ・幻想) ---
  final Color lanternOrange;
  final Color fantasyPurple;

  // --- テキストカラー ---
  final Color textPrimary;
  final Color textSecondary;

  // --- ガラスモーフィズム用 ---
  final Color glassWhite;

  static const AppColors dark = AppColors(
    midnightBackground: Color(0xFF0F0F16),
    cardSurface: Color(0xFF1A1A24),
    magicGold: Color(0xFFFFD700),
    deepGold: Color(0xFFC5A000),
    lanternOrange: Color(0xFFFFA500),
    fantasyPurple: Color(0xFF9D4EDD),
    textPrimary: Color(0xFFF0F0F5),
    textSecondary: Color(0xFFAAAAAA),
    glassWhite: Color(0x1AFFFFFF),
  );

  static const AppColors light = AppColors(
    midnightBackground: Color(0xFFF7F5FF),
    cardSurface: Colors.white,
    magicGold: Color(0xFFFFD700),
    deepGold: Color(0xFFC5A000),
    lanternOrange: Color(0xFFFFA500),
    fantasyPurple: Color(0xFF8A4AE3),
    textPrimary: Color(0xFF1C1B1F),
    textSecondary: Color(0xFF5E5E6D),
    glassWhite: Color(0xB3FFFFFF),
  );

  static AppColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}

/// アプリ全体のテーマ設定
class AppTheme {
  static ThemeData get darkTheme => _buildTheme(AppColors.dark, Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(AppColors.light, Brightness.light);

  static ThemeData _buildTheme(AppColors colors, Brightness brightness) {
    final colorScheme = brightness == Brightness.dark
        ? ColorScheme.dark(
            primary: colors.magicGold,
            onPrimary: Colors.black,
            secondary: colors.fantasyPurple,
            onSecondary: Colors.white,
            surface: colors.cardSurface,
            onSurface: colors.textPrimary,
            error: const Color(0xFFCF6679),
          )
        : ColorScheme.light(
            primary: colors.magicGold,
            onPrimary: Colors.black,
            secondary: colors.fantasyPurple,
            onSecondary: Colors.white,
            surface: colors.cardSurface,
            onSurface: colors.textPrimary,
            error: const Color(0xFFB3261E),
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Noto Sans JP',
      scaffoldBackgroundColor: colors.midnightBackground,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: colors.magicGold,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Noto Sans JP',
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.cardSurface.withValues(
          alpha: brightness == Brightness.dark ? 0.9 : 0.95,
        ),
        selectedItemColor: colors.magicGold,
        unselectedItemColor: colors.textSecondary,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.fantasyPurple,
        foregroundColor: Colors.white,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: colors.cardSurface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: brightness == Brightness.dark ? Colors.white10 : Colors.black12,
            width: 1,
          ),
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: colors.textPrimary),
        bodyMedium: TextStyle(color: colors.textPrimary),
        titleLarge: TextStyle(
          color: colors.magicGold,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
