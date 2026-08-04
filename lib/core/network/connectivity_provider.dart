import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream of connectivity changes from connectivity_plus.
final connectivityStatusProvider = StreamProvider<ConnectivityResult>((ref) {
  final connectivity = Connectivity();
  return (connectivity.onConnectivityChanged as Stream<dynamic>).map((event) {
    if (event is List) {
      // connectivity_plus v5+ returns a list
      return (event.isNotEmpty) ? (event.first as ConnectivityResult) : ConnectivityResult.none;
    }
    // Fallback for older versions or unexpected types
    return event as ConnectivityResult;
  });
});

/// Simple boolean flag for whether the app is currently offline.
final isOfflineProvider = Provider<bool>((ref) {
  final asyncStatus = ref.watch(connectivityStatusProvider);
  return asyncStatus.maybeWhen(
    data: (status) => status == ConnectivityResult.none,
    orElse: () => false,
  );
});
