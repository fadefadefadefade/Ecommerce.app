import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/buyer/buyer_main_screen.dart';

/// Polls [onLiveRefresh] every [liveInterval] while the screen is actually on
/// screen, and once more when the app comes back to the foreground.
/// Used to keep stock counts current for buyers.
mixin LiveRefresh<T extends StatefulWidget> on State<T> {
  Timer? _liveTimer;
  AppLifecycleListener? _lifecycle;

  Duration get liveInterval => const Duration(seconds: 10);

  /// Bottom-nav tab this screen lives in (BuyerMainScreenState.tabX), or null when pushed.
  int? get liveTab => null;

  /// Reload without showing a full-screen spinner.
  Future<void> onLiveRefresh();

  bool get isLiveVisible {
    if (!mounted) return false;
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    final tab = liveTab;
    if (tab == null) return true;
    final shell = BuyerMainScreen.of(context);
    return shell == null || shell.currentIndex == tab;
  }

  @override
  void initState() {
    super.initState();
    _liveTimer = Timer.periodic(liveInterval, (_) {
      if (isLiveVisible) onLiveRefresh();
    });
    _lifecycle = AppLifecycleListener(onResume: () {
      if (isLiveVisible) onLiveRefresh();
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }
}
