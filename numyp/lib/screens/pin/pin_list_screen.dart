import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/spot.dart';
import '../../providers/spot_providers.dart';
import 'pin_form_screen.dart';

class PinListScreen extends ConsumerWidget {
  const PinListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotsAsync = ref.watch(spotsControllerProvider);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.midnightBackground,
      appBar: AppBar(
        title: const Text('スポット管理'),
        backgroundColor: colors.midnightBackground,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        backgroundColor: colors.magicGold,
        label: const Text('新規スポット'),
        icon: const Icon(Icons.add),
        foregroundColor: Colors.black,
      ),
      body: spotsAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: colors.magicGold)),
        error: (error, _) => _ErrorState(
          message: 'スポットの取得に失敗しました\n${error.toString()}',
          onRetry: () =>
              ref.read(spotsControllerProvider.notifier).refreshSpots(),
        ),
        data: (spots) {
          if (spots.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            color: colors.magicGold,
            backgroundColor: colors.cardSurface,
            onRefresh: () =>
                ref.read(spotsControllerProvider.notifier).refreshSpots(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final spot = spots[index];
                return _SpotTile(
                  spot: spot,
                  onTap: () => _openForm(context, ref, spot: spot),
                  onDelete: () => _confirmDelete(context, ref, spot),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: spots.length,
            ),
          );
        },
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    Spot? spot,
  }) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SpotFormScreen(spot: spot)));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Spot spot,
  ) async {
    final colors = AppColors.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.cardSurface,
          title: Text('スポットを削除', style: TextStyle(color: colors.textPrimary)),
          content: Text(
            '「${spot.content.title}」を削除しますか？',
            style: TextStyle(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                '削除',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      try {
        await ref.read(spotsControllerProvider.notifier).deleteSpot(spot.id);
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('削除しました')));
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }
}

class _SpotTile extends StatelessWidget {
  const _SpotTile({required this.spot, this.onTap, this.onDelete});

  final Spot spot;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.cardSurface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        isThreeLine: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        onTap: onTap,
        title: Text(
          spot.content.title,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              spot.content.description ?? '説明なし',
              style: TextStyle(color: colors.textSecondary, height: 1.2),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: colors.magicGold),
                const SizedBox(width: 4),
                Text(
                  '${spot.location.latitude.toStringAsFixed(5)}, ${spot.location.longitude.toStringAsFixed(5)}',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                spot.status.crowdLevel.label,
                style: TextStyle(color: colors.magicGold, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < spot.status.rating.clamp(1, 5)
                        ? Icons.star
                        : Icons.star_border,
                    size: 11,
                    color: colors.magicGold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.push_pin_outlined, color: colors.magicGold, size: 48),
          const SizedBox(height: 12),
          Text(
            '登録されたスポットはありません',
            style: TextStyle(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.magicGold,
              foregroundColor: Colors.black,
            ),
            child: const Text('再読み込み'),
          ),
        ],
      ),
    );
  }
}
