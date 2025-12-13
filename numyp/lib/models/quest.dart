import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'spot.dart';

enum QuestStatus { open, accepted, completed, expired, cancelled }

enum QuestParticipantStatus {
  invited,
  accepted,
  reported,
  settled,
  expired,
  declined,
}

class QuestParticipant {
  QuestParticipant({
    required this.id,
    required this.status,
    required this.walker,
    this.acceptedAt,
    this.reportedAt,
    this.rewardPaidAt,
    this.distanceAtAcceptM,
    this.photoUrl,
    this.comment,
    this.reportLatitude,
    this.reportLongitude,
  });

  final String id;
  final QuestParticipantStatus status;
  final AuthorInfo walker;
  final DateTime? acceptedAt;
  final DateTime? reportedAt;
  final DateTime? rewardPaidAt;
  final int? distanceAtAcceptM;
  final String? photoUrl;
  final String? comment;
  final double? reportLatitude;
  final double? reportLongitude;

  QuestParticipant copyWith({
    QuestParticipantStatus? status,
    DateTime? acceptedAt,
    DateTime? reportedAt,
    DateTime? rewardPaidAt,
    int? distanceAtAcceptM,
    String? photoUrl,
    String? comment,
    double? reportLatitude,
    double? reportLongitude,
  }) {
    return QuestParticipant(
      id: id,
      status: status ?? this.status,
      walker: walker,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      reportedAt: reportedAt ?? this.reportedAt,
      rewardPaidAt: rewardPaidAt ?? this.rewardPaidAt,
      distanceAtAcceptM: distanceAtAcceptM ?? this.distanceAtAcceptM,
      photoUrl: photoUrl ?? this.photoUrl,
      comment: comment ?? this.comment,
      reportLatitude: reportLatitude ?? this.reportLatitude,
      reportLongitude: reportLongitude ?? this.reportLongitude,
    );
  }
}

class Quest {
  Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.radiusMeters,
    required this.bountyCoins,
    required this.lockedBountyCoins,
    required this.status,
    required this.requester,
    required this.createdAt,
    this.expiresAt,
    this.acceptedAt,
    this.completedAt,
    this.expiredAt,
    this.activeParticipantId,
    this.participants = const [],
  });

  final String id;
  final String title;
  final String description;
  final LatLng location;
  final int radiusMeters;
  final int bountyCoins;
  final int lockedBountyCoins;
  final QuestStatus status;
  final AuthorInfo requester;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? expiredAt;
  final String? activeParticipantId;
  final List<QuestParticipant> participants;

  Quest copyWith({
    String? title,
    String? description,
    LatLng? location,
    int? radiusMeters,
    int? bountyCoins,
    int? lockedBountyCoins,
    QuestStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
    DateTime? expiredAt,
    String? activeParticipantId,
    List<QuestParticipant>? participants,
  }) {
    return Quest(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      bountyCoins: bountyCoins ?? this.bountyCoins,
      lockedBountyCoins: lockedBountyCoins ?? this.lockedBountyCoins,
      status: status ?? this.status,
      requester: requester,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      expiredAt: expiredAt ?? this.expiredAt,
      activeParticipantId: activeParticipantId ?? this.activeParticipantId,
      participants: participants ?? this.participants,
    );
  }

  QuestParticipant? get activeParticipant {
    if (activeParticipantId == null) return null;
    try {
      return participants.firstWhere((p) => p.id == activeParticipantId);
    } catch (_) {
      return null;
    }
  }
}
