import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Stage palette — tuned for visibility on a dark stage without blinding
/// the performer.
class StageColors {
  static const bg = Color(0xFF070709); // near-black backdrop
  static const surface = Color(0xFF101014); // panels
  static const surfaceRaised = Color(0xFF17171D); // cards / pads (empty)
  static const stroke = Color(0xFF26262E); // hairline borders
  static const textPrimary = Color(0xFFF2F2F5);
  static const textSecondary = Color(0xFF8B8B96);
  static const danger = Color(0xFFFF3B30);
  static const warn = Color(0xFFFFB300);
}

ThemeData buildStageTheme(Color accent) {
  final base = ThemeData.dark(useMaterial3: true);
  final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
    // Condensed display face for bank/group labels and pad names — reads
    // fast at distance, like rack gear labelling.
    displayLarge: GoogleFonts.oswald(
        fontWeight: FontWeight.w600, letterSpacing: 1.2),
    displayMedium: GoogleFonts.oswald(
        fontWeight: FontWeight.w600, letterSpacing: 1.0),
    titleLarge: GoogleFonts.oswald(
        fontWeight: FontWeight.w500, letterSpacing: 0.8),
    labelLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w600, letterSpacing: 0.6),
  );

  return base.copyWith(
    scaffoldBackgroundColor: StageColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: accent,
      secondary: accent,
      surface: StageColors.surface,
      error: StageColors.danger,
    ),
    textTheme: textTheme.apply(
      bodyColor: StageColors.textPrimary,
      displayColor: StageColors.textPrimary,
    ),
    dividerColor: StageColors.stroke,
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: accent,
      inactiveTrackColor: StageColors.stroke,
      thumbColor: Colors.white,
      overlayColor: accent.withOpacity(0.15),
      trackHeight: 3,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? accent
              : StageColors.stroke),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: StageColors.surfaceRaised,
      contentTextStyle:
          GoogleFonts.inter(color: StageColors.textPrimary, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: StageColors.stroke),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: StageColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: StageColors.stroke),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: StageColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: StageColors.bg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.oswald(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: StageColors.textPrimary,
      ),
    ),
  );
}
