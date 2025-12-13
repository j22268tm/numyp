import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../models/quest.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quest_provider.dart';
import 'quest_completion_report_screen.dart';
import 'quest_notifications_screen.dart';

class QuestBoardScreen extends ConsumerStatefulWidget {
  const QuestBoardScreen({super.key});

  @override
  ConsumerState<QuestBoardScreen> createState() => _QuestBoardScreenState();
}

class _QuestBoardScreenState extends ConsumerState<QuestBoardScreen> {
  Position? _currentPosition;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      if (mounted) {
        setState(() => _currentPosition = position);
      }
    } catch (e) {
      setState(() => _locationError = '現在地を取得できませんでした ($e)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final questsAsync = ref.watch(questControllerProvider);
    final username = ref.watch(authProvider).user?.username ?? 'ウォーカー';
    final currentUserId = ref.watch(authProvider).user?.id;

    return Scaffold(
      backgroundColor: colors.midnightBackground,
      appBar: AppBar(
        title: const Text('依頼と解決'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '通知',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QuestNotificationsScreen()),
              );
            },
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context),
        backgroundColor: colors.magicGold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('クエスト作成'),
      ),
      body: RefreshIndicator(
        color: colors.magicGold,
        backgroundColor: colors.cardSurface,
        onRefresh: () => ref.read(questControllerProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _HeroHeader(
                username: username,
                subtitle: '「今ここ」をみんなで解決しよう',
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: questsAsync.when(
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'クエストの取得に失敗しました\n$error',
                      style: TextStyle(color: colors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (quests) {
                  if (quests.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'まだクエストがありません。\n右下の「クエスト作成」から追加してみましょう。',
                          style: TextStyle(color: colors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return SliverList.separated(
                    itemBuilder: (context, index) {
                      final quest = quests[index];
                      final distance = _distanceToQuest(quest);
                      return _QuestCard(
                        quest: quest,
                        distanceMeters: distance,
                        locationError: _locationError,
                        isRequester: currentUserId != null && currentUserId == quest.requester.id,
                        onAccept: () => _acceptQuest(quest),
                        onReport: () => _openReportSheet(context, quest),
                        onViewReport: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => QuestCompletionReportScreen(questId: quest.id),
                            ),
                          );
                        },
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: quests.length,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  int? _distanceToQuest(Quest quest) {
    if (_currentPosition == null) return null;
    final pos = _currentPosition!;
    return Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      quest.location.latitude,
      quest.location.longitude,
    ).round();
  }

  Future<void> _acceptQuest(Quest quest) async {
    final pos = _currentPosition;
    await ref
        .read(questControllerProvider.notifier)
        .acceptQuest(quest.id, currentLocation: pos == null ? null : LatLng(pos.latitude, pos.longitude));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「${quest.title}」を受け付けました')),
    );
  }

  Future<void> _openReportSheet(BuildContext context, Quest quest) async {
    final commentController = TextEditingController();
    final picker = ImagePicker();
    Uint8List? imageBytes;
    String? imageBase64;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colors = AppColors.of(context);
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickFromGallery() async {
              final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
              if (file == null) return;
              final bytes = await file.readAsBytes();
              if (bytes.length > 10 * 1024 * 1024) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('画像が大きすぎます（10MBまで）')),
                  );
                }
                return;
              }
              final lower = file.path.toLowerCase();
              final contentType = lower.endsWith('.png') ? 'image/png' : 'image/jpeg';
              setModalState(() {
                imageBytes = bytes;
                imageBase64 = 'data:$contentType;base64,${base64Encode(bytes)}';
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 12,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.cardSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white10),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '報告を送信',
                          style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '現地で撮影した写真と一言コメントを送ってください。',
                      style: TextStyle(color: colors.textSecondary, height: 1.3),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickFromGallery,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('写真を選ぶ'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (imageBytes != null)
                          IconButton(
                            tooltip: '写真を外す',
                            onPressed: () => setModalState(() {
                              imageBytes = null;
                              imageBase64 = null;
                            }),
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ],
                    ),
                    if (imageBytes != null) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Image.memory(imageBytes!, fit: BoxFit.cover),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: '例: 行列は5組程度で風は弱め。',
                        hintStyle: TextStyle(color: colors.textSecondary),
                        filled: true,
                        fillColor: Colors.black12,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.send_rounded),
                        onPressed: () => Navigator.of(context).pop(true),
                        label: const Text('報告する'),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      final pos = _currentPosition;
      await ref.read(questControllerProvider.notifier).submitReport(
            questId: quest.id,
            comment: commentController.text,
            reportLocation: pos == null ? null : LatLng(pos.latitude, pos.longitude),
            imageBase64: imageBase64,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('報告を送信しました')),
        );
      }
    }
  }

  Future<void> _openCreateSheet(BuildContext context) async {
    final titleController = TextEditingController();
    final detailController = TextEditingController();
    final bountyController = TextEditingController(text: '20');
    final pos = _currentPosition;

    final shouldCreate = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colors = AppColors.of(context);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            left: 16,
            right: 16,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: colors.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '調査依頼ピンを作成',
                      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: '今知りたいこと',
                    labelStyle: TextStyle(color: colors.textSecondary),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: detailController,
                  maxLines: 2,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: '依頼内容の詳細',
                    labelStyle: TextStyle(color: colors.textSecondary),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bountyController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: '懸賞金を設定（コイン）',
                    labelStyle: TextStyle(color: colors.textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.place_outlined),
                    onPressed: () => Navigator.of(context).pop(true),
                    label: Text(pos == null ? '現在地を使えません' : 'この場所にピンを立てる'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldCreate == true && pos != null) {
      final bounty = int.tryParse(bountyController.text) ?? 10;
      await ref.read(questControllerProvider.notifier).createQuest(
            title: titleController.text.isEmpty ? '新しい依頼' : titleController.text,
            description: detailController.text.isEmpty ? 'ウォーカーに状況を確認してほしい' : detailController.text,
            location: LatLng(pos.latitude, pos.longitude),
            bountyCoins: bounty,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('調査依頼ピンを作成しました')),
        );
      }
    }
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.username, required this.subtitle});

  final String username;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.magicGold.withValues(alpha: 0.28),
            colors.fantasyPurple.withValues(alpha: 0.25),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.radar_rounded, size: 28, color: Colors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ようこそ、$username',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: colors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.cardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, color: colors.magicGold, size: 18),
                const SizedBox(width: 6),
                Text('緊急クエスト', style: TextStyle(color: colors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.onAccept,
    required this.onReport,
    required this.onViewReport,
    required this.isRequester,
    this.distanceMeters,
    this.locationError,
  });

  final Quest quest;
  final VoidCallback onAccept;
  final VoidCallback onReport;
  final VoidCallback onViewReport;
  final bool isRequester;
  final int? distanceMeters;
  final String? locationError;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isOpen = quest.status == QuestStatus.open;
    final isAccepted = quest.status == QuestStatus.accepted;
    final isCompleted = quest.status == QuestStatus.completed;

    return Container(
      decoration: BoxDecoration(
        color: colors.cardSurface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusPill(status: quest.status),
              const SizedBox(width: 8),
              _CoinChip(value: quest.bountyCoins),
              const SizedBox(width: 8),
              if (distanceMeters != null)
                _DistanceChip(distance: distanceMeters!)
              else if (locationError != null)
                _WarningChip(label: '位置情報なし'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            quest.title,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            quest.description,
            style: TextStyle(color: colors.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 16, color: colors.magicGold),
              const SizedBox(width: 6),
              Text(
                quest.expiresAt != null
                    ? '期限: ${quest.expiresAt!.hour.toString().padLeft(2, '0')}:${quest.expiresAt!.minute.toString().padLeft(2, '0')} まで'
                    : '期限: 未設定',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 10),
              Icon(Icons.radar, size: 16, color: colors.fantasyPurple),
              const SizedBox(width: 4),
              Text('${quest.radiusMeters}m内', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isOpen || isAccepted)
                FilledButton.icon(
                  onPressed: isCompleted ? null : (isAccepted ? onReport : onAccept),
                  style: FilledButton.styleFrom(
                    backgroundColor: isAccepted ? colors.fantasyPurple : colors.magicGold,
                    foregroundColor: isAccepted ? Colors.white : Colors.black,
                  ),
                  icon: Icon(isAccepted ? Icons.camera_alt_rounded : Icons.flash_on_rounded),
                  label: Text(isAccepted ? '写真を送る' : '受ける'),
                ),
              if (isCompleted && isRequester)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: OutlinedButton.icon(
                    onPressed: onViewReport,
                    icon: const Icon(Icons.assignment_turned_in_outlined),
                    label: const Text('成果を見る'),
                  ),
                )
              else if (isCompleted)
                _CompletedLabel(colors: colors),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final QuestStatus status;

  Color _color(BuildContext context) {
    final colors = AppColors.of(context);
    switch (status) {
      case QuestStatus.open:
        return colors.magicGold.withValues(alpha: 0.16);
      case QuestStatus.accepted:
        return colors.fantasyPurple.withValues(alpha: 0.18);
      case QuestStatus.completed:
        return Colors.green.withOpacity(0.15);
      case QuestStatus.expired:
        return Colors.red.withOpacity(0.15);
      case QuestStatus.cancelled:
        return Colors.grey.withOpacity(0.2);
    }
  }

  String get label => switch (status) {
        QuestStatus.open => '募集中',
        QuestStatus.accepted => '対応中',
        QuestStatus.completed => '完了',
        QuestStatus.expired => '期限切れ',
        QuestStatus.cancelled => 'キャンセル',
      };

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _color(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CoinChip extends StatelessWidget {
  const _CoinChip({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.deepGold.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(Icons.local_atm_rounded, size: 16, color: colors.magicGold),
          const SizedBox(width: 6),
          Text('$value コイン', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _DistanceChip extends StatelessWidget {
  const _DistanceChip({required this.distance});

  final int distance;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final km = distance >= 1000;
    final label = km ? '${(distance / 1000).toStringAsFixed(1)} km' : '$distance m';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.fantasyPurple.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.navigation_rounded, size: 16),
          const SizedBox(width: 4),
          Text('距離 $label', style: TextStyle(color: colors.textPrimary)),
        ],
      ),
    );
  }
}

class _WarningChip extends StatelessWidget {
  const _WarningChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(label, style: TextStyle(color: colors.textPrimary)),
    );
  }
}

class _CompletedLabel extends StatelessWidget {
  const _CompletedLabel({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.verified_rounded, color: Colors.greenAccent.shade400),
        const SizedBox(width: 4),
        Text('最新の写真が届きました', style: TextStyle(color: colors.textSecondary)),
      ],
    );
  }
}
