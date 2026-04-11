import '../../data/models/topic_model.dart';
import '../../data/models/day_plan_model.dart';
import '../../data/models/task_model.dart';

/// Manages spaced repetition scheduling and topic strength updates.
class RevisionScheduler {
  // Ebbinghaus intervals (in plan-days after learning)
  static const List<int> _intervals = [1, 3, 7, 14];

  /// Schedule revision tasks for a topic learned on [learnDay].
  /// Populates [revisionQueue] {dayNumber -> list of topicIds}.
  static void scheduleRevisions({
    required TopicModel topic,
    required int learnDay,
    required int totalDays,
    required Map<int, List<String>> revisionQueue,
  }) {
    topic.scheduledRevisions.clear();
    for (final offset in _intervals) {
      final targetDay = learnDay + offset;
      if (targetDay <= totalDays) {
        topic.scheduledRevisions.add(targetDay);
        revisionQueue.putIfAbsent(targetDay, () => []).add(topic.id);
      }
    }
  }

  /// Called when a recall task is answered (positive or negative).
  static void updateStrength({
    required TopicModel topic,
    required bool correct,
    required int currentDay,
    required int totalDays,
    required Map<int, List<String>> revisionQueue,
  }) {
    if (correct) {
      topic.strengthScore = (topic.strengthScore + 0.20).clamp(0.0, 1.0);
      topic.incorrectAnswers = 0;
      topic.revisionCount++;
      topic.lastRevisedAt = DateTime.now();
    } else {
      topic.strengthScore = (topic.strengthScore - 0.15).clamp(0.0, 1.0);
      topic.incorrectAnswers++;

      // Insert emergency re-revision if still weak
      if (topic.strengthScore < 0.4) {
        final emergencyDay = (currentDay + 2).clamp(1, totalDays);
        if (!topic.scheduledRevisions.contains(emergencyDay)) {
          topic.scheduledRevisions.add(emergencyDay);
          revisionQueue.putIfAbsent(emergencyDay, () => []).add(topic.id);
        }
      }
    }
  }

  /// Apply passive strength decay.
  /// Called when a new day begins (Ebbinghaus forgetting curve).
  static void applyDecay({
    required TopicModel topic,
    required int daysSinceLastRevision,
  }) {
    // Exponential decay model: strength × e^(-0.05 × days)
    final decay = 0.05 * daysSinceLastRevision;
    topic.strengthScore = (topic.strengthScore - decay).clamp(0.0, 1.0);
  }

  /// Build a RecallPrompt for a topic.
  /// Rotates between question / flashcard / miniQuiz based on revision count.
  static RecallPrompt buildRecallPrompt(TopicModel topic) {
    final count = topic.revisionCount;
    final modulus = count % 3;

    if (modulus == 0) {
      return _buildQuestion(topic);
    } else if (modulus == 1) {
      return _buildFlashcard(topic);
    } else {
      return _buildMiniQuiz(topic);
    }
  }

  static RecallPrompt _buildQuestion(TopicModel topic) {
    return RecallPrompt(
      type: PromptType.question,
      prompt: _questionFor(topic.name),
      answer: null,
    );
  }

  static RecallPrompt _buildFlashcard(TopicModel topic) {
    return RecallPrompt(
      type: PromptType.flashcard,
      prompt: 'Recall everything you know about: **${topic.name}**',
      answer: _summaryFor(topic.name),
    );
  }

  static RecallPrompt _buildMiniQuiz(TopicModel topic) {
    final quiz = _quizFor(topic.name);
    return RecallPrompt(
      type: PromptType.miniQuiz,
      prompt: quiz['question'] as String,
      options: (quiz['options'] as List).cast<String>(),
      answer: quiz['answer'] as String,
    );
  }

  // ── Prompt Content Generation ─────────────────────────────────────────
  static String _questionFor(String topicName) {
    final templates = [
      'Explain the concept of "$topicName" in your own words.',
      'What are the key properties of "$topicName"?',
      'Give a practical use case for "$topicName".',
      'What problem does "$topicName" solve?',
      'How would you teach "$topicName" to a beginner?',
    ];
    final idx = topicName.length % templates.length;
    return templates[idx];
  }

  static String _summaryFor(String topicName) {
    return 'Think about: definition, how it works, when to use it, and any common pitfalls of $topicName.';
  }

  static Map<String, dynamic> _quizFor(String topicName) {
    // Generic quiz templates based on topic name hash for diversity
    final seed = topicName.codeUnits.fold(0, (a, b) => a + b) % 4;
    final quizzes = [
      {
        'question': 'Which statement best describes "$topicName"?',
        'options': [
          'It is used for input validation only',
          'It is a core concept that enables structured behavior',
          'It replaces the need for other components',
          'It is deprecated in modern usage',
        ],
        'answer': 'It is a core concept that enables structured behavior',
      },
      {
        'question': 'When should you use "$topicName"?',
        'options': [
          'Only in production environments',
          'When you need to organize and manage related operations',
          'As a last resort when nothing else works',
          'Only for debugging purposes',
        ],
        'answer': 'When you need to organize and manage related operations',
      },
      {
        'question': 'What does mastering "$topicName" give you?',
        'options': [
          'Faster compilation times',
          'Ability to write more maintainable and efficient code',
          'Automatic memory management',
          'No need for testing',
        ],
        'answer': 'Ability to write more maintainable and efficient code',
      },
      {
        'question': 'A common pitfall with "$topicName" is:',
        'options': [
          'Using it only once per project',
          'Overusing it without understanding the trade-offs',
          'It cannot be combined with other concepts',
          'It must always be used with a framework',
        ],
        'answer': 'Overusing it without understanding the trade-offs',
      },
    ];
    return quizzes[seed];
  }
}
