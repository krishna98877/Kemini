import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatWindowState {
  final String overlayMode; // "icon", "radial", or "maximized"

  ChatWindowState({this.overlayMode = "icon"});

  ChatWindowState copyWith({String? overlayMode}) {
    return ChatWindowState(
      overlayMode: overlayMode ?? this.overlayMode,
    );
  }
}

class ChatWindowNotifier extends Notifier<ChatWindowState> {
  @override
  ChatWindowState build() => ChatWindowState();

  void setMode(String mode) {
    state = state.copyWith(overlayMode: mode);
  }

  void cycleMode() {
    final newMode = switch (state.overlayMode) {
      "icon" => "radial",
      "radial" => "maximized",
      _ => "icon", // maximized or unknown returns to icon
    };
    state = state.copyWith(overlayMode: newMode);
  }
}

final chatWindowStateProvider =
    NotifierProvider<ChatWindowNotifier, ChatWindowState>(
  ChatWindowNotifier.new,
);