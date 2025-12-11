import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/spot.dart';
import '../services/api_client.dart';
import 'api_client_provider.dart';
import 'auth_provider.dart';

class SpotsController extends AsyncNotifier<List<Spot>> {
  @override
  Future<List<Spot>> build() async {
    return _fetchSpots();
  }

  ApiClient get _client => ref.read(apiClientProvider);

  Future<List<Spot>> _fetchSpots() => _client.fetchSpots();

  String _requireToken() {
    final token = ref.read(authProvider).user?.accessToken;
    if (token == null) {
      throw StateError('ログインしてください');
    }
    return token;
  }

  Future<void> refreshSpots() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchSpots);
  }

  Future<Spot> createSpot({
    required double lat,
    required double lng,
    required String title,
    String? description,
    CrowdLevel crowdLevel = CrowdLevel.medium,
    int rating = 3,
  }) async {
    final token = _requireToken();
    final newSpot = await _client.createSpot(
      token: token,
      lat: lat,
      lng: lng,
      title: title,
      description: description,
      crowdLevel: crowdLevel,
      rating: rating,
    );

    final current = state.valueOrNull ?? <Spot>[];
    state = AsyncValue.data([...current, newSpot]);
    return newSpot;
  }

  Future<Spot> updateSpot({
    required String id,
    required double lat,
    required double lng,
    required String title,
    String? description,
    required CrowdLevel crowdLevel,
    required int rating,
  }) async {
    final token = _requireToken();
    final updatedSpot = await _client.updateSpot(
      token: token,
      id: id,
      lat: lat,
      lng: lng,
      title: title,
      description: description,
      crowdLevel: crowdLevel,
      rating: rating,
    );

    final current = state.valueOrNull ?? <Spot>[];
    state = AsyncValue.data([
      for (final spot in current) spot.id == updatedSpot.id ? updatedSpot : spot
    ]);
    return updatedSpot;
  }

  Future<void> deleteSpot(String id) async {
    final token = _requireToken();
    await _client.deleteSpot(token: token, id: id);
    final current = state.valueOrNull ?? <Spot>[];
    state = AsyncValue.data(
      current.where((spot) => spot.id != id).toList(),
    );
    final selected = ref.read(selectedSpotProvider);
    if (selected?.id == id) {
      ref.read(selectedSpotProvider.notifier).state = null;
    }
  }
}

final spotsControllerProvider =
    AsyncNotifierProvider<SpotsController, List<Spot>>(SpotsController.new);

final selectedSpotProvider = StateProvider<Spot?>((ref) => null);

final markerProvider = Provider<Set<Marker>>((ref) {
  final spotsAsync = ref.watch(spotsControllerProvider);
  return spotsAsync.maybeWhen(
    data: (spots) {
      return spots
          .map(
            (spot) => Marker(
              markerId: MarkerId(spot.id),
              position: spot.location,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueYellow,
              ),
              onTap: () => ref.read(selectedSpotProvider.notifier).state = spot,
            ),
          )
          .toSet();
    },
    orElse: () => <Marker>{},
  );
});
