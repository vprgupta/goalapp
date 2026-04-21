import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/ai_service.dart';
import '../../domain/services/dynamic_learning_service.dart';

/// Provides a singleton [AiService] instance into the widget tree.
/// Using a Riverpod Provider (not instantiating inside Notifiers) ensures
/// the service can be overridden in tests via ProviderScope overrides.
final aiServiceProvider = Provider<AiService>((ref) {
  return AiService();
});

/// Provides a singleton [DynamicLearningService].
final dynamicLearningServiceProvider = Provider<DynamicLearningService>((ref) {
  return DynamicLearningService();
});
