import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'base_llm_service.dart';

/// MCQ Verifier Agent — runs a second LLM pass to verify and fix wrong answers.
/// This prevents hallucinated correct answers from destroying user trust.
class McqVerifierService {
  final BaseLlmService _llm;

  McqVerifierService(this._llm);

  /// Verifies a list of MCQ questions and fixes any that have wrong correct_index.
  /// Returns the corrected list. Falls back to original if verification fails.
  Future<List<Map<String, dynamic>>> verifyAndFix(
    List<Map<String, dynamic>> questions, {
    required String topicConcept,
  }) async {
    if (questions.isEmpty) return questions;

    // Only verify MCQ-type questions (not open-ended theory)
    final mcqs = questions.where((q) => q['type'] != 'theory').toList();
    if (mcqs.isEmpty) return questions;

    try {
      final qDump = jsonEncode(mcqs);
      final prompt = '''
You are a Senior Software Engineer verifying MCQ accuracy. For each question below, check if the stated correct_index is actually correct.

TOPIC: $topicConcept

QUESTIONS:
$qDump

RULES:
- If correct_index is RIGHT, keep it exactly as is.
- If correct_index is WRONG, fix it to the right answer index (0-3).
- Also improve the explanation if it's vague or incorrect.
- Do NOT change the question text or options.
- Return ONLY valid JSON array. No markdown, no explanation.

Return the SAME array structure with corrections applied.
''';

      final buffer = StringBuffer();
      await for (final chunk in _llm.generateTextStream(prompt)) {
        buffer.write(chunk);
      }

      final raw = buffer.toString().trim();
      final jsonStr = _extractJson(raw);
      if (jsonStr == null) return questions;

      final verified = jsonDecode(jsonStr) as List<dynamic>;
      final verifiedList = verified.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // Merge verified MCQs back with theory questions
      final result = <Map<String, dynamic>>[];
      int mcqIdx = 0;
      for (final q in questions) {
        if (q['type'] == 'theory') {
          result.add(q);
        } else {
          result.add(mcqIdx < verifiedList.length ? verifiedList[mcqIdx++] : q);
        }
      }
      return result;
    } catch (e) {
      debugPrint('[McqVerifier] Verification failed, using originals: $e');
      return questions; // Safe fallback
    }
  }

  String? _extractJson(String raw) {
    // Try to extract a JSON array from the response
    final startIdx = raw.indexOf('[');
    final endIdx = raw.lastIndexOf(']');
    if (startIdx == -1 || endIdx == -1 || endIdx <= startIdx) return null;
    return raw.substring(startIdx, endIdx + 1);
  }
}
