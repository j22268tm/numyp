import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../config/theme.dart';

/// アプリ起動時のロゴムービースプラッシュ画面
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasFinished = false;

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
      // エラーが発生した場合は即座に終了扱い
      _finish();
    }
  }

  /// 動画の再生状態を監視
  void _videoListener() {
    if (_controller.value.position >= _controller.value.duration) {
      // 再生終了したら終了扱い
      _finish();
    }
  }

  void _finish() {
    if (_hasFinished) return;
    _hasFinished = true;
    if (_isInitialized) {
      _controller.removeListener(_videoListener);
    }
    widget.onFinished();
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _controller.removeListener(_videoListener);
    }
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
