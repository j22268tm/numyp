import 'package:dio/dio.dart';

import '../config/constants.dart';
import '../models/spot.dart';
import '../models/user.dart';

class ApiClient {
  ApiClient({Dio? dio})
      : _dio = dio ??
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

  Future<void> signup({required String username, required String password}) async {
    await _dio.post('/auth/signup', data: {
      'username': username,
      'password': password,
    });
  }

  Future<String> login({required String username, required String password}) async {
    final response = await _dio.post(
      '/auth/login',
      data: {
        'username': username,
        'password': password,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final data = response.data as Map<String, dynamic>;
    return data['access_token'] as String;
  }

  Future<AppUser> fetchCurrentUser(String token) async {
    final response = await _dio.get(
      '/users/me',
      options: _authOptions(token),
    );
    return AppUser.fromApi(response.data as Map<String, dynamic>, token);
  }
}
