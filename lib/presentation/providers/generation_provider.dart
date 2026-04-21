import 'package:flutter_riverpod/flutter_riverpod.dart';

class GenerationState {
  final String buffer;
  final bool isGenerating;
  final String? error;

  GenerationState({
    this.buffer = '',
    this.isGenerating = false,
    this.error,
  });

  GenerationState copyWith({
    String? buffer,
    bool? isGenerating,
    String? error,
  }) {
    return GenerationState(
      buffer: buffer ?? this.buffer,
      isGenerating: isGenerating ?? this.isGenerating,
      error: error,
    );
  }
}

class GenerationNotifier extends StateNotifier<GenerationState> {
  GenerationNotifier() : super(GenerationState());

  void start() {
    state = state.copyWith(buffer: '', isGenerating: true, error: null);
  }

  void append(String chunk) {
    state = state.copyWith(buffer: state.buffer + chunk);
  }

  void complete() {
    state = state.copyWith(isGenerating: false);
  }

  void fail(String error) {
    state = state.copyWith(isGenerating: false, error: error);
  }

  void reset() {
    state = GenerationState();
  }
}

final generationProvider = StateNotifierProvider<GenerationNotifier, GenerationState>((ref) {
  return GenerationNotifier();
});
