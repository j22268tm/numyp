import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// セッショントークンを安全に保存・取得・削除するサービス
class SessionStorage {
  SessionStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const String _tokenKey = 'session_token';

  /// セッショントークンを保存
  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
      debugPrint('[SessionStorage] トークンを保存しました');
    } catch (e) {
      debugPrint('[SessionStorage] トークン保存エラー: $e');
      rethrow;
    }
  }

  /// セッショントークンを取得
  Future<String?> getToken() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token != null) {
        debugPrint('[SessionStorage] トークンを取得しました');
      } else {
        debugPrint('[SessionStorage] トークンが見つかりませんでした');
      }
      return token;
    } catch (e) {
      debugPrint('[SessionStorage] トークン取得エラー: $e');
      return null;
    }
  }

  /// セッショントークンを削除
  Future<void> clearToken() async {
    try {
      await _storage.delete(key: _tokenKey);
      debugPrint('[SessionStorage] トークンを削除しました');
    } catch (e) {
      debugPrint('[SessionStorage] トークン削除エラー: $e');
      rethrow;
    }
  }

  /// すべてのデータをクリア
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      debugPrint('[SessionStorage] すべてのデータを削除しました');
    } catch (e) {
      debugPrint('[SessionStorage] データ削除エラー: $e');
      rethrow;
    }
  }
}
