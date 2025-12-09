class AppConstants {
  /// APIのベースURL。本番環境では--dart-defineで上書きしてください。
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// 地図初期位置
  static const double initialLatitude = 35.6377437;
  static const double initialLongitude = 140.2032806;
  static const double initialZoom = 17.0;

  /// API通信のタイムアウト秒数
  static const int requestTimeoutSeconds = 20;
}
