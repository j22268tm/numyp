import 'package:dio/dio.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import 'api_client_provider.dart';

class AuthState {
  const AuthState({this.user, this.isLoading = false, this.errorMessage});

  final AppUser? user;
  final bool isLoading;
  final String? errorMessage;

  AuthState copyWith({
    AppUser? user,
    bool clearUser = false,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._client) : super(const AuthState());

  final ApiClient _client;

  Future<void> register({
    required String username,
    required String password,
  }) async {
    debugPrint('=== 登録処理開始 ===');
    debugPrint('ユーザー名: $username');

    if (username.isEmpty || password.isEmpty) {
      debugPrint('エラー: ユーザー名またはパスワードが空です');
      state = state.copyWith(errorMessage: 'ユーザー名とパスワードを入力してください');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      debugPrint('サインアップAPI呼び出し中...');
      await _client.signup(username: username, password: password);
      debugPrint('サインアップ成功 - ログイン処理へ');
      await login(username: username, password: password);
    } on DioException catch (e) {
      debugPrint('=== DioException発生 ===');
      debugPrint('ステータスコード: ${e.response?.statusCode}');
      debugPrint('レスポンスデータ: ${e.response?.data}');
      debugPrint('エラーメッセージ: ${e.message}');
      debugPrint('エラータイプ: ${e.type}');

      final detail = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['detail'] as String?)
          : null;
      state = state.copyWith(
        isLoading: false,
        errorMessage: detail ?? '登録に失敗しました (ステータス: ${e.response?.statusCode})',
      );
    } catch (e, stackTrace) {
      debugPrint('=== 予期しないエラー ===');
      debugPrint('エラー: $e');
      debugPrint('スタックトレース: $stackTrace');
      state = state.copyWith(isLoading: false, errorMessage: '登録に失敗しました: $e');
    }
    debugPrint('=== 登録処理終了 ===');
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    debugPrint('=== ログイン処理開始 ===');
    debugPrint('ユーザー名: $username');

    if (username.isEmpty || password.isEmpty) {
      debugPrint('エラー: ユーザー名またはパスワードが空です');
      state = state.copyWith(errorMessage: 'ユーザー名とパスワードを入力してください');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      debugPrint('ログインAPI呼び出し中...');
      final token = await _client.login(username: username, password: password);
      debugPrint('ログイン成功 - トークン取得完了');
      debugPrint('ユーザー情報取得中...');
      final user = await _client.fetchCurrentUser(token);
      debugPrint('ユーザー情報取得成功: ${user.username}');
      state = AuthState(user: user, isLoading: false);
    } on DioException catch (e) {
      debugPrint('=== DioException発生(ログイン) ===');
      debugPrint('ステータスコード: ${e.response?.statusCode}');
      debugPrint('レスポンスデータ: ${e.response?.data}');
      debugPrint('エラーメッセージ: ${e.message}');

      final detail = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['detail'] as String?)
          : null;
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            detail ?? 'ログインに失敗しました (ステータス: ${e.response?.statusCode})',
      );
    } catch (e, stackTrace) {
      debugPrint('=== 予期しないエラー(ログイン) ===');
      debugPrint('エラー: $e');
      debugPrint('スタックトレース: $stackTrace');
      state = state.copyWith(isLoading: false, errorMessage: 'ログインに失敗しました: $e');
    }
    debugPrint('=== ログイン処理終了 ===');
  }

  void logout() {
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthNotifier(client);
});
