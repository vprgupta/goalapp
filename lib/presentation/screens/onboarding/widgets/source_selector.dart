import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Source type selector tabs (AI / YouTube / PDF).
/// Fixed: uses Material+InkWell instead of GestureDetector for proper ripple.
class SourceSelector extends StatelessWidget {
  final String selectedSource;
  final ValueChanged<String> onSourceChanged;

  const SourceSelector({
    super.key,
    required this.selectedSource,
    required this.onSourceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _SourceButton(
            type: 'ai',
            label: 'AI Syllabus',
            icon: Icons.auto_awesome_rounded,
            isSelected: selectedSource == 'ai',
            onTap: () => onSourceChanged('ai'),
          ),
          const SizedBox(width: 8),
          _SourceButton(
            type: 'youtube',
            label: 'YouTube Playlist',
            icon: Icons.video_library_rounded,
            isSelected: selectedSource == 'youtube',
            onTap: () => onSourceChanged('youtube'),
          ),
          const SizedBox(width: 8),
          _SourceButton(
            type: 'pdf',
            label: 'PDF Document',
            icon: Icons.picture_as_pdf_rounded,
            isSelected: selectedSource == 'pdf',
            onTap: () => onSourceChanged('pdf'),
          ),
        ],
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final String type;
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SourceButton({
    required this.type,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentAmber.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accentAmber : AppColors.borderCard,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        // Material+InkWell gives correct ripple within the styled Container
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            splashColor: AppColors.accentAmber.withOpacity(0.12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected
                        ? AppColors.accentAmber
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isSelected
                          ? AppColors.accentAmber
                          : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
