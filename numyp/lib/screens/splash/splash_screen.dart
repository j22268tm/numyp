import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../auth/auth_screen.dart';
import '../map/map_screen.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

/// アプリ起動時のロゴムービースプラッシュ画面
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  /// 動画の初期化と再生開始
  Future<void> _initializeVideo() async {
    // assets/videos/startup.mp4 を読み込む
    _controller = VideoPlayerController.asset('assets/videos/startup.mp4');

    try {
      await _controller.initialize();
      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });

      // 自動再生を開始
      await _controller.play();

      // 再生終了を検知するリスナーを登録
      _controller.addListener(_videoListener);
    } catch (e) {
      debugPrint('動画の初期化エラー: $e');
      // エラーが発生した場合は即座に画面遷移
      _navigateToHome();
    }
  }

  /// 動画の再生状態を監視
  void _videoListener() {
    if (_controller.value.position >= _controller.value.duration) {
      // 再生終了したら画面遷移
      _navigateToHome();
    }
  }

  /// 認証状態に基づいて適切な画面へ遷移
  void _navigateToHome() {
    if (!mounted) return;

    // リスナーを削除
    _controller.removeListener(_videoListener);

    // 認証状態を確認
    final authState = ref.read(authProvider);

    // 認証済みならMapScreen、未認証ならAuthScreenへ遷移
    final destination = authState.user != null
        ? const MapScreen()
        : const AuthScreen();

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (context) => destination));
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.midnightBackground,
      body: Center(
        child: _isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const SizedBox.shrink(), // ローディング中は黒画面のまま
      ),
    );
  }
}
