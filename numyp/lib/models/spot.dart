import 'package:google_maps_flutter/google_maps_flutter.dart';

class Spot {
  Spot({
    required this.id,
    required this.createdAt,
    required this.location,
    required this.content,
    required this.status,
    required this.author,
    required this.skin,
  });

  final String id;
  final DateTime createdAt;
  final LatLng location;
  final SpotContent content;
  final SpotStatus status;
  final AuthorInfo author;
  final SkinInfo skin;

  factory Spot.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final createdAt = json['created_at'] as String?;
    final locationJson = json['location'] as Map<String, dynamic>?;
    final contentJson = json['content'] as Map<String, dynamic>?;
    final statusJson = json['status'] as Map<String, dynamic>?;
    final authorJson = json['author'] as Map<String, dynamic>?;
    final skinJson = json['skin'] as Map<String, dynamic>?;

    if (id == null ||
        createdAt == null ||
        locationJson == null ||
        contentJson == null ||
        statusJson == null ||
        authorJson == null ||
        skinJson == null) {
      throw const FormatException('Missing required spot fields');
    }

    final lat = (locationJson['lat'] as num?);
    final lng = (locationJson['lng'] as num?);
    if (lat == null || lng == null) {
      throw const FormatException('Location lat/lng are required');
    }

    return Spot(
      id: id,
      createdAt: DateTime.parse(createdAt),
      location: LatLng(
        lat.toDouble(),
        lng.toDouble(),
      ),
      content: SpotContent.fromJson(contentJson),
      status: SpotStatus.fromJson(statusJson),
      author: AuthorInfo.fromJson(authorJson),
      skin: SkinInfo.fromJson(skinJson),
    );
  }
}

class SpotContent {
  SpotContent({
    required this.title,
    this.description,
    this.imageUrl,
  });

  final String title;
  final String? description;
  final String? imageUrl;

  factory SpotContent.fromJson(Map<String, dynamic> json) {
    return SpotContent(
      title: json['title'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}

class SpotStatus {
  SpotStatus({
    required this.crowdLevel,
    required this.rating,
  });

  final CrowdLevel crowdLevel;
  final int rating;

  factory SpotStatus.fromJson(Map<String, dynamic> json) {
    return SpotStatus(
      crowdLevel: CrowdLevelExtension.fromString(json['crowd_level'] as String),
      rating: (json['rating'] as num).toInt(),
    );
  }
}

enum CrowdLevel { low, medium, high }

extension CrowdLevelExtension on CrowdLevel {
  String get label => switch (this) {
        CrowdLevel.low => '空いている',
        CrowdLevel.medium => '普通',
        CrowdLevel.high => '混雑',
      };

  static CrowdLevel fromString(String value) {
    switch (value.toLowerCase()) {
      case 'low':
        return CrowdLevel.low;
      case 'high':
        return CrowdLevel.high;
      default:
        return CrowdLevel.medium;
    }
  }

  String get apiValue {
    switch (this) {
      case CrowdLevel.low:
        return 'low';
      case CrowdLevel.high:
        return 'high';
      case CrowdLevel.medium:
        return 'medium';
    }
  }
}

class AuthorInfo {
  AuthorInfo({
    required this.id,
    required this.username,
    this.iconUrl,
  });

  final String id;
  final String username;
  final String? iconUrl;

  factory AuthorInfo.fromJson(Map<String, dynamic> json) {
    return AuthorInfo(
      id: json['id'] as String,
      username: json['username'] as String,
      iconUrl: json['icon_url'] as String?,
    );
  }
}

class SkinInfo {
  SkinInfo({
    required this.id,
    required this.name,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String? imageUrl;

  factory SkinInfo.fromJson(Map<String, dynamic> json) {
    return SkinInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String?,
    );
  }
}
