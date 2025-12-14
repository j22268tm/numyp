import 'package:flutter/material.dart';
// import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/constants.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/map/map_screen.dart';
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

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'numyp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const _AppEntry(),
    );
  }
}

/// アプリ起動直後の初期化と画面出し分けを一元化するルート。
/// - まずSplash(動画)を表示
/// - 同時にセッション復元を実行
/// - Splash終了 + セッション復元完了後、auth状態で Auth/Map を出し分け
class _AppEntry extends ConsumerStatefulWidget {
  const _AppEntry();

  @override
  ConsumerState<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends ConsumerState<_AppEntry> {
  bool _splashFinished = false;
  bool _didBootstrap = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrapAuth);
  }

  Future<void> _bootstrapAuth() async {
    if (_didBootstrap) return;
    _didBootstrap = true;

    await ref.read(authProvider.notifier).restoreSession();

    final authState = ref.read(authProvider);
    if (authState.user == null && AppConstants.isDebugMode) {
      ref.read(authProvider.notifier).loginAsDebugUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // 初回起動時のみSplashを表示（logout/loginなどでは表示しない）
    if (!_splashFinished || !authState.hasRestoredSession) {
      return SplashScreen(
        key: const ValueKey('splash'),
        onFinished: () {
          if (!mounted) return;
          setState(() {
            _splashFinished = true;
          });
        },
      );
    }

    return authState.user != null ? const MapScreen() : const AuthScreen();
  }
}
