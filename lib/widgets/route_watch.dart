import 'package:flutter/widgets.dart';

/// Lets a screen know when the user comes back to it from a page opened on top (RouteAware.didPopNext),
/// e.g. Home picks new category tiles then. Registered in MaterialApp.navigatorObservers (main.dart).
final appRouteObserver = RouteObserver<ModalRoute<void>>();
