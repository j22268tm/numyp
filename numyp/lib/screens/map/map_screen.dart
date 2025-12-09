import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/spot.dart';
import '../../providers/spot_providers.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/spot_detail_card.dart';
import '../../widgets/spot_preview_card.dart';
import '../mypage/mypage_screen.dart';
import '../pin/pin_list_screen.dart';

/// メイン地図画面
/// APIから取得したスポットを表示し、選択できる
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  late final CameraPosition _initialCameraPosition;

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initialCameraPosition = const CameraPosition(
      target: LatLng(
        AppConstants.initialLatitude,
        AppConstants.initialLongitude,
      ),
      zoom: AppConstants.initialZoom,
    );
  }

  @override
  void dispose() {
    if (_controller.isCompleted) {
      _controller.future.then((controller) => controller.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;

    switch (_currentIndex) {
      case 0:
        body = _buildMapView(context);
        break;
      case 1:
        body = const PinListScreen();
        break;
      default:
        body = const MyPageScreen();
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
        backgroundColor: AppColors.midnightBackground.withOpacity(0.95),
        selectedItemColor: AppColors.magicGold,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'map'),
          BottomNavigationBarItem(icon: Icon(Icons.push_pin), label: 'pins'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'mypage'),
        ],
      ),
    );
  }

  Widget _buildMapView(BuildContext context) {
    final spotsAsync = ref.watch(spotsProvider);
    final markers = ref.watch(markerProvider);
    final selectedSpot = ref.watch(selectedSpotProvider);

    final user = ref.watch(authProvider).user;

    return Stack(
      children: [
        GoogleMap(
          mapType: MapType.hybrid,
          initialCameraPosition: _initialCameraPosition,
          onMapCreated: (GoogleMapController controller) {
            _controller.complete(controller);
          },
          cloudMapId: null,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
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
                _buildCoinSection(user?.coins ?? 0),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'numyp',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '今日のスポットを探索しよう',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildIconBadge(user?.iconUrl),
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
              onTap: () => ref.refresh(spotsProvider),
            ),
          ),
        ),

        // 下部のスポットプレビュー
        if (spotsAsync.hasValue && spotsAsync.value!.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 120,
            child: SizedBox(
              height: 200,
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
                separatorBuilder: (_, __) => const SizedBox(width: 12),
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
              onClose: () => ref.read(selectedSpotProvider.notifier).state = null,
            ),
          ),

        // 現在地 / リフレッシュボタン
        Positioned(
          bottom: 220,
          right: 16,
          child: Column(
            children: [
              FloatingActionButton(
                heroTag: 'refresh',
                backgroundColor: AppColors.cardSurface.withOpacity(0.85),
                onPressed: () => ref.refresh(spotsProvider),
                child: const Icon(Icons.refresh, color: AppColors.magicGold),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'location',
                backgroundColor: AppColors.cardSurface.withOpacity(0.85),
                onPressed: _goToCurrentLocation,
                child: const Icon(
                  Icons.my_location,
                  color: AppColors.magicGold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCoinSection(int coins) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardSurface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on, color: AppColors.magicGold, size: 22),
          const SizedBox(width: 6),
          Text(
            coins.toString(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBadge(String? iconUrl) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.fantasyPurple.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.fantasyPurple,
        backgroundImage:
            iconUrl != null ? NetworkImage(iconUrl) : null,
        child:
            iconUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
      ),
    );
  }

  /// 現在地へ移動（仮実装）
  Future<void> _goToCurrentLocation() async {
    if (!_controller.isCompleted) return;
    final GoogleMapController controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(_initialCameraPosition),
    );
  }

  Future<void> _moveCamera(LatLng position) async {
    if (!_controller.isCompleted) return;
    final GoogleMapController controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: AppConstants.initialZoom + 1),
      ),
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
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.magicGold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
