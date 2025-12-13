import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/constants.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/map/map_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);

    // デバッグモードの場合、自動ログイン（一度だけ実行）
    if (AppConstants.isDebugMode && 
        authState.user == null && 
        !authState.isLoading && 
        !_hasTriedDebugLogin) {
      _hasTriedDebugLogin = true;
      // フレーム後に実行（ビルド中の状態変更を避けるため）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(authProvider.notifier).loginAsDebugUser();
      });
    }

    return MaterialApp(
      title: 'numyp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: authState.user == null ? const AuthScreen() : const MapScreen(),
    );
  }
}
