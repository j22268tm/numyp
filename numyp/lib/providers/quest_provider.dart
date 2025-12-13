import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/quest.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';
import 'api_client_provider.dart';

class QuestController extends AsyncNotifier<List<Quest>> {
  @override
  Future<List<Quest>> build() async {
    return _fetchQuests();
  }

  ApiClient get _client => ref.read(apiClientProvider);

  String _requireToken() {
    final token = ref.read(authProvider).user?.accessToken;
    if (token == null) {
      throw StateError('ログインしてください');
    }
    return token;
  }

  Future<List<Quest>> _fetchQuests() {
    final token = _requireToken();
    return _client.fetchQuests(token: token);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchQuests);
  }

  Future<void> acceptQuest(String questId, {LatLng? currentLocation}) async {
    final token = _requireToken();
    final quest = await _client.acceptQuest(
      token: token,
      questId: questId,
      currentLocation: currentLocation,
    );
    _replaceQuest(quest);
  }

  Future<void> submitReport({
    required String questId,
    String? comment,
    LatLng? reportLocation,
    String? imageBase64,
  }) async {
    final token = _requireToken();
    final quest = await _client.submitQuestReport(
      token: token,
      questId: questId,
      comment: comment,
      reportLocation: reportLocation,
      imageBase64: imageBase64,
    );
    _replaceQuest(quest);
  }

  Future<void> createQuest({
    required String title,
    required String description,
    required LatLng location,
    int radiusMeters = 200,
    required int bountyCoins,
    DateTime? expiresAt,
  }) async {
    final token = _requireToken();
    final quest = await _client.createQuest(
      token: token,
      title: title,
      description: description,
      location: location,
      radiusMeters: radiusMeters,
      bountyCoins: bountyCoins,
      expiresAt: expiresAt,
    );
    final current = state.valueOrNull ?? await future;
    state = AsyncValue.data([quest, ...current]);
  }

  void _replaceQuest(Quest quest) {
    final current = state.valueOrNull ?? <Quest>[];
    var replaced = false;
    final next = current.map((q) {
      if (q.id == quest.id) {
        replaced = true;
        return quest;
      }
      return q;
    }).toList();
    if (!replaced) {
      next.insert(0, quest);
    }
    state = AsyncValue.data(next);
  }
}

final questControllerProvider =
    AsyncNotifierProvider<QuestController, List<Quest>>(QuestController.new);
