import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../services/api_client.dart';
import 'api_client_provider.dart';
import 'auth_provider.dart';

class NotificationController extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    return _fetchNotifications();
  }

  ApiClient get _client => ref.read(apiClientProvider);

  String _requireToken() {
    final token = ref.read(authProvider).user?.accessToken;
    if (token == null) {
      throw StateError('ログインしてください');
    }
    return token;
  }

  Future<List<AppNotification>> _fetchNotifications({bool unreadOnly = false}) {
    final token = _requireToken();
    return _client.fetchNotifications(token: token, unreadOnly: unreadOnly);
  }

  Future<void> refresh({bool unreadOnly = false}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchNotifications(unreadOnly: unreadOnly));
  }

  Future<void> markRead(String notificationId) async {
    final token = _requireToken();
    final updated = await _client.markNotificationRead(
      token: token,
      notificationId: notificationId,
    );

    final current = state.valueOrNull ?? <AppNotification>[];
    final next = current
        .map((n) => n.id == notificationId ? updated : n)
        .toList(growable: false);
    state = AsyncValue.data(next);
  }
}

final notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, List<AppNotification>>(
  NotificationController.new,
);

