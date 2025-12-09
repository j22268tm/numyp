import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/pin.dart';
import '../../providers/pin_provider.dart';
import 'pin_form_screen.dart';

class PinListScreen extends ConsumerWidget {
  const PinListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pins = ref.watch(pinProvider);

    return Scaffold(
      backgroundColor: AppColors.midnightBackground,
      appBar: AppBar(
        title: const Text('ピン管理'),
        backgroundColor: AppColors.midnightBackground,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        backgroundColor: AppColors.magicGold,
        label: const Text('新規ピン'),
        icon: const Icon(Icons.add),
        foregroundColor: Colors.black,
      ),
      body: pins.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final pin = pins[index];
                return _PinTile(
                  pin: pin,
                  onTap: () => _openForm(context, ref, pin: pin),
                  onDelete: () => ref.read(pinProvider.notifier).deletePin(pin.id),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: pins.length,
            ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref, {Pin? pin}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PinFormScreen(pin: pin)),
    );
  }
}

class _PinTile extends StatelessWidget {
  const _PinTile({required this.pin, this.onTap, this.onDelete});

  final Pin pin;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          pin.title,
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          pin.description ?? '説明なし',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        trailing: IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.push_pin_outlined, color: AppColors.magicGold, size: 48),
          SizedBox(height: 12),
          Text(
            '登録されたピンはありません',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
