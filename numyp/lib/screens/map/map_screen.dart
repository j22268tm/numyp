import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../config/theme.dart';
import '../../widgets/glass_card.dart';

/// メイン地図画面
/// 夜のディズニーリゾートをイメージしたデザイン
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  // 初期位置: 千城台駅付近
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(35.6377437, 140.2032806),
    zoom: 18.0,
  );

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1層目: Google Map
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _kGooglePlex,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            // Google Map ID を適用（カスタムスタイル用）
            cloudMapId: '3594a289df4f7f14d77cb4e2',
            // 不要なUIを非表示
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
          ),

          // 2層目: 上部のステータスバー（コイン・ユーザー情報）
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: GlassCard(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // コイン表示
                  Row(
                    children: [
                      Icon(
                        Icons.monetization_on,
                        color: AppColors.magicGold,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '1,234',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  // ユーザーアイコン
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.fantasyPurple,
                    child: Icon(Icons.person, color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),
          ),

          // 3層目: 右下の現在地ボタン
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'location',
              onPressed: _goToCurrentLocation,
              backgroundColor: AppColors.cardSurface.withOpacity(0.8),
              child: Icon(Icons.my_location, color: AppColors.magicGold),
            ),
          ),
        ],
      ),

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
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'shop',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'mypage'),
        ],
      ),
    );
  }

  /// 現在地へ移動（仮実装）
  Future<void> _goToCurrentLocation() async {
    final GoogleMapController controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(_kGooglePlex),
    );
  }
}
