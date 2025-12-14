import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/theme_provider.dart';
import '../../providers/spot_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quest_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/spot_detail_card.dart';
import '../../widgets/spot_preview_card.dart';
import '../mypage/mypage_screen.dart';
import '../pin/pin_list_screen.dart';
import '../pin/pin_form_screen.dart';
import '../quest/quest_board_screen.dart';
import '../quest/quest_form_screen.dart';
import '../shop/shop_screeen.dart';

/// メイン地図画面
/// APIから取得したスポットを表示し、選択できる
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  late final CameraPosition _initialCameraPosition;
  String? _darkMapStyle;
  String? _lightMapStyle;

  int _currentIndex = 0;

  // 位置情報追従用の変数
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTrackingMode = true;
  bool _isProgrammaticCameraChange = false;

  @override
  void initState() {
    super.initState();
    _loadMapStyles();
    _initialCameraPosition = const CameraPosition(
      target: LatLng(
        AppConstants.initialLatitude,
        AppConstants.initialLongitude,
      ),
      zoom: AppConstants.initialZoom,
    );
    _startLocationTracking();
  }

  @override
  // Future<void> dispose() async {
  void dispose() {
    unawaited(_positionStreamSubscription?.cancel());
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ThemeMode>(themeModeProvider, (previous, next) {
      _applyMapStyle(next);
    });

    final Widget body;

    switch (_currentIndex) {
      case 0:
        body = _buildMapView(context);
        break;
      case 1:
        body = const QuestBoardScreen();
        break;
      case 2:
        body = const PinListScreen();
        break;
      case 3:
        body = const ShopScreen();
        break;
      case 4:
        body = const MyPageScreen();
        break;
      default:
        body = _buildMapView(context);
        break;
    }

    return Scaffold(
      body: body,

      // 下部ナビゲーションバー
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.emergency_recording),
            label: 'quests',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.push_pin), label: 'spots'),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'shop',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'mypage'),
        ],
      ),
    );
  }

  Widget _buildMapView(BuildContext context) {
    final spotsAsync = ref.watch(spotsControllerProvider);
    final spotMarkers = ref.watch(markerProvider);
    final questMarkers = ref.watch(questMarkerProvider);
    final markers = {...spotMarkers, ...questMarkers};
    final selectedSpot = ref.watch(selectedSpotProvider);

    final user = ref.watch(authProvider).user;
    final colors = AppColors.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    return Stack(
      children: [
        GoogleMap(
          // Cloud Map Styling works only with the normal map type.
          mapType: MapType.normal,
          initialCameraPosition: _initialCameraPosition,
          onMapCreated: (GoogleMapController controller) {
            _mapController?.dispose();
            _mapController = controller;
            _applyMapStyle(ref.read(themeModeProvider));
          },
          onLongPress: (latLng) => _onMapLongPress(context, latLng),
          onCameraMoveStarted: () {
            // プログラマティックなカメラ変更の場合はスキップ
            if (_isProgrammaticCameraChange) return;
            // ユーザーが手動で地図を操作した場合、追従モードを解除
            if (_isTrackingMode) {
              setState(() {
                _isTrackingMode = false;
              });
            }
          },
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          myLocationEnabled: true, // デフォルトの青い点で現在地と方向を表示
          markers: markers,
        ),

        // 上部ステータスバー
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildCoinSection(context, user?.coins ?? 0),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user?.username ?? 'ゲスト',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '今日のスポットを探索しよう',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: isDarkMode ? 'ライトモードに切替' : 'ダークモードに切替',
                  onPressed: () =>
                      ref.read(themeModeProvider.notifier).toggle(),
                  icon: Icon(
                    isDarkMode
                        ? Icons.wb_sunny_outlined
                        : Icons.dark_mode_outlined,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                _buildIconBadge(context, user?.iconUrl),
              ],
            ),
          ),
        ),

        // ローディングやエラーの表示
        Positioned(
          top: MediaQuery.of(context).padding.top + 90,
          left: 16,
          right: 16,
          child: spotsAsync.when(
            data: (_) => const SizedBox.shrink(),
            loading: () => const _StatusBubble(
              icon: Icons.cloud_download,
              text: 'スポットを読み込み中...',
            ),
            error: (error, _) => _StatusBubble(
              icon: Icons.error_outline,
              text: '取得に失敗しました。リトライ',
              onTap: () =>
                  ref.read(spotsControllerProvider.notifier).refreshSpots(),
            ),
          ),
        ),

        // 下部のスポットプレビュー
        // if (spotsAsync.hasValue && spotsAsync.value!.isNotEmpty)
        if (selectedSpot == null &&
            spotsAsync.hasValue &&
            spotsAsync.value!.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: SizedBox(
              height: 170,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final spot = spotsAsync.value![index];
                  return SpotPreviewCard(
                    spot: spot,
                    onTap: () {
                      _moveCamera(spot.location);
                      ref.read(selectedSpotProvider.notifier).state = spot;
                    },
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemCount: spotsAsync.value!.length,
              ),
            ),
          ),

        // 詳細カード
        if (selectedSpot != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: SpotDetailCard(
              spot: selectedSpot,
              onClose: () =>
                  ref.read(selectedSpotProvider.notifier).state = null,
            ),
          ),

        // 現在地 / リフレッシュボタン
        Positioned(
          bottom: 200,
          right: 16,
          child: Column(
            children: [
              FloatingActionButton(
                heroTag: 'refresh',
                backgroundColor: colors.cardSurface.withValues(alpha: 0.85),
                onPressed: () =>
                    ref.read(spotsControllerProvider.notifier).refreshSpots(),
                child: Icon(Icons.refresh, color: colors.magicGold),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'location',
                backgroundColor: _isTrackingMode
                    ? colors.magicGold.withValues(alpha: 0.9)
                    : colors.cardSurface.withValues(alpha: 0.85),
                onPressed: _goToCurrentLocation,
                child: Icon(
                  Icons.my_location,
                  color: _isTrackingMode
                      ? colors.cardSurface
                      : colors.magicGold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCoinSection(BuildContext context, int coins) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.cardSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(Icons.monetization_on, color: colors.magicGold, size: 22),
          const SizedBox(width: 6),
          Text(
            coins.toString(),
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBadge(BuildContext context, String? iconUrl) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors.fantasyPurple.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: colors.fantasyPurple,
        backgroundImage: iconUrl != null ? NetworkImage(iconUrl) : null,
        child: iconUrl == null
            ? const Icon(Icons.person, color: Colors.white)
            : null,
      ),
    );
  }

  /// ユーザーの現在位置を表すカスタムマーカーを作成
  ///
  /// 後から画像に置き換える場合は、以下の手順で実装してください：
  /// 1. assets/images/ に画像ファイルを配置（例: user_location_pin.png）
  /// 2. pubspec.yaml の assets セクションに画像を追加
  /// 3. BitmapDescriptor.fromAssetImage() を使用してアイコンを読み込む
  ///
  /// 例：
  /// ```dart
  /// final icon = await BitmapDescriptor.fromAssetImage(
  ///   const ImageConfiguration(size: Size(48, 48)),
  ///   'assets/images/user_location_pin.png',
  /// );
  /// ```

  // 現在は myLocationEnabled: true を使用しているため、このメソッドは使用していません
  // カスタム画像に置き換えたい場合は、以下のコメントを解除して使用してください
  /*
  Marker _createUserLocationMarker() {
    return Marker(
      markerId: const MarkerId('user_location'),
      position: _currentPosition!,
      // TODO: 画像に置き換える場合は、ここでBitmapDescriptor.fromAssetImage()を使用
      // 現在はデフォルトのマーカーを青色で表示
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      anchor: const Offset(0.5, 0.5), // マーカーの中心を位置に合わせる
      zIndex: 999, // 他のマーカーより前面に表示
      infoWindow: const InfoWindow(title: '現在地', snippet: 'あなたの現在位置です'),
    );
  }
  */

  /// 位置情報のリアルタイム監視を開始
  void _startLocationTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (!mounted) return;
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        debugPrint('位置情報の権限拒否');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint("Location Permission DeniedForever");
      return;
    }

    if (!mounted) return;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    await _positionStreamSubscription?.cancel();
    if (!mounted) return;
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _onLocationUpdate(position);
          },
          onError: (error) {
            debugPrint('位置情報の取得エラー: $error');
          },
        );
  }

  /// 位置情報更新時の処理
  void _onLocationUpdate(Position position) {
    if (!mounted) return;
    final newPosition = LatLng(position.latitude, position.longitude);

    // 追従モードが有効な場合、カメラを移動
    if (_isTrackingMode && _mapController != null) {
      _isProgrammaticCameraChange = true;
      _mapController!
          .animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: newPosition,
                zoom: AppConstants.initialZoom + 1,
              ),
            ),
          )
          .then((_) {
            _isProgrammaticCameraChange = false;
          })
          .catchError((_) {
            _isProgrammaticCameraChange = false;
          });
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (context) {
        final colors = AppColors.of(context);
        return AlertDialog(
          backgroundColor: colors.cardSurface,
          title: Text('画像の選択', style: TextStyle(color: colors.textPrimary)),
          content: Text(
            'スポットの画像をどのように取得しますか？',
            style: TextStyle(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.camera),
              child: const Text('カメラで撮影'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
              child: const Text('ギャラリーから選択'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
          ],
        );
      },
    );  
  }

  /// 現在地へ移動して追従モードを有効化
  Future<void> _goToCurrentLocation() async {
    final controller = _mapController;
    if (controller == null) return;

    setState(() {
      _isTrackingMode = true;
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      final currentLatLng = LatLng(position.latitude, position.longitude);

      _isProgrammaticCameraChange = true;
      try {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: currentLatLng,
              zoom: AppConstants.initialZoom + 1,
            ),
          ),
        );
      } finally {
        _isProgrammaticCameraChange = false;
      }
    } catch (e) {
      debugPrint('現在地の取得エラー: $e');
    }
  }

  Future<void> _moveCamera(LatLng position) async {
    final controller = _mapController;
    if (controller == null) return;
    _isProgrammaticCameraChange = true;
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: position, zoom: AppConstants.initialZoom + 1),
        ),
      );
    } finally {
      _isProgrammaticCameraChange = false;
    }
  }

  Future<void> _loadMapStyles() async {
    final dark = await rootBundle.loadString('assets/map_styles/dark.json');
    final light = await rootBundle.loadString('assets/map_styles/light.json');
    if (!mounted) return;
    setState(() {
      _darkMapStyle = dark;
      _lightMapStyle = light;
    });
    if (!mounted) return;
    await _applyMapStyle(ref.read(themeModeProvider));
  }

  Future<void> _applyMapStyle(ThemeMode mode) async {
    final controller = _mapController;
    if (controller == null) return;
    final style = mode == ThemeMode.dark ? _darkMapStyle : _lightMapStyle;
    await controller.setMapStyle(style);
  }

  Future<void> _onMapLongPress(BuildContext context, LatLng latLng) async {
    ref.read(selectedSpotProvider.notifier).state = null;
    final selection = await _showLongPressActionSheet(context, latLng);
    if (!context.mounted || selection == null) return;

    switch (selection) {
      case _MapLongPressAction.createSpot:

        final imageSource = await _showImageSourceDialog();
        if (imageSource == null || !context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SpotFormScreen(
              initialLocation: latLng, 
              imageSource: imageSource
            ),
          ),
        );
        break;
      case _MapLongPressAction.createQuest:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QuestFormScreen(initialLocation: latLng),
          ),
        );
        break;
    }
  }

  Future<_MapLongPressAction?> _showLongPressActionSheet(
    BuildContext context,
    LatLng location,
  ) async {
    return showModalBottomSheet<_MapLongPressAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: colors.cardSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'この場所でできること',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  _ActionTile(
                    icon: Icons.push_pin,
                    title: 'ピンの新規作成',
                    subtitle: 'スポットとして登録',
                    onTap: () async {
                      Navigator.of(ctx).pop(_MapLongPressAction.createSpot);
                      // final imageSource = await _showImageSourceDialog();
                      // if (imageSource != null && context.mounted) {
                      //   await Navigator.of(context).push(
                      //     MaterialPageRoute(
                      //       builder: (_) => SpotFormScreen(
                      //         initialLocation: location,
                      //         imageSource: imageSource,
                      //       ),
                      //     ),
                      //   );
                      // }
                    },
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  _ActionTile(
                    icon: Icons.add_task_rounded,
                    title: 'クエストの新規発注',
                    subtitle: '調査依頼を作成',
                    onTap: () =>
                        Navigator.of(ctx).pop(_MapLongPressAction.createQuest),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _MapLongPressAction { createSpot, createQuest }

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.midnightBackground.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(icon, color: colors.magicGold),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: colors.textSecondary)),
      trailing: Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
      onTap: onTap,
    );
  }
}

class _StatusBubble extends StatelessWidget {
  const _StatusBubble({required this.icon, required this.text, this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: colors.magicGold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: TextStyle(color: colors.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}
