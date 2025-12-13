import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/session_storage.dart';

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  return SessionStorage();
});
