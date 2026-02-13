import 'package:flutter/material.dart';

/// Root navigator key used for app-level navigation events
/// (e.g. push-notification taps while app is background/terminated).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
