import 'dart:convert';
import 'package:flutter/services.dart';

class AppConstants {
  static Map<String, dynamic>? _envConfig;

  /// env.jsonを読み込む
  static Future<void> loadEnv() async {
    final String envString = await rootBundle.loadString('env.json');
    _envConfig = json.decode(envString);
  }

  /// APIのベースURL
  static String get apiBaseUrl {
    return _envConfig?['API_BASE_URL'] ?? 'http://localhost:8000';
  }

  /// Google Maps API Key
  static String get gmapApiKey {
    return _envConfig?['GMAP_API_KEY'] ?? '';
  }

  /// 地図初期位置
  static const double initialLatitude = 35.6377437;
  static const double initialLongitude = 140.2032806;
  static const double initialZoom = 17.0;

  /// API通信のタイムアウト秒数
  static const int requestTimeoutSeconds = 20;
}
