import 'package:dio/dio.dart';

import '../config/constants.dart';
import '../models/spot.dart';

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

  Future<List<Spot>> fetchSpots() async {
    final response = await _dio.get('/spots');
    final data = response.data as List<dynamic>;
    return data.map((item) => Spot.fromJson(item as Map<String, dynamic>)).toList();
  }
}
