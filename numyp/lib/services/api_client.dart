import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/constants.dart';
import '../models/spot.dart';
import '../models/user.dart';

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
}
