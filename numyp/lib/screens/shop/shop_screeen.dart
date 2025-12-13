import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

/// ショップ画面
/// ユーザーがピンのスキンを閲覧・購入できる画面
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final colors = AppColors.of(context);

    // サンプルデータ（将来的にはAPIから取得）
    final sampleSkins = [
      {'id': '1', 'name': '基本ピン', 'price': 0, 'imageUrl': null},
      {'id': '2', 'name': 'ゴールドピン', 'price': 100, 'imageUrl': null},
      {'id': '3', 'name': 'シルバーピン', 'price': 50, 'imageUrl': null},
      {'id': '4', 'name': 'レインボーピン', 'price': 200, 'imageUrl': null},
      {'id': '5', 'name': 'ダイヤモンドピン', 'price': 500, 'imageUrl': null},
      {'id': '6', 'name': 'スターピン', 'price': 150, 'imageUrl': null},
    ];

    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        title: Text(
          'ショップ',
          style: TextStyle(
            color: colors.magicGold,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1C1C1C),
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colors.magicGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.magicGold, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.monetization_on, color: colors.magicGold, size: 20),
                const SizedBox(width: 6),
                Text(
                  '${user?.coins ?? 0}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ピンアイコングリッド
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: sampleSkins.length,
              itemBuilder: (context, index) {
                final skin = sampleSkins[index];
                final price = skin['price'] as int;
                final name = skin['name'] as String;
                final isPurchased = price == 0; // 基本ピンは購入済みとする

                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isPurchased
                          ? colors.magicGold
                          : Colors.grey.shade400,
                      width: isPurchased ? 2 : 1,
                    ),
                  ),
                  color: Colors.white,
                  child: InkWell(
                    onTap: () {
                      // 購入処理を実装
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$name の購入機能は開発中です'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ピンアイコン
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: colors.fantasyPurple.withValues(
                                alpha: 0.2,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isPurchased
                                    ? colors.magicGold
                                    : colors.fantasyPurple,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.push_pin,
                              size: 40,
                              color: isPurchased
                                  ? colors.magicGold
                                  : colors.fantasyPurple,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // スキン名
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),

                          // 価格または購入済み表示
                          if (isPurchased)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colors.magicGold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '購入済み',
                                style: TextStyle(
                                  color: colors.magicGold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.monetization_on,
                                  color: colors.magicGold,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$price',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
