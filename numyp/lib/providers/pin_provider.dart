import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/pin.dart';

class PinNotifier extends StateNotifier<List<Pin>> {
  PinNotifier() : super(_initialPins);

  static final _uuid = const Uuid();
  static final List<Pin> _initialPins = [
    Pin(
      id: _uuid.v4(),
      title: '初期ピン: 駅前',
      description: '待ち合わせ用のピン',
    ),
    Pin(
      id: _uuid.v4(),
      title: '初期ピン: カフェ',
      description: 'Wi-Fiが強いお気に入り',
    ),
  ];

  void addPin({required String title, String? description}) {
    final pin = Pin(
      id: _uuid.v4(),
      title: title,
      description: description,
    );
    state = [...state, pin];
  }

  void updatePin(Pin updatedPin) {
    state = state.map((pin) => pin.id == updatedPin.id ? updatedPin : pin).toList();
  }

  void deletePin(String id) {
    state = state.where((pin) => pin.id != id).toList();
  }
}

final pinProvider = StateNotifierProvider<PinNotifier, List<Pin>>((ref) {
  return PinNotifier();
});
