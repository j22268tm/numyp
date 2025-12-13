import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/constants.dart';
import '../models/quest.dart';
import '../models/spot.dart';
import 'auth_provider.dart';

class QuestController extends AsyncNotifier<List<Quest>> {
  @override
  Future<List<Quest>> build() async {
    return _seedQuests();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_seedQuests);
  }

  String _requireUserId() {
    final user = ref.read(authProvider).user;
    if (user == null) {
      throw StateError('ログインしてください');
    }
    return user.id;
  }

  AuthorInfo _currentWalker() {
    final user = ref.read(authProvider).user;
    if (user == null) {
      throw StateError('ログインしてください');
    }
    return AuthorInfo(
      id: user.id,
      username: user.username,
      iconUrl: user.iconUrl,
    );
  }

  Future<void> acceptQuest(String questId, {LatLng? currentLocation}) async {
    final walker = _currentWalker();
    final now = DateTime.now();
    final current = state.valueOrNull ?? await _seedQuests();

    final updated = current.map((quest) {
      if (quest.id != questId) return quest;

      final distance = currentLocation == null
          ? null
          : _distanceToMeters(currentLocation, quest.location);

      final participant = QuestParticipant(
        id: walker.id,
        walker: walker,
        status: QuestParticipantStatus.accepted,
        acceptedAt: now,
        distanceAtAcceptM: distance,
      );

      return quest.copyWith(
        status: QuestStatus.accepted,
        activeParticipantId: participant.id,
        acceptedAt: now,
        participants: [...quest.participants, participant],
      );
    }).toList();

    state = AsyncValue.data(updated);
  }

  Future<void> submitReport({
    required String questId,
    String? comment,
    LatLng? reportLocation,
  }) async {
    final walkerId = _requireUserId();
    final now = DateTime.now();
    final current = state.valueOrNull ?? await _seedQuests();

    final updated = current.map((quest) {
      if (quest.id != questId) return quest;

      final participants = quest.participants.map((p) {
        if (p.id != walkerId) return p;
        return p.copyWith(
          status: QuestParticipantStatus.reported,
          reportedAt: now,
          comment: comment,
          reportLatitude: reportLocation?.latitude,
          reportLongitude: reportLocation?.longitude,
        );
      }).toList();

      return quest.copyWith(
        status: QuestStatus.completed,
        participants: participants,
        completedAt: now,
      );
    }).toList();

    state = AsyncValue.data(updated);
  }

  Future<void> createQuest({
    required String title,
    required String description,
    required LatLng location,
    int radiusMeters = 200,
    required int bountyCoins,
    DateTime? expiresAt,
  }) async {
    final requester = _currentWalker();
    final now = DateTime.now();
    final newQuest = Quest(
      id: 'quest-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      location: location,
      radiusMeters: radiusMeters,
      bountyCoins: bountyCoins,
      lockedBountyCoins: bountyCoins,
      status: QuestStatus.open,
      requester: requester,
      createdAt: now,
      expiresAt: expiresAt,
      participants: const [],
      activeParticipantId: null,
    );

    final current = state.valueOrNull ?? await future;
    state = AsyncValue.data([newQuest, ...current]);
  }

  // --- Demo data ---
  Future<List<Quest>> _seedQuests() async {
    // Simulate network latency
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final now = DateTime.now();

    return [
      Quest(
        id: 'quest-1',
        title: '駅前カフェの混雑チェック',
        description: 'テラス席は空いているか、待ち時間を教えてほしい',
        location: const LatLng(AppConstants.initialLatitude, AppConstants.initialLongitude),
        radiusMeters: 200,
        bountyCoins: 20,
        lockedBountyCoins: 20,
        status: QuestStatus.open,
        requester: AuthorInfo(
          id: 'requester-1',
          username: '旅人A',
          iconUrl: null,
        ),
        createdAt: now.subtract(const Duration(minutes: 10)),
        expiresAt: now.add(const Duration(minutes: 30)),
        participants: const [],
      ),
      Quest(
        id: 'quest-2',
        title: '海辺の風の強さを確認',
        description: 'ウィンドブレーカーは必要そう？波の高さも写真でほしい',
        location: const LatLng(AppConstants.initialLatitude + 0.0012, AppConstants.initialLongitude + 0.0012),
        radiusMeters: 350,
        bountyCoins: 35,
        lockedBountyCoins: 35,
        status: QuestStatus.accepted,
        requester: AuthorInfo(
          id: 'requester-2',
          username: 'ミナ',
          iconUrl: null,
        ),
        createdAt: now.subtract(const Duration(minutes: 25)),
        acceptedAt: now.subtract(const Duration(minutes: 5)),
        expiresAt: now.add(const Duration(minutes: 20)),
        activeParticipantId: 'walker-7',
        participants: [
          QuestParticipant(
            id: 'walker-7',
            walker: AuthorInfo(
              id: 'walker-7',
              username: 'しおん',
              iconUrl: null,
            ),
            status: QuestParticipantStatus.accepted,
            acceptedAt: now.subtract(const Duration(minutes: 5)),
            distanceAtAcceptM: 180,
          ),
        ],
      ),
      Quest(
        id: 'quest-3',
        title: '夜のライトアップ状況',
        description: '公園のイルミネーションがまだ点灯しているか写真で教えて',
        location: const LatLng(AppConstants.initialLatitude - 0.0008, AppConstants.initialLongitude + 0.0015),
        radiusMeters: 250,
        bountyCoins: 18,
        lockedBountyCoins: 0,
        status: QuestStatus.completed,
        requester: AuthorInfo(
          id: 'requester-3',
          username: 'Nobu',
          iconUrl: null,
        ),
        createdAt: now.subtract(const Duration(hours: 1)),
        acceptedAt: now.subtract(const Duration(minutes: 50)),
        completedAt: now.subtract(const Duration(minutes: 5)),
        activeParticipantId: 'walker-9',
        participants: [
          QuestParticipant(
            id: 'walker-9',
            walker: AuthorInfo(
              id: 'walker-9',
              username: 'Risa',
              iconUrl: null,
            ),
            status: QuestParticipantStatus.reported,
            acceptedAt: now.subtract(const Duration(minutes: 50)),
            reportedAt: now.subtract(const Duration(minutes: 5)),
            comment: '人も少なくて撮影しやすいです',
            reportLatitude: AppConstants.initialLatitude - 0.0008,
            reportLongitude: AppConstants.initialLongitude + 0.0015,
          ),
        ],
      ),
    ];
  }

  int? _distanceToMeters(LatLng a, LatLng b) {
    final earthRadius = 6371000; // meters
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLon = _toRadians(b.longitude - a.longitude);
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);

    final aCalc = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.sin(dLon / 2) * math.sin(dLon / 2) * math.cos(lat1) * math.cos(lat2));
    final c = 2 * math.atan2(math.sqrt(aCalc), math.sqrt(1 - aCalc));
    return (earthRadius * c).round();
  }

  double _toRadians(double degree) => degree * (math.pi / 180);
}

final questControllerProvider =
    AsyncNotifierProvider<QuestController, List<Quest>>(QuestController.new);
