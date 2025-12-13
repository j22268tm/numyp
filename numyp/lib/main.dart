import 'package:flutter/material.dart';
// import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/constants.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppConstants.loadEnv();
  } catch (e) {
    debugPrint('Failed to load env.json: $e');
    // デフォルト値が使用されます
  }
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _hasTriedDebugLogin = false;
  bool _hasTriedSessionRestore = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);

    // セッション復元を試行（一度だけ実行）
    if (authState.user == null &&
        !authState.isLoading &&
        !_hasTriedSessionRestore) {
      _hasTriedSessionRestore = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ref.read(authProvider.notifier).restoreSession();

        // セッション復元に失敗し、デバッグモードの場合は自動ログイン
        if (mounted) {
          final currentState = ref.read(authProvider);
          if (AppConstants.isDebugMode &&
              currentState.user == null &&
              !_hasTriedDebugLogin) {
            _hasTriedDebugLogin = true;
            ref.read(authProvider.notifier).loginAsDebugUser();
          }
        }
      });
    }

    return MaterialApp(
      title: 'numyp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(), // スプラッシュ画面から開始
    );
  }
}
