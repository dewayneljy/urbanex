import 'package:flutter/foundation.dart';

/// Tracks which bottom-nav tab is "active", shared globally so any pushed
/// screen - not just the four top-level tab screens - can show the same
/// persistent bottom nav and jump straight to a different tab from
/// anywhere in the app, not only from the home shell itself.
class NavService {
  NavService._();
  static final ValueNotifier<int> currentTab = ValueNotifier<int>(0);
}



