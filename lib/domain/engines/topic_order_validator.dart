/// Topic Order Validator — ensures topics within each phase follow prerequisite logic.
/// Fixes the most common AI mistake: putting advanced concepts before foundational ones.
class TopicOrderValidator {
  /// Prerequisite keyword chains: if a later topic contains a key from the map,
  /// and an earlier topic contains the prerequisite, they are already in order.
  /// If reversed, we reorder them.
  static const Map<String, List<String>> _prerequisites = {
    // General programming
    'async': ['function', 'callback', 'promise', 'event'],
    'await': ['async', 'promise'],
    'closure': ['function', 'scope'],
    'prototype': ['object', 'class'],
    'inheritance': ['class', 'object', 'prototype'],
    'polymorphism': ['inheritance', 'class'],
    'interface': ['class', 'abstract'],
    'generics': ['type', 'class'],
    'lambda': ['function', 'functional'],
    'stream': ['async', 'observable', 'iterator'],
    'decorator': ['class', 'function', 'pattern'],
    'dependency injection': ['class', 'interface', 'design pattern'],

    // Data structures
    'tree': ['array', 'list', 'node', 'pointer'],
    'graph': ['tree', 'node', 'edge'],
    'heap': ['tree', 'array'],
    'hash': ['array', 'function'],
    'trie': ['tree', 'string'],
    'dynamic programming': ['recursion', 'array'],
    'backtracking': ['recursion'],
    'binary search': ['array', 'sorted'],
    'merge sort': ['array', 'recursion'],
    'quick sort': ['array', 'recursion'],

    // Web/Frontend
    'react hooks': ['react', 'component', 'state'],
    'redux': ['react', 'state management'],
    'context api': ['react', 'component'],
    'next.js': ['react', 'node'],
    'graphql': ['rest', 'api'],

    // Python
    'decorators': ['function', 'closure'],
    'generators': ['function', 'iterator'],
    'metaclass': ['class', 'object'],
    'asyncio': ['async', 'function'],

    // Java/Kotlin
    'lambda expression': ['interface', 'functional interface'],
    'stream api': ['collection', 'lambda'],
    'spring': ['java', 'dependency injection'],
  };

  /// Validates and reorders topics within each module/phase.
  /// Groups topics by moduleName, then reorders within each group.
  static List<Map<String, dynamic>> validate(List<Map<String, dynamic>> topics) {
    if (topics.length <= 1) return topics;

    // Group by moduleName (phase)
    final modules = <String, List<Map<String, dynamic>>>{};
    final moduleOrder = <String>[];

    for (final topic in topics) {
      final module = topic['module'] as String? ?? 'default';
      if (!modules.containsKey(module)) {
        modules[module] = [];
        moduleOrder.add(module);
      }
      modules[module]!.add(topic);
    }

    // Sort within each module
    final result = <Map<String, dynamic>>[];
    for (final module in moduleOrder) {
      final moduleTopics = modules[module]!;
      result.addAll(_sortTopics(moduleTopics));
    }

    return result;
  }

  static List<Map<String, dynamic>> _sortTopics(List<Map<String, dynamic>> topics) {
    if (topics.length <= 1) return topics;

    // Build a score for each topic — topics with prerequisites should come AFTER their deps
    final scored = topics.asMap().entries.map((entry) {
      final idx = entry.key;
      final topic = entry.value;
      final name = (topic['concept'] as String? ?? topic['name'] as String? ?? '').toLowerCase();

      int prereqViolations = 0;
      for (final entry in _prerequisites.entries) {
        if (name.contains(entry.key)) {
          // This topic HAS a prerequisite — it should come AFTER topics with those keywords
          for (final prereqKeyword in entry.value) {
            // Check if any earlier topic covers the prerequisite
            final hasPrereqEarlier = topics
                .take(idx)
                .any((t) => (t['concept'] as String? ?? t['name'] as String? ?? '')
                    .toLowerCase()
                    .contains(prereqKeyword));
            if (!hasPrereqEarlier) {
              // Prerequisite not covered yet — this is a violation
              prereqViolations++;
            }
          }
        }
      }

      return (topic: topic, score: idx + prereqViolations * 10, originalIdx: idx);
    }).toList();

    // Sort by score (lower = earlier)
    scored.sort((a, b) => a.score.compareTo(b.score));

    // If re-ordered significantly, renumber sortOrder
    final result = scored.map((s) => Map<String, dynamic>.from(s.topic)).toList();
    for (int i = 0; i < result.length; i++) {
      result[i]['sortOrder'] = i;
    }

    return result;
  }
}
