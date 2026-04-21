import 'package:uuid/uuid.dart';
import '../../data/models/topic_model.dart';

/// Generates an ordered list of topics for a given goal + level.
/// Topics are organized into 3 difficulty tiers.
class TopicGenerator {
  static const _uuid = Uuid();

  static List<TopicModel> generate({
    required String goalId,
    required String goalName,
    required String level, // beginner | intermediate | advanced
    required int totalDays,
  }) {
    final raw = _getTopicTree(goalName, level);
    return raw.asMap().entries.map((entry) {
      final idx = entry.key;
      final data = entry.value;
      return TopicModel(
        id: _uuid.v4(),
        goalId: goalId,
        name: data['name'] as String,
        tier: data['tier'] as int,
        estimatedLearnMinutes: data['minutes'] as int,
        sortOrder: idx,
      );
    }).toList();
  }

  static List<TopicModel> generateFromMetadata({
    required String goalId,
    required List<Map<String, dynamic>> metadata,
    required int totalDays,
  }) {
    // 0. Sort metadata chronologically if possible
    final sortedMetadata = List<Map<String, dynamic>>.from(metadata);
    sortMetadata(sortedMetadata);

    final List<TopicModel> result = [];
    
    // 1. Calculate TOTAL duration of the entire playlist
    final int totalDurationSec = sortedMetadata.fold(0, (sum, item) => sum + (item['duration_sec'] as int));
    final int totalMinutes = (totalDurationSec / 60).ceil();
    
    // 2. Determine target session length (Global Average)
    // We aim for exactly one segment per day per video group where possible
    final int averageMinutesPerDay = (totalMinutes / totalDays).ceil();
    
    // 3. Set dynamic threshold: we don't want session segments to be 
    // too short (<15m) or too long (>120m for focus)
    final int dynamicMaxMinutes = averageMinutesPerDay.clamp(15, 120);

    for (int i = 0; i < sortedMetadata.length; i++) {
      final item = sortedMetadata[i];
      final String fullTitle = item['title'] as String;
      final int videoDurationSec = item['duration_sec'] as int;
      final int videoMinutes = (videoDurationSec / 60).ceil();
      final List<String> subTopics = (item['subtopics'] as List<dynamic>?)?.map((s) => s.toString()).toList() ?? [];
      final String? videoId = item['video_id'] as String?;
      final String? thumbUrl = item['thumbnail_url'] as String?;
      final String? chapter = item['chapter'] as String?;
      final bool isBoss = item['is_boss'] as bool? ?? false;
      final String? rank = item['rank'] as String?;

      if (videoMinutes <= dynamicMaxMinutes) {
        // Normal topic
        int tier = _mapRankToTier(rank);
        if (rank == null) {
          final progress = i / metadata.length;
          if (progress > 0.3) tier = 2;
          if (progress > 0.7) tier = 3;
        }

        result.add(TopicModel(
          id: _uuid.v4(),
          goalId: goalId,
          name: fullTitle,
          tier: tier,
          estimatedLearnMinutes: videoMinutes.clamp(10, 120),
          videoId: videoId,
          thumbnailUrl: thumbUrl,
          startSeconds: 0,
          subTopics: subTopics,
          moduleName: chapter,
          isBoss: isBoss,
          sortOrder: i,
        ));
      } else {
        // LONG VIDEO: Split proportionally based on global average
        final int numParts = (videoMinutes / dynamicMaxMinutes).ceil();
        final int minutesPerPart = (videoMinutes / numParts).floor();

        for (int p = 1; p <= numParts; p++) {
          int tier = _mapRankToTier(rank);
          if (rank == null) {
            final progress = (i + (p / numParts)) / metadata.length;
            if (progress > 0.3) tier = 2;
            if (progress > 0.7) tier = 3;
          }

          result.add(TopicModel(
            id: _uuid.v4(),
            goalId: goalId,
            name: '$fullTitle (Part $p/$numParts)',
            tier: tier,
            estimatedLearnMinutes: minutesPerPart.clamp(10, 120),
            videoId: videoId,
            thumbnailUrl: thumbUrl,
            startSeconds: (p - 1) * minutesPerPart * 60,
            subTopics: p == 1 ? subTopics : [], // Only add subtopics to first part
            moduleName: chapter != null ? '$chapter (Part $p)' : null,
            isBoss: p == numParts ? isBoss : false, // Only last part is the boss
            sortOrder: i * 100 + p, // Spread out indices to allow parts within a group
          ));
        }
      }
    }
    return result;
  }

  /// Sorts metadata based on Phase numbering (e.g. "PHASE 1", "Phase 2") 
  /// or leading numbers in titles.
  static void sortMetadata(List<Map<String, dynamic>> metadata) {
    metadata.sort((a, b) {
      final aPhase = _extractSequenceIndex(a['chapter'] as String? ?? a['title'] as String? ?? '');
      final bPhase = _extractSequenceIndex(b['chapter'] as String? ?? b['title'] as String? ?? '');
      
      if (aPhase != null && bPhase != null) {
        return aPhase.compareTo(bPhase);
      }
      return 0; // Maintain original order if no Phase info found
    });
  }

  static int? _extractSequenceIndex(String text) {
    // 1. Look for "PHASE X" or "PART X"
    final phaseRegex = RegExp(r'(?:PHASE|PART|PH)\s*(\d+)', caseSensitive: false);
    final match = phaseRegex.firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }

    // 2. Look for leading numbers "1. Introduction" or "01 - Basics"
    final leadingNumRegex = RegExp(r'^\s*(\d+)[\.\-\s]');
    final leadingMatch = leadingNumRegex.firstMatch(text);
    if (leadingMatch != null) {
      return int.tryParse(leadingMatch.group(1) ?? '');
    }

    return null;
  }

  static int _mapRankToTier(String? rank) {
    switch (rank?.toUpperCase()) {
      case 'S': return 3;
      case 'A': return 3;
      case 'B': return 2;
      case 'C': return 1;
      default: return 1;
    }
  }

  static List<Map<String, dynamic>> _getTopicTree(String goal, String level) {
    final key = _normalize(goal);
    final tree = _topicDatabase[key] ?? _topicDatabase['default']!;
    return tree[level] ?? tree['beginner']!;
  }

  static String _normalize(String input) {
    final lower = input.toLowerCase().trim();
    for (final key in _topicDatabase.keys) {
      if (lower.contains(key) || key.contains(lower)) return key;
    }
    return 'default';
  }

  // ── Topic Database ──────────────────────────────────────────────────
  static final Map<String, Map<String, List<Map<String, dynamic>>>> _topicDatabase = {
    'java': {
      'beginner': [
        {'name': 'Java Setup & Hello World', 'tier': 1, 'minutes': 15},
        {'name': 'Variables & Data Types', 'tier': 1, 'minutes': 20},
        {'name': 'Operators & Expressions', 'tier': 1, 'minutes': 20},
        {'name': 'Control Flow: if / else', 'tier': 1, 'minutes': 20},
        {'name': 'Loops: for, while, do-while', 'tier': 1, 'minutes': 25},
        {'name': 'Arrays & Basic Collections', 'tier': 2, 'minutes': 25},
        {'name': 'Methods & Parameters', 'tier': 2, 'minutes': 20},
        {'name': 'String Manipulation', 'tier': 2, 'minutes': 20},
        {'name': 'OOP: Classes & Objects', 'tier': 2, 'minutes': 30},
        {'name': 'OOP: Constructors', 'tier': 2, 'minutes': 20},
        {'name': 'OOP: Inheritance', 'tier': 2, 'minutes': 25},
        {'name': 'OOP: Interfaces & Abstraction', 'tier': 3, 'minutes': 25},
        {'name': 'Exception Handling', 'tier': 3, 'minutes': 20},
        {'name': 'Collections Framework', 'tier': 3, 'minutes': 30},
        {'name': 'File I/O Basics', 'tier': 3, 'minutes': 25},
      ],
      'intermediate': [
        {'name': 'Generics', 'tier': 1, 'minutes': 25},
        {'name': 'Functional Interfaces & Lambdas', 'tier': 1, 'minutes': 30},
        {'name': 'Streams API', 'tier': 1, 'minutes': 30},
        {'name': 'Optional Class', 'tier': 2, 'minutes': 20},
        {'name': 'Concurrency Basics', 'tier': 2, 'minutes': 30},
        {'name': 'Executors & Thread Pools', 'tier': 2, 'minutes': 30},
        {'name': 'Design Patterns: Singleton, Factory', 'tier': 2, 'minutes': 30},
        {'name': 'JVM Internals & Memory Model', 'tier': 3, 'minutes': 35},
        {'name': 'Reflection API', 'tier': 3, 'minutes': 30},
        {'name': 'Unit Testing with JUnit', 'tier': 3, 'minutes': 25},
      ],
      'advanced': [
        {'name': 'Virtual Threads (Project Loom)', 'tier': 1, 'minutes': 35},
        {'name': 'CompletableFuture & Async Patterns', 'tier': 1, 'minutes': 35},
        {'name': 'Reactive Programming Basics', 'tier': 2, 'minutes': 40},
        {'name': 'GC Tuning & Profiling', 'tier': 2, 'minutes': 40},
        {'name': 'Custom Annotations & APT', 'tier': 2, 'minutes': 35},
        {'name': 'Bytecode & Instrumentation', 'tier': 3, 'minutes': 45},
        {'name': 'Performance Optimization Patterns', 'tier': 3, 'minutes': 40},
      ],
    },

    'python': {
      'beginner': [
        {'name': 'Python Setup & REPL', 'tier': 1, 'minutes': 10},
        {'name': 'Variables, Types & Print', 'tier': 1, 'minutes': 15},
        {'name': 'Strings & String Methods', 'tier': 1, 'minutes': 20},
        {'name': 'Lists & Tuples', 'tier': 1, 'minutes': 20},
        {'name': 'Dictionaries & Sets', 'tier': 1, 'minutes': 20},
        {'name': 'Control Flow: if/elif/else', 'tier': 1, 'minutes': 15},
        {'name': 'Loops: for, while', 'tier': 1, 'minutes': 20},
        {'name': 'Functions & Return Values', 'tier': 2, 'minutes': 20},
        {'name': 'List Comprehensions', 'tier': 2, 'minutes': 20},
        {'name': 'File I/O', 'tier': 2, 'minutes': 20},
        {'name': 'Error Handling', 'tier': 2, 'minutes': 20},
        {'name': 'Modules & Imports', 'tier': 2, 'minutes': 15},
        {'name': 'OOP Basics', 'tier': 3, 'minutes': 30},
        {'name': 'OOP Inheritance', 'tier': 3, 'minutes': 25},
        {'name': 'pip & Virtual Environments', 'tier': 3, 'minutes': 15},
      ],
      'intermediate': [
        {'name': 'Decorators', 'tier': 1, 'minutes': 30},
        {'name': 'Generators & Iterators', 'tier': 1, 'minutes': 30},
        {'name': 'Context Managers', 'tier': 2, 'minutes': 25},
        {'name': 'asyncio Basics', 'tier': 2, 'minutes': 35},
        {'name': 'Type Hints & mypy', 'tier': 2, 'minutes': 25},
        {'name': 'Dataclasses', 'tier': 3, 'minutes': 25},
        {'name': 'Testing with pytest', 'tier': 3, 'minutes': 30},
        {'name': 'Packaging & Distribution', 'tier': 3, 'minutes': 25},
      ],
      'advanced': [
        {'name': 'Metaclasses', 'tier': 1, 'minutes': 40},
        {'name': 'C Extensions & Ctypes', 'tier': 2, 'minutes': 45},
        {'name': 'Concurrency: GIL deep dive', 'tier': 2, 'minutes': 40},
        {'name': 'CPython Internals', 'tier': 3, 'minutes': 50},
      ],
    },

    'javascript': {
      'beginner': [
        {'name': 'JS Fundamentals & Console', 'tier': 1, 'minutes': 15},
        {'name': 'Variables: let, const, var', 'tier': 1, 'minutes': 15},
        {'name': 'Data Types & Type Coercion', 'tier': 1, 'minutes': 20},
        {'name': 'Functions & Arrow Functions', 'tier': 1, 'minutes': 20},
        {'name': 'Arrays & Array Methods', 'tier': 1, 'minutes': 25},
        {'name': 'Objects & Destructuring', 'tier': 2, 'minutes': 25},
        {'name': 'DOM Manipulation', 'tier': 2, 'minutes': 30},
        {'name': 'Events & Event Listeners', 'tier': 2, 'minutes': 25},
        {'name': 'Promises & async/await', 'tier': 3, 'minutes': 30},
        {'name': 'Fetch API & REST', 'tier': 3, 'minutes': 25},
        {'name': 'ES6+ Features', 'tier': 3, 'minutes': 25},
        {'name': 'Error Handling', 'tier': 3, 'minutes': 20},
      ],
      'intermediate': [
        {'name': 'Closures & Scope', 'tier': 1, 'minutes': 30},
        {'name': 'Prototypes & Prototype Chain', 'tier': 1, 'minutes': 30},
        {'name': 'this Keyword', 'tier': 2, 'minutes': 25},
        {'name': 'Modules (ESM & CJS)', 'tier': 2, 'minutes': 25},
        {'name': 'Event Loop & Micro/Macro Tasks', 'tier': 2, 'minutes': 35},
        {'name': 'Design Patterns in JS', 'tier': 3, 'minutes': 35},
        {'name': 'Testing with Jest', 'tier': 3, 'minutes': 30},
      ],
      'advanced': [
        {'name': 'Service Workers & PWA', 'tier': 1, 'minutes': 40},
        {'name': 'Web Workers', 'tier': 2, 'minutes': 35},
        {'name': 'V8 Engine & Optimization', 'tier': 2, 'minutes': 45},
        {'name': 'WebAssembly Integration', 'tier': 3, 'minutes': 50},
      ],
    },

    'react': {
      'beginner': [
        {'name': 'React Setup & JSX', 'tier': 1, 'minutes': 20},
        {'name': 'Components & Props', 'tier': 1, 'minutes': 25},
        {'name': 'useState Hook', 'tier': 1, 'minutes': 25},
        {'name': 'useEffect Hook', 'tier': 2, 'minutes': 30},
        {'name': 'Event Handling in React', 'tier': 2, 'minutes': 20},
        {'name': 'Lists, Keys & Conditional Rendering', 'tier': 2, 'minutes': 25},
        {'name': 'Forms & Controlled Inputs', 'tier': 2, 'minutes': 25},
        {'name': 'React Router Basics', 'tier': 3, 'minutes': 30},
        {'name': 'Fetching Data from APIs', 'tier': 3, 'minutes': 30},
        {'name': 'Component Lifecycle Understanding', 'tier': 3, 'minutes': 25},
      ],
      'intermediate': [
        {'name': 'Context API & useContext', 'tier': 1, 'minutes': 30},
        {'name': 'useReducer & Complex State', 'tier': 1, 'minutes': 30},
        {'name': 'Custom Hooks', 'tier': 2, 'minutes': 30},
        {'name': 'Performance: useMemo, useCallback', 'tier': 2, 'minutes': 30},
        {'name': 'Code Splitting & Lazy Loading', 'tier': 3, 'minutes': 30},
        {'name': 'Testing with React Testing Library', 'tier': 3, 'minutes': 35},
      ],
      'advanced': [
        {'name': 'React Server Components', 'tier': 1, 'minutes': 45},
        {'name': 'Concurrent Features', 'tier': 2, 'minutes': 45},
        {'name': 'Advanced Patterns (Compound, HOC)', 'tier': 3, 'minutes': 40},
      ],
    },

    'sql': {
      'beginner': [
        {'name': 'DB Concepts & SQL Overview', 'tier': 1, 'minutes': 15},
        {'name': 'SELECT, FROM, WHERE', 'tier': 1, 'minutes': 20},
        {'name': 'INSERT, UPDATE, DELETE', 'tier': 1, 'minutes': 20},
        {'name': 'ORDER BY & LIMIT', 'tier': 1, 'minutes': 15},
        {'name': 'Aggregate Functions', 'tier': 2, 'minutes': 20},
        {'name': 'GROUP BY & HAVING', 'tier': 2, 'minutes': 20},
        {'name': 'JOINs: INNER, LEFT, RIGHT', 'tier': 2, 'minutes': 25},
        {'name': 'Subqueries', 'tier': 3, 'minutes': 25},
        {'name': 'Indexes & Performance', 'tier': 3, 'minutes': 25},
        {'name': 'Transactions & ACID', 'tier': 3, 'minutes': 25},
      ],
      'intermediate': [
        {'name': 'Window Functions', 'tier': 1, 'minutes': 35},
        {'name': 'CTEs (Common Table Expressions)', 'tier': 1, 'minutes': 30},
        {'name': 'Stored Procedures', 'tier': 2, 'minutes': 30},
        {'name': 'Triggers', 'tier': 2, 'minutes': 30},
        {'name': 'Query Optimization & EXPLAIN', 'tier': 3, 'minutes': 35},
      ],
      'advanced': [
        {'name': 'Partitioning Strategies', 'tier': 1, 'minutes': 40},
        {'name': 'Replication & Sharding Concepts', 'tier': 2, 'minutes': 45},
        {'name': 'Query Planner Internals', 'tier': 3, 'minutes': 50},
      ],
    },

    'dsa': {
      'beginner': [
        {'name': 'Big-O Notation & Complexity', 'tier': 1, 'minutes': 25},
        {'name': 'Arrays & Time Complexity', 'tier': 1, 'minutes': 25},
        {'name': 'Linked Lists', 'tier': 1, 'minutes': 30},
        {'name': 'Stacks & Queues', 'tier': 1, 'minutes': 25},
        {'name': 'Hash Maps & Hash Sets', 'tier': 2, 'minutes': 30},
        {'name': 'Binary Search', 'tier': 2, 'minutes': 25},
        {'name': 'Sorting Algorithms', 'tier': 2, 'minutes': 30},
        {'name': 'Trees & Binary Trees', 'tier': 2, 'minutes': 30},
        {'name': 'BST Operations', 'tier': 3, 'minutes': 30},
        {'name': 'Recursion & Backtracking', 'tier': 3, 'minutes': 35},
        {'name': 'Graph Basics: BFS & DFS', 'tier': 3, 'minutes': 35},
      ],
      'intermediate': [
        {'name': 'Dynamic Programming Intro', 'tier': 1, 'minutes': 40},
        {'name': 'DP: Memoization vs Tabulation', 'tier': 1, 'minutes': 35},
        {'name': 'Heaps & Priority Queues', 'tier': 2, 'minutes': 30},
        {'name': 'Tries', 'tier': 2, 'minutes': 30},
        {'name': 'Graph: Dijkstra & Bellman-Ford', 'tier': 3, 'minutes': 40},
        {'name': 'Union-Find / Disjoint Sets', 'tier': 3, 'minutes': 35},
      ],
      'advanced': [
        {'name': 'Segment Trees & Fenwick Trees', 'tier': 1, 'minutes': 50},
        {'name': 'Advanced DP Patterns', 'tier': 2, 'minutes': 50},
        {'name': 'Network Flow Algorithms', 'tier': 3, 'minutes': 55},
      ],
    },

    'flutter': {
      'beginner': [
        {'name': 'Flutter Setup & First App', 'tier': 1, 'minutes': 20},
        {'name': 'Widgets: Stateless vs Stateful', 'tier': 1, 'minutes': 25},
        {'name': 'Basic Widgets: Text, Row, Column', 'tier': 1, 'minutes': 20},
        {'name': 'Layout: Container, Padding, SizedBox', 'tier': 1, 'minutes': 25},
        {'name': 'Hot Reload & Hot Restart', 'tier': 1, 'minutes': 10},
        {'name': 'setState & Local State', 'tier': 2, 'minutes': 25},
        {'name': 'Navigator & Routes', 'tier': 2, 'minutes': 25},
        {'name': 'ListView & GridView', 'tier': 2, 'minutes': 25},
        {'name': 'Forms & Input Validation', 'tier': 2, 'minutes': 25},
        {'name': 'Networking with http', 'tier': 3, 'minutes': 30},
        {'name': 'Local Storage: SharedPreferences', 'tier': 3, 'minutes': 25},
        {'name': 'Basic Animations', 'tier': 3, 'minutes': 30},
      ],
      'intermediate': [
        {'name': 'Riverpod State Management', 'tier': 1, 'minutes': 35},
        {'name': 'go_router Navigation', 'tier': 1, 'minutes': 30},
        {'name': 'Hive Local Database', 'tier': 2, 'minutes': 30},
        {'name': 'Custom Painters', 'tier': 2, 'minutes': 40},
        {'name': 'Platform Channels', 'tier': 3, 'minutes': 40},
        {'name': 'Isolates & Compute', 'tier': 3, 'minutes': 35},
      ],
      'advanced': [
        {'name': 'Flutter Web Optimization', 'tier': 1, 'minutes': 45},
        {'name': 'Frame Rendering & Jank Analysis', 'tier': 2, 'minutes': 50},
        {'name': 'Custom RenderObjects', 'tier': 3, 'minutes': 55},
      ],
    },

    'machine learning': {
      'beginner': [
        {'name': 'ML Concepts & Terminology', 'tier': 1, 'minutes': 20},
        {'name': 'Data Preprocessing', 'tier': 1, 'minutes': 25},
        {'name': 'Linear Regression', 'tier': 1, 'minutes': 30},
        {'name': 'Logistic Regression', 'tier': 1, 'minutes': 30},
        {'name': 'Train/Test Split & Metrics', 'tier': 2, 'minutes': 25},
        {'name': 'Decision Trees', 'tier': 2, 'minutes': 30},
        {'name': 'Random Forests', 'tier': 2, 'minutes': 30},
        {'name': 'k-Nearest Neighbors', 'tier': 2, 'minutes': 25},
        {'name': 'Feature Engineering', 'tier': 3, 'minutes': 35},
        {'name': 'Cross Validation', 'tier': 3, 'minutes': 25},
        {'name': 'scikit-learn Pipelines', 'tier': 3, 'minutes': 30},
      ],
      'intermediate': [
        {'name': 'SVM & Kernel Trick', 'tier': 1, 'minutes': 35},
        {'name': 'Gradient Boosting (XGBoost)', 'tier': 1, 'minutes': 35},
        {'name': 'Neural Networks Intro', 'tier': 2, 'minutes': 40},
        {'name': 'Backpropagation', 'tier': 2, 'minutes': 40},
        {'name': 'CNNs', 'tier': 3, 'minutes': 45},
        {'name': 'RNNs & LSTMs', 'tier': 3, 'minutes': 45},
      ],
      'advanced': [
        {'name': 'Transformers Architecture', 'tier': 1, 'minutes': 55},
        {'name': 'Fine-tuning LLMs', 'tier': 2, 'minutes': 60},
        {'name': 'MLOps & Model Deployment', 'tier': 3, 'minutes': 50},
      ],
    },

    'default': {
      'beginner': [
        {'name': 'Introduction & Overview', 'tier': 1, 'minutes': 20},
        {'name': 'Core Concepts Part 1', 'tier': 1, 'minutes': 25},
        {'name': 'Core Concepts Part 2', 'tier': 1, 'minutes': 25},
        {'name': 'Fundamentals: Part A', 'tier': 1, 'minutes': 20},
        {'name': 'Fundamentals: Part B', 'tier': 1, 'minutes': 20},
        {'name': 'Intermediate Topics Part 1', 'tier': 2, 'minutes': 30},
        {'name': 'Intermediate Topics Part 2', 'tier': 2, 'minutes': 30},
        {'name': 'Practical Application', 'tier': 2, 'minutes': 30},
        {'name': 'Advanced Concepts', 'tier': 3, 'minutes': 35},
        {'name': 'Real-World Usage', 'tier': 3, 'minutes': 35},
        {'name': 'Best Practices', 'tier': 3, 'minutes': 30},
        {'name': 'Review & Consolidation', 'tier': 3, 'minutes': 25},
      ],
      'intermediate': [
        {'name': 'Review of Fundamentals', 'tier': 1, 'minutes': 20},
        {'name': 'Intermediate Concept A', 'tier': 1, 'minutes': 30},
        {'name': 'Intermediate Concept B', 'tier': 2, 'minutes': 30},
        {'name': 'Advanced Application', 'tier': 2, 'minutes': 35},
        {'name': 'Edge Cases & Gotchas', 'tier': 3, 'minutes': 35},
        {'name': 'Professional Patterns', 'tier': 3, 'minutes': 35},
      ],
      'advanced': [
        {'name': 'Expert Concept A', 'tier': 1, 'minutes': 45},
        {'name': 'Expert Concept B', 'tier': 2, 'minutes': 45},
        {'name': 'System-Level Understanding', 'tier': 3, 'minutes': 50},
      ],
    },
  };
}
