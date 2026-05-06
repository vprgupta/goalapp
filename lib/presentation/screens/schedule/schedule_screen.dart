import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/services/notification_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _enabled = false;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  bool _loading = true;

  static const _prefEnabled = 'study_reminder_enabled';
  static const _prefHour = 'study_reminder_hour';
  static const _prefMinute = 'study_reminder_minute';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabled = prefs.getBool(_prefEnabled) ?? false;
      final h = prefs.getInt(_prefHour) ?? 9;
      final m = prefs.getInt(_prefMinute) ?? 0;
      _selectedTime = TimeOfDay(hour: h, minute: m);
      _loading = false;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, _enabled);
    await prefs.setInt(_prefHour, _selectedTime.hour);
    await prefs.setInt(_prefMinute, _selectedTime.minute);
  }

  Future<void> _toggleReminder(bool value) async {
    if (value) {
      // Request permission first
      final granted =
          await NotificationService.instance.requestPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Notification permission denied. Enable it in Settings.'),
          ),
        );
        return;
      }
      await NotificationService.instance.scheduleDailyReminder(
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
      );
    } else {
      await NotificationService.instance.cancelReminder();
    }
    setState(() => _enabled = value);
    await _savePrefs();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accentAmber,
            onPrimary: Colors.black,
            surface: AppColors.backgroundCard,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _selectedTime = picked);
    if (_enabled) {
      await NotificationService.instance.scheduleDailyReminder(
        hour: picked.hour,
        minute: picked.minute,
      );
    }
    await _savePrefs();
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // ── Header ────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STUDY SCHEDULE',
                            style: AppTextStyles.tagStyle.copyWith(
                              color: AppColors.accentAmber,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Daily Reminder',
                            style: AppTextStyles.headlineLarge.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Set a daily study alarm and stay consistent.',
                            style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            height: 1,
                            color: AppColors.borderSubtle,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Toggle card ───────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: _Card(
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.accentAmber.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color:
                                        AppColors.accentAmber.withOpacity(0.3)),
                              ),
                              child: const Icon(Icons.notifications_rounded,
                                  color: AppColors.accentAmber, size: 22),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Daily Reminder',
                                    style: AppTextStyles.titleMedium.copyWith(
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _enabled
                                        ? 'Rings every day at ${_formatTime(_selectedTime)}'
                                        : 'Turn on to get a daily nudge',
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _enabled,
                              onChanged: _toggleReminder,
                              activeColor: AppColors.accentAmber,
                              trackColor: WidgetStateProperty.resolveWith((s) =>
                                  s.contains(WidgetState.selected)
                                      ? AppColors.accentAmber.withOpacity(0.3)
                                      : AppColors.borderCard),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Time picker card ──────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: GestureDetector(
                        onTap: _pickTime,
                        child: _Card(
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.accentTeal.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppColors.accentTeal
                                          .withOpacity(0.3)),
                                ),
                                child: const Icon(Icons.access_time_rounded,
                                    color: AppColors.accentTeal, size: 22),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Study Time',
                                      style: AppTextStyles.titleMedium
                                          .copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Tap to change the time',
                                      style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundElevated,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: AppColors.borderCard),
                                ),
                                child: Text(
                                  _formatTime(_selectedTime),
                                  style: AppTextStyles.titleMedium.copyWith(
                                    color: AppColors.accentAmber,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Info banner ───────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.accentAmber.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.accentAmber.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: AppColors.accentAmber, size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'The notification fires every day at your chosen time '
                                'to remind you to open the app and complete your tasks. '
                                'Make sure notifications are allowed in your device settings.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Status strip ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: _enabled
                              ? AppColors.accentGreen.withOpacity(0.08)
                              : AppColors.backgroundCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _enabled
                                ? AppColors.accentGreen.withOpacity(0.3)
                                : AppColors.borderCard,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _enabled
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: _enabled
                                  ? AppColors.accentGreen
                                  : AppColors.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _enabled
                                  ? 'Reminder is ON — ${_formatTime(_selectedTime)} every day'
                                  : 'Reminder is OFF',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: _enabled
                                    ? AppColors.accentGreen
                                    : AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Reusable card shell ──────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderCard),
      ),
      child: child,
    );
  }
}
