import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/constants.dart';
import '../models/quest.dart';
import '../models/spot.dart';
import '../models/user.dart';
import '../models/app_notification.dart';

class ApiClient {
  ApiClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConstants.apiBaseUrl,
              connectTimeout: const Duration(
                seconds: AppConstants.requestTimeoutSeconds,
              ),
              receiveTimeout: const Duration(
                seconds: AppConstants.requestTimeoutSeconds,
              ),
            ),
          );

  final Dio _dio;

  Options _authOptions(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  Future<List<Spot>> fetchSpots() async {
    final response = await _dio.get('/spots');
    final data = response.data as List<dynamic>;
    return data
        .map((item) => Spot.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> signup({
    required String username,
    required String password,
  }) async {
    debugPrint('[API] サインアップリクエスト送信');
    debugPrint('[API] URL: ${AppConstants.apiBaseUrl}/auth/signup');
    debugPrint('[API] ユーザー名: $username');

    try {
      final response = await _dio.post(
        '/auth/signup',
        data: {'username': username, 'password': password},
      );
      debugPrint('[API] サインアップ成功 - ステータス: ${response.statusCode}');
    } catch (e) {
      debugPrint('[API] サインアップ失敗: $e');
      rethrow;
    }
  }

  Future<String> login({
    required String username,
    required String password,
  }) async {
    debugPrint('[API] ログインリクエスト送信');
    debugPrint('[API] URL: ${AppConstants.apiBaseUrl}/auth/login');
    debugPrint('[API] ユーザー名: $username');

    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'username': username, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      debugPrint('[API] ログイン成功 - ステータス: ${response.statusCode}');

      final data = response.data as Map<String, dynamic>;
      final token = data['access_token'] as String;
      debugPrint('[API] トークン取得成功 (長さ: ${token.length})');
      return token;
    } catch (e) {
      debugPrint('[API] ログイン失敗: $e');
      rethrow;
    }
  }

  Future<AppUser> fetchCurrentUser(String token) async {
    final response = await _dio.get('/users/me', options: _authOptions(token));
    return AppUser.fromApi(response.data as Map<String, dynamic>, token);
  }

  Future<Spot> createSpot({
    required String token,
    required double lat,
    required double lng,
    required String title,
    String? description,
    CrowdLevel crowdLevel = CrowdLevel.medium,
    int rating = 3,
    String? imageBase64,
  }) async {
    final response = await _dio.post(
      '/spots',
      data: {
        'lat': lat,
        'lng': lng,
        'title': title,
        'description': description,
        'crowd_level': crowdLevel.apiValue,
        'rating': rating,
        'image_base64': imageBase64,
      },
      options: _authOptions(token),
    );

    return Spot.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Spot> updateSpot({
    required String token,
    required String id,
    double? lat,
    double? lng,
    String? title,
    String? description,
    CrowdLevel? crowdLevel,
    int? rating,
    String? imageBase64,
  }) async {
    final payload = <String, dynamic>{
      'lat': lat,
      'lng': lng,
      'title': title,
      'description': description,
      'crowd_level': crowdLevel?.apiValue,
      'rating': rating,
      'image_base64': imageBase64,
    }..removeWhere((_, value) => value == null);

    final response = await _dio.put(
      '/spots/$id',
      data: payload,
      options: _authOptions(token),
    );

    return Spot.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteSpot({required String token, required String id}) async {
    await _dio.delete('/spots/$id', options: _authOptions(token));
  }

  // --- Quests ---
  Future<List<Quest>> fetchQuests({required String token}) async {
    final response = await _dio.get('/quests', options: _authOptions(token));
    final data = response.data as List<dynamic>;
    return data
        .map((item) => Quest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Quest> createQuest({
    required String token,
    required String title,
    required String description,
    required LatLng location,
    int radiusMeters = 200,
    required int bountyCoins,
    DateTime? expiresAt,
  }) async {
    final response = await _dio.post(
      '/quests',
      data: {
        'title': title,
        'description': description,
        'lat': location.latitude,
        'lng': location.longitude,
        'radius_meters': radiusMeters,
        'bounty_coins': bountyCoins,
        'expires_at': expiresAt?.toIso8601String(),
      },
      options: _authOptions(token),
    );

    return Quest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Quest> acceptQuest({
    required String token,
    required String questId,
    LatLng? currentLocation,
  }) async {
    final response = await _dio.post(
      '/quests/$questId/accept',
      data: {
        'lat': currentLocation?.latitude,
        'lng': currentLocation?.longitude,
      }..removeWhere((_, value) => value == null),
      options: _authOptions(token),
    );

    return Quest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Quest> submitQuestReport({
    required String token,
    required String questId,
    String? comment,
    LatLng? reportLocation,
    String? imageBase64,
  }) async {
    final response = await _dio.post(
      '/quests/$questId/report',
      data: {
        'comment': comment,
        'latitude': reportLocation?.latitude,
        'longitude': reportLocation?.longitude,
        'image_base64': imageBase64,
      }..removeWhere((_, value) => value == null),
      options: _authOptions(token),
    );

    return Quest.fromJson(response.data as Map<String, dynamic>);
  }

  // --- Notifications ---
  Future<List<AppNotification>> fetchNotifications({
    required String token,
    bool unreadOnly = false,
    int limit = 100,
  }) async {
    final response = await _dio.get(
      '/notifications',
      queryParameters: {'unread_only': unreadOnly, 'limit': limit},
      options: _authOptions(token),
    );
    final data = response.data as List<dynamic>;
    return data
        .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AppNotification> markNotificationRead({
    required String token,
    required String notificationId,
  }) async {
    final response = await _dio.post(
      '/notifications/$notificationId/read',
      options: _authOptions(token),
    );
    return AppNotification.fromJson(response.data as Map<String, dynamic>);
  }
}
