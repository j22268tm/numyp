import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import 'api_client_provider.dart';

class AuthState {
  const AuthState({this.user, this.isLoading = false, this.errorMessage});

  final AppUser? user;
  final bool isLoading;
  final String? errorMessage;

  AuthState copyWith({AppUser? user, bool? isLoading, String? errorMessage}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._client) : super(const AuthState());

  final ApiClient _client;

  Future<void> register({required String username, required String password}) async {
    if (username.isEmpty || password.isEmpty) {
      state = state.copyWith(errorMessage: 'ユーザー名とパスワードを入力してください');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _client.signup(username: username, password: password);
      await login(username: username, password: password);
    } on DioException catch (e) {
      final detail = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['detail'] as String?)
          : null;
      state = state.copyWith(
        isLoading: false,
        errorMessage: detail ?? '登録に失敗しました',
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: '登録に失敗しました');
    }
  }

  Future<void> login({required String username, required String password}) async {
    if (username.isEmpty || password.isEmpty) {
      state = state.copyWith(errorMessage: 'ユーザー名とパスワードを入力してください');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final token = await _client.login(username: username, password: password);
      final user = await _client.fetchCurrentUser(token);
      state = AuthState(user: user, isLoading: false);
    } on DioException catch (e) {
      final detail = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['detail'] as String?)
          : null;
      state = state.copyWith(
        isLoading: false,
        errorMessage: detail ?? 'ログインに失敗しました',
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: 'ログインに失敗しました');
    }
  }

  void logout() {
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthNotifier(client);
});
