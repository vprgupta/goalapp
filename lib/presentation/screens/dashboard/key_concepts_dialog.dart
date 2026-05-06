import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class KeyConceptsDialog extends StatefulWidget {
  final String topicName;
  final List<String> initialConcepts;
  final bool isRevision;

  const KeyConceptsDialog({
    super.key,
    required this.topicName,
    this.initialConcepts = const [],
    this.isRevision = false,
  });

  @override
  State<KeyConceptsDialog> createState() => _KeyConceptsDialogState();
}

class _KeyConceptsDialogState extends State<KeyConceptsDialog> {
  final TextEditingController _controller = TextEditingController();
  late List<String> _concepts;

  @override
  void initState() {
    super.initState();
    _concepts = List.from(widget.initialConcepts);
  }

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
    return Dialog.fullscreen(
      backgroundColor: AppColors.backgroundDark,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accentGreen.withOpacity(0.35)),
                    ),
                    child: const Icon(Icons.psychology_rounded,
                        color: AppColors.accentGreen, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.isRevision ? 'Refine Key Topics' : 'Quick Reflection',
                      style: AppTextStyles.headlineLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // ── Sub-heading ─────────────────────────────────────────────
              Text(
                widget.isRevision
                    ? 'Did you discover any new key concepts while reviewing?'
                    : 'What are the most important concepts you just learned?',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              // Topic pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accentGreen.withOpacity(0.25)),
                ),
                child: Text(
                  '"${widget.topicName}"',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.accentGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              // ── Text field ──────────────────────────────────────────────
              TextField(
                controller: _controller,
                autofocus: false,
                style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Type a concept and press +',
                  hintStyle: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: AppColors.backgroundCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.borderCard),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.accentGreen, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: GestureDetector(
                    onTap: _addConcept,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),
                onSubmitted: (_) => _addConcept(),
              ),
              const SizedBox(height: 14),
              // ── Chips list ──────────────────────────────────────────────
              Expanded(
                child: _concepts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lightbulb_outline_rounded,
                                size: 48, color: AppColors.textMuted.withOpacity(0.4)),
                            const SizedBox(height: 10),
                            Text(
                              'Add concepts above to\nbuild your recall list',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          children: _concepts.map((c) {
                            return Chip(
                              label: Text(
                                c,
                                style: AppTextStyles.labelSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              backgroundColor: AppColors.backgroundCard,
                              side: BorderSide(
                                color: AppColors.accentGreen.withOpacity(0.3),
                              ),
                              deleteIcon:
                                  const Icon(Icons.close_rounded, size: 16),
                              onDeleted: () =>
                                  setState(() => _concepts.remove(c)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 4),
                            );
                          }).toList(),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              // ── Action buttons ──────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.borderCard),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Skip',
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _concepts),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Save Concepts',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
