import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class KeyConceptsDialog extends StatefulWidget {
  final String topicName;

  const KeyConceptsDialog({super.key, required this.topicName});

  @override
  State<KeyConceptsDialog> createState() => _KeyConceptsDialogState();
}

class _KeyConceptsDialogState extends State<KeyConceptsDialog> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _concepts = [];

  void _addConcept() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !_concepts.contains(text)) {
      setState(() {
        _concepts.add(text);
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.backgroundCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.psychology_rounded, 
                      color: AppColors.accentGreen, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Quick Reflection',
                    style: AppTextStyles.headlineMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'What are the 2-3 most important concepts you just learned in "${widget.topicName}"?',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              style: AppTextStyles.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Enter a concept...',
                hintStyle: AppTextStyles.bodyLarge.copyWith(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.backgroundDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.accentGreen),
                  onPressed: _addConcept,
                ),
              ),
              onSubmitted: (_) => _addConcept(),
            ),
            if (_concepts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _concepts.map((c) => Chip(
                  label: Text(c, style: AppTextStyles.labelSmall),
                  backgroundColor: AppColors.backgroundDark,
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => setState(() => _concepts.remove(c)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                )).toList(),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Skip', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _concepts),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save My Topics'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
