import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Monitors network connectivity and fires callbacks when the network is
/// restored so pending sync items can be processed.
///
/// NOTE: Uses the connectivity_plus v5 API where [Connectivity.checkConnectivity]
/// and [Connectivity.onConnectivityChanged] return a single [ConnectivityResult].
class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  bool _isOnline = false;
  StreamSubscription<ConnectivityResult>? _subscription;
  bool _isDispatchingRestore = false;

  bool get isOnline => _isOnline;

  final List<FutureOr<void> Function()> _onRestoreCallbacks = [];

  /// Start monitoring. Should be called once at app startup.
  Future<void> init() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _isResultOnline(result);
    debugPrint('[ConnectivityService] init — result=$result isOnline=$_isOnline');

    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = _isResultOnline(result);
      debugPrint('[ConnectivityService] changed — result=$result isOnline=$_isOnline');
      if (!wasOnline && _isOnline) {
        unawaited(_dispatchRestoreCallbacks());
      }
    });
  }

  Future<void> _dispatchRestoreCallbacks() async {
    if (_isDispatchingRestore) {
      debugPrint('[ConnectivityService] restore callbacks already running, skipping duplicate trigger');
      return;
    }
    _isDispatchingRestore = true;
    try {
      debugPrint('[ConnectivityService] network restored — '
          'triggering ${_onRestoreCallbacks.length} callback(s)');
      final callbacks = List<FutureOr<void> Function()>.from(_onRestoreCallbacks);
      for (final cb in callbacks) {
        await cb();
      }
    } catch (e, st) {
      debugPrint('[ConnectivityService] restore callback failed: $e\n$st');
    } finally {
      _isDispatchingRestore = false;
    }
  }

  /// Returns true when active connection is not [ConnectivityResult.none].
  bool _isResultOnline(ConnectivityResult result) {
    return result != ConnectivityResult.none;
  }

  /// Register a callback to be called when network is restored.
  void onNetworkRestored(FutureOr<void> Function() callback) {
    _onRestoreCallbacks.add(callback);
  }

  /// Cancel the connectivity subscription. Call on app teardown if needed.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _onRestoreCallbacks.clear();
  }
}