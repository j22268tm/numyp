import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numyp/services/session_storage.dart';

/// FlutterSecureStorageのモックを作成
class MockSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _storage[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.remove(key);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.clear();
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage.containsKey(key);
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return Map.from(_storage);
  }
}

void main() {
  group('SessionStorage', () {
    late SessionStorage sessionStorage;
    late MockSecureStorage mockStorage;

    setUp(() {
      mockStorage = MockSecureStorage();
      sessionStorage = SessionStorage(storage: mockStorage);
    });

    test('saveToken should store token', () async {
      const testToken = 'test_token_12345';
      await sessionStorage.saveToken(testToken);

      final storedToken = await sessionStorage.getToken();
      expect(storedToken, equals(testToken));
    });

    test('getToken should return null when no token is stored', () async {
      final token = await sessionStorage.getToken();
      expect(token, isNull);
    });

    test('clearToken should remove stored token', () async {
      const testToken = 'test_token_12345';
      await sessionStorage.saveToken(testToken);

      // トークンが保存されていることを確認
      var storedToken = await sessionStorage.getToken();
      expect(storedToken, equals(testToken));

      // トークンをクリア
      await sessionStorage.clearToken();

      // トークンがクリアされていることを確認
      storedToken = await sessionStorage.getToken();
      expect(storedToken, isNull);
    });

    test('clearAll should remove all data', () async {
      const testToken = 'test_token_12345';
      await sessionStorage.saveToken(testToken);

      // トークンが保存されていることを確認
      var storedToken = await sessionStorage.getToken();
      expect(storedToken, equals(testToken));

      // すべてのデータをクリア
      await sessionStorage.clearAll();

      // トークンがクリアされていることを確認
      storedToken = await sessionStorage.getToken();
      expect(storedToken, isNull);
    });

    test('saveToken should overwrite existing token', () async {
      const firstToken = 'first_token';
      const secondToken = 'second_token';

      await sessionStorage.saveToken(firstToken);
      var storedToken = await sessionStorage.getToken();
      expect(storedToken, equals(firstToken));

      await sessionStorage.saveToken(secondToken);
      storedToken = await sessionStorage.getToken();
      expect(storedToken, equals(secondToken));
    });
  });
}
