import 'dart:ui';

class AppColors {
  AppColors._();

  // Backgrounds
  static const Color backgroundDark = Color(0xFF080C17);
  static const Color backgroundCard = Color(0xFF111827);
  static const Color backgroundElevated = Color(0xFF182032);
  static const Color backgroundSurface = Color(0xFF1E2840);

  // Accent
  static const Color accentAmber = Color(0xFFFFA726);
  static const Color accentAmberLight = Color(0xFFFFCC80);
  static const Color accentGreen = Color(0xFF4ADE80);
  static const Color accentTeal = Color(0xFF22D3EE);
  static const Color accentRed = Color(0xFFEF5350);
  static const Color accentPurple = Color(0xFFAB47BC);

  // Gradient pairs — for use inside LinearGradient(colors: [...])
  static const Color gradientAmberStart = Color(0xFFFF9500);
  static const Color gradientAmberEnd   = Color(0xFFFF5F00);
  static const Color gradientBlueStart  = Color(0xFF3A86FF);
  static const Color gradientBlueEnd    = Color(0xFF0052CC);
  static const Color gradientGreenStart = Color(0xFF4ADE80);
  static const Color gradientGreenEnd   = Color(0xFF16A34A);
  static const Color gradientPurpleStart = Color(0xFFA78BFA);
  static const Color gradientPurpleEnd   = Color(0xFF7C3AED);

  // Glow shadows — use as BoxShadow color
  static const Color glowAmber  = Color(0x33FFA726); // 20 % amber
  static const Color glowBlue   = Color(0x293A86FF); // 16 % blue
  static const Color glowGreen  = Color(0x294ADE80); // 16 % green
  static const Color glowPurple = Color(0x29A78BFA); // 16 % purple
  static const Color glowTeal   = Color(0x2922D3EE); // 16 % teal

  // Text
  static const Color textPrimary   = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF475569);
  static const Color textHint      = Color(0xFF334155);

  // Task Type Colors
  static const Color learnColor      = Color(0xFF3A86FF);
  static const Color learnColorLight = Color(0xFF93C5FD);
  static const Color reviseColor      = Color(0xFFFFA726);
  static const Color reviseColorLight = Color(0xFFFFCC80);

  // Progress
  static const Color progressTrack = Color(0xFF1A2440);
  static const Color progressFill  = Color(0xFF3A86FF);

  // Borders
  static const Color borderSubtle = Color(0xFF1A2235);
  static const Color borderCard   = Color(0xFF1E2E4A);

  // Strength levels
  static const Color strengthWeak    = Color(0xFFEF5350);
  static const Color strengthMedium  = Color(0xFFFFA726);
  static const Color strengthStrong  = Color(0xFF4ADE80);
  static const Color strengthPerfect = Color(0xFF22D3EE);
}
