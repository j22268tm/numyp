import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/spot.dart';
import '../services/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final spotsProvider = FutureProvider<List<Spot>>((ref) async {
  final client = ref.watch(apiClientProvider);
  return client.fetchSpots();
});

final selectedSpotProvider = StateProvider<Spot?>((ref) => null);

final markerProvider = Provider<Set<Marker>>((ref) {
  final spotsAsync = ref.watch(spotsProvider);
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
