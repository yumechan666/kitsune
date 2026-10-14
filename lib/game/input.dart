import 'package:flutter/services.dart';

class InputState {
  final Map<String, bool> held = {
    "left": false,
    "right": false,
    "jump": false,
    "fire": false,
    "dash": false,
    "ofuda": false,
    "spirit": false,
  };
  final Set<String> pressed = {};
  final Set<String> released = {};

  static final Map<LogicalKeyboardKey, String> keyMap = {
    LogicalKeyboardKey.keyA: "left",
    LogicalKeyboardKey.arrowLeft: "left",
    LogicalKeyboardKey.keyD: "right",
    LogicalKeyboardKey.arrowRight: "right",
    LogicalKeyboardKey.space: "jump",
    LogicalKeyboardKey.keyJ: "fire",
    LogicalKeyboardKey.keyK: "dash",
    LogicalKeyboardKey.keyL: "ofuda",
    LogicalKeyboardKey.keyI: "spirit",
  };

  void set(String action, bool value) {
    if (value && !held[action]!) pressed.add(action);
    if (!value && held[action]!) released.add(action);
    held[action] = value;
  }

  // Key-up and pointer-up events are lost when focus leaves the window, which
  // would leave a direction held and the character walking on its own.
  void releaseAll() {
    for (final action in held.keys.toList()) {
      set(action, false);
    }
  }

  bool consume(String action) {
    if (!pressed.contains(action)) return false;
    pressed.remove(action);
    return true;
  }

  bool consumeRelease(String action) {
    if (!released.contains(action)) return false;
    released.remove(action);
    return true;
  }

  void resetEdges() {
    pressed.clear();
    released.clear();
  }

  void onKeyEvent(KeyEvent event) {
    final action = keyMap[event.logicalKey];
    if (action == null) return;
    set(action, event is KeyDownEvent);
  }
}
