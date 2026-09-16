import 'package:flutter/foundation.dart';

/// Shared home-shell tab index so registration can jump to the dial pad.
class HomeNav {
  HomeNav._();

  static final ValueNotifier<int> tabIndex = ValueNotifier<int>(0);

  static void goDialer() => tabIndex.value = 0;
}
