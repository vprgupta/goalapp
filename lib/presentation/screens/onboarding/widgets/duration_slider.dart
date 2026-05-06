import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Duration input widget supporting both slider (7–90 days) and custom text input.
class DurationSlider extends StatefulWidget {
  final double days;
  final ValueChanged<double> onChanged;

  const DurationSlider({
    super.key,
    required this.days,
    required this.onChanged,
  });

  @override
  State<DurationSlider> createState() => _DurationSliderState();
}

class _DurationSliderState extends State<DurationSlider> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.days.round().toString());
  }

  @override
  void didUpdateWidget(covariant DurationSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days != widget.days) {
      if (_controller.text != widget.days.round().toString()) {
        _controller.text = widget.days.round().toString();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Duration (Days)', style: AppTextStyles.titleMedium),
            SizedBox(
              width: 80,
              height: 36,
              child: TextFormField(
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.accentAmber),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: AppColors.accentAmber.withOpacity(0.15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null && parsed > 0) {
                    widget.onChanged(parsed);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: AppColors.accentAmber,
            inactiveTrackColor: AppColors.progressTrack,
            thumbColor: AppColors.accentAmber,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            overlayColor: AppColors.accentAmber.withOpacity(0.15),
          ),
          child: Slider(
            value: widget.days.clamp(7.0, 365.0),
            min: 7,
            max: 365,
            divisions: 358,
            onChanged: (val) {
              _controller.text = val.round().toString();
              widget.onChanged(val);
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('7 days', style: AppTextStyles.bodySmall),
            Text('365 days', style: AppTextStyles.bodySmall),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 650.ms, duration: 400.ms);
  }
}
