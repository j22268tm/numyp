import 'package:flutter/material.dart';

/// アプリ全体で使用する色定義
class AppColors {
  // --- ベースカラー (夜空・背景) ---
  // 完全な黒(#000000)ではなく、ほんの少し紫を含んだ「深い夜空色」にすることで
  // 画面に奥行きとリッチな雰囲気を与えます。
  static const Color midnightBackground = Color(0xFF0F0F16); // メイン背景
  static const Color cardSurface = Color(0xFF1A1A24); // カードやダイアログの背景

  // --- アクセントカラー (魔法・輝き) ---
  // パレードの電飾や魔法の粉(Pixie Dust)をイメージしたゴールド
  static const Color magicGold = Color(0xFFFFD700);
  // 落ち着いた高級感を出すための深いゴールド（枠線などに使用）
  static const Color deepGold = Color(0xFFC5A000);

  // --- サブカラー (温かみ・幻想) ---
  // 夜の街灯やキャンドルをイメージした温かいオレンジ
  static const Color lanternOrange = Color(0xFFFFA500);
  // 魔法の世界観を強調するミステリアスな紫
  static const Color fantasyPurple = Color(0xFF9D4EDD);

  // --- テキストカラー ---
  // 真っ白(#FFFFFF)だと暗い背景では目が痛くなるので、少し抑えた色にします
  static const Color textPrimary = Color(0xFFF0F0F5); // メイン文字
  static const Color textSecondary = Color(0xFFAAAAAA); // 補足文字

  // --- ガラスモーフィズム用 ---
  // 地図の上に浮くUIのための、半透明の白
  static const Color glassWhite = Color(0x1AFFFFFF); // 透明度10%
}

/// アプリ全体のテーマ設定
class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // フォント設定
      fontFamily: 'Noto Sans JP',

      // 1. 全体の背景色
      scaffoldBackgroundColor: AppColors.midnightBackground,

      // 2. 色の役割分担 (ColorScheme)
      colorScheme: const ColorScheme.dark(
        // Primary: 最も重要な色（ボタン、アクティブなアイコン）
        primary: AppColors.magicGold,
        onPrimary: Colors.black, // Primaryの上の文字色
        // Secondary: 補助的な色（FAB、スイッチなど）
        secondary: AppColors.fantasyPurple,
        onSecondary: Colors.white,

        // Surface: カードやシートの背景色
        surface: AppColors.cardSurface,
        onSurface: AppColors.textPrimary,

        // Error: エラー色（世界観を壊さないよう少し彩度を落とした赤）
        error: Color(0xFFCF6679),
      ),

      // 3. アプリバーの設定
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent, // 背景色なし（地図を透かすため）
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.magicGold,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Noto Sans JP',
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),

      // 4. ボトムナビゲーションバーの設定（下のメニュー）
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.midnightBackground.withOpacity(
          0.9,
        ), // 少し透けさせる
        selectedItemColor: AppColors.magicGold, // 選ばれているアイコン
        unselectedItemColor: AppColors.textSecondary, // 選ばれていないアイコン
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        elevation: 0,
      ),

      // 5. フローティングアクションボタン (右下の＋ボタンなど)
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.fantasyPurple, // 紫色のボタンで魔法っぽく
        foregroundColor: Colors.white,
        elevation: 8,
      ),

      // 6. カードのテーマ (ダイアログやリストアイテム)
      cardTheme: CardThemeData(
        color: AppColors.cardSurface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // 角丸を強めにして優しい印象に
          side: const BorderSide(color: Colors.white10, width: 1), // うっすら枠線
        ),
      ),

      // 7. テキストテーマの微調整
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        titleLarge: TextStyle(
          color: AppColors.magicGold,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
