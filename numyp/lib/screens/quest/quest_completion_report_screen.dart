import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/quest_provider.dart';

class QuestCompletionReportScreen extends ConsumerWidget {
  const QuestCompletionReportScreen({super.key, required this.questId});

  final String questId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final questsAsync = ref.watch(questControllerProvider);

    return Scaffold(
      backgroundColor: colors.midnightBackground,
      appBar: AppBar(
        title: const Text('成果報告'),
        backgroundColor: Colors.transparent,
      ),
      body: questsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            '読み込みに失敗しました\n$error',
            style: TextStyle(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
        data: (quests) {
          final quest = quests.where((q) => q.id == questId).firstOrNull;
          if (quest == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('クエストが見つかりません', style: TextStyle(color: colors.textSecondary)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => ref.read(questControllerProvider.notifier).refresh(),
                    child: const Text('更新する'),
                  ),
                ],
              ),
            );
          }

          final participant = quest.activeParticipant;
          final photoUrl = participant?.photoUrl;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                quest.title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '依頼者: ${quest.requester.username}',
                style: TextStyle(color: colors.textSecondary),
              ),
              if (participant != null)
                Text(
                  '報告者: ${participant.walker.username}',
                  style: TextStyle(color: colors.textSecondary),
                ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: colors.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('写真', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (photoUrl != null && photoUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Image.network(photoUrl, fit: BoxFit.cover),
                        ),
                      )
                    else
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text('写真はありません', style: TextStyle(color: colors.textSecondary)),
                      ),
                    const SizedBox(height: 14),
                    Text('コメント', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      participant?.comment?.isNotEmpty == true ? participant!.comment! : 'コメントはありません',
                      style: TextStyle(color: colors.textSecondary, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
