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

  factory QuestParticipant.fromJson(Map<String, dynamic> json) {
    final walkerJson = json['walker'] as Map<String, dynamic>?;
    if (walkerJson == null) {
      throw const FormatException('Missing walker info in participant');
    }
    DateTime? _parseDate(String? value) =>
        value == null ? null : DateTime.tryParse(value);

    return QuestParticipant(
      id: json['id'] as String,
      status: QuestParticipantStatusExtension.fromString(json['status'] as String?),
      walker: AuthorInfo.fromJson(walkerJson),
      acceptedAt: _parseDate(json['accepted_at'] as String?),
      reportedAt: _parseDate(json['reported_at'] as String?),
      rewardPaidAt: _parseDate(json['reward_paid_at'] as String?),
      distanceAtAcceptM: (json['distance_at_accept_m'] as num?)?.toInt(),
      photoUrl: json['photo_url'] as String?,
      comment: json['comment'] as String?,
      reportLatitude: (json['report_latitude'] as num?)?.toDouble(),
      reportLongitude: (json['report_longitude'] as num?)?.toDouble(),
    );
  }

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

  factory Quest.fromJson(Map<String, dynamic> json) {
    final locationJson = json['location'] as Map<String, dynamic>?;
    final requesterJson = json['requester'] as Map<String, dynamic>?;
    final participantsJson = json['participants'] as List<dynamic>? ?? const [];

    if (locationJson == null || requesterJson == null) {
      throw const FormatException('Missing required quest fields');
    }

    DateTime? _parseDate(String? value) =>
        value == null ? null : DateTime.tryParse(value);

    final lat = (locationJson['lat'] as num?)?.toDouble();
    final lng = (locationJson['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      throw const FormatException('Quest location is invalid');
    }

    return Quest(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      location: LatLng(lat, lng),
      radiusMeters: (json['radius_meters'] as num?)?.toInt() ?? 0,
      bountyCoins: (json['bounty_coins'] as num?)?.toInt() ?? 0,
      lockedBountyCoins: (json['locked_bounty_coins'] as num?)?.toInt() ?? 0,
      status: QuestStatusExtension.fromString(json['status'] as String?),
      requester: AuthorInfo.fromJson(requesterJson),
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: _parseDate(json['expires_at'] as String?),
      acceptedAt: _parseDate(json['accepted_at'] as String?),
      completedAt: _parseDate(json['completed_at'] as String?),
      expiredAt: _parseDate(json['expired_at'] as String?),
      activeParticipantId: json['active_participant_id'] as String?,
      participants: participantsJson
          .map((p) => QuestParticipant.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

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

extension QuestStatusExtension on QuestStatus {
  static QuestStatus fromString(String? value) {
    switch (value) {
      case 'accepted':
        return QuestStatus.accepted;
      case 'completed':
        return QuestStatus.completed;
      case 'expired':
        return QuestStatus.expired;
      case 'cancelled':
        return QuestStatus.cancelled;
      case 'open':
      default:
        return QuestStatus.open;
    }
  }
}

extension QuestParticipantStatusExtension on QuestParticipantStatus {
  static QuestParticipantStatus fromString(String? value) {
    switch (value) {
      case 'accepted':
        return QuestParticipantStatus.accepted;
      case 'reported':
        return QuestParticipantStatus.reported;
      case 'settled':
        return QuestParticipantStatus.settled;
      case 'expired':
        return QuestParticipantStatus.expired;
      case 'declined':
        return QuestParticipantStatus.declined;
      case 'invited':
      default:
        return QuestParticipantStatus.invited;
    }
  }
}
