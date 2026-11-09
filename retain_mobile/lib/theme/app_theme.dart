import 'package:flutter/material.dart';

// ─── Bespoke Enterprise Color Palette (Solid, High-Contrast & Minimalist) ──
const Color bgPrimary = Color(0xFFF8FAFC);     // Slate 50 clean canvas
const Color bgSecondary = Colors.white;         // Pure white cards
const Color bgTertiary = Color(0xFFF1F5F9);      // Slate 100 neutral fills
const Color bgSidebar = Color(0xFFF8FAFC);
const Color bgCard = Colors.white;
const Color bgCardHover = Color(0xFFF8FAFC);
const Color borderDefault = Color(0xFFE2E8F0);   // Slate 200 crisp border
const Color borderMuted = Color(0xFFF1F5F9);

// Hero & Brand Accent (Deep Obsidian Slate & Sharp Indigo/Cobalt)
const Color navyPrimary = Color(0xFF0F172A);    // Deep Obsidian Slate 900
const Color navyDark = Color(0xFF020617);       // Rich Slate 950
const Color navyLight = Color(0xFF1E293B);      // Crisp Slate 800

// Functional Enterprise Accents
const Color accentCyan = Color(0xFF2563EB);     // Royal Blue for key CTA
const Color accentTeal = Color(0xFF059669);     // Emerald 600 for positive revenue saved
const Color accentOrange = Color(0xFFD97706);   // Amber 600 for moderate risk
const Color accentRed = Color(0xFFDC2626);      // Crimson 600 for critical risk
const Color accentPurple = Color(0xFF4F46E5);   // Indigo 600 for AI solutions

// Crisp Functional Fills (Subtle tints for contextual badges)
const Color bluePastelBg = Color(0xFFEFF6FF);
const Color amberPastelBg = Color(0xFFFFFBEB);
const Color emeraldPastelBg = Color(0xFFECFDF5);
const Color rosePastelBg = Color(0xFFFEF2F2);
const Color purplePastelBg = Color(0xFFEEF2FF);

// Risk Semantic Colors
const Color criticalColor = Color(0xFFDC2626);
const Color criticalBg = Color(0xFFFEF2F2);
const Color highColor = Color(0xFFD97706);
const Color highBg = Color(0xFFFFFBEB);
const Color lowColor = Color(0xFF059669);
const Color lowBg = Color(0xFFECFDF5);

// Typography & Contrast (Slate Hierarchy)
const Color textPrimary = Color(0xFF0F172A);    // Slate 900 for crisp readability
const Color textSecondary = Color(0xFF475569);  // Slate 600
const Color textTertiary = Color(0xFF94A3B8);   // Slate 400
const Color textLink = Color(0xFF2563EB);

// Soft Clean Shadows (No AI glow, crisp elevation)
final List<BoxShadow> softCardShadow = [
  BoxShadow(
    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
    blurRadius: 12,
    offset: const Offset(0, 3),
  ),
  BoxShadow(
    color: const Color(0xFF0F172A).withValues(alpha: 0.02),
    blurRadius: 4,
    offset: const Offset(0, 1),
  ),
];

final List<BoxShadow> heroBannerShadow = [
  BoxShadow(
    color: const Color(0xFF0F172A).withValues(alpha: 0.12),
    blurRadius: 16,
    offset: const Offset(0, 6),
  ),
];

// ─── Theme Data ───────────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: navyPrimary,
      brightness: Brightness.light,
      surface: bgSecondary,
    ),
    scaffoldBackgroundColor: bgPrimary,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: textPrimary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: textTertiary),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: borderDefault),
        borderRadius: BorderRadius.circular(14),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: navyLight, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: criticalColor),
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: navyLight,
      inactiveTrackColor: borderDefault,
      thumbColor: navyLight,
      overlayColor: navyLight.withValues(alpha: 0.12),
      valueIndicatorColor: navyPrimary,
      valueIndicatorTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      trackHeight: 5,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: textPrimary,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(borderDefault),
      thickness: WidgetStateProperty.all(6),
      radius: const Radius.circular(3),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

// ─── UI Localization Helpers (Sales Friendly) ───────────────────────────────
String formatContractLabel(String? raw) {
  switch (raw) {
    case 'Month-to-month':
      return 'Kontrak Bulanan';
    case 'One year':
      return 'Kontrak 1 Tahun';
    case 'Two year':
      return 'Kontrak 2 Tahun';
    default:
      return raw ?? '-';
  }
}

String formatInternetLabel(String? raw) {
  switch (raw) {
    case 'DSL':
      return 'Reguler (DSL)';
    case 'Fiber optic':
      return 'Fiber Optik';
    case 'No':
      return 'Hanya Telepon';
    default:
      return raw ?? '-';
  }
}

String formatPaymentLabel(String? raw) {
  switch (raw) {
    case 'Electronic check':
      return 'E-Check (Manual)';
    case 'Mailed check':
      return 'Tagihan Pos (Manual)';
    case 'Bank transfer (automatic)':
      return 'Autodebit Bank';
    case 'Credit card (automatic)':
      return 'Autodebit Kartu Kredit';
    default:
      return raw ?? '-';
  }
}

String formatRiskLabel(String? raw) {
  switch (raw?.toUpperCase()) {
    case 'CRITICAL':
      return 'Kritis';
    case 'HIGH':
      return 'Tinggi';
    case 'MEDIUM':
      return 'Sedang';
    case 'LOW':
      return 'Rendah';
    default:
      return raw ?? '-';
  }
}

// ─── Currency Helpers (IDR Converter & Formatter) ───────────────────────────
const double usdToIdrRate = 18121.15;

/// Konversi nominal dari USD ke Rupiah
double usdToIdr(num usdAmount) => usdAmount * usdToIdrRate;

/// Konversi nominal dari Rupiah ke USD (untuk dikirim ke Model Backend)
double idrToUsd(num idrAmount) => idrAmount / usdToIdrRate;

/// Mengonversi nilai USD (basis dataset) ke mata uang Rupiah (IDR).
/// Mendukung format lengkap (misal: "Rp 975.000") atau compact (misal: "Rp 14,5 Jt").
String formatRupiah(
  num? usdAmount, {
  bool compact = false,
  bool withPrefix = true,
}) {
  if (usdAmount == null) return withPrefix ? 'Rp 0' : '0';
  final idr = (usdAmount * usdToIdrRate).round();
  final isNegative = idr < 0;
  final absIdr = idr.abs();

  String formatted;
  if (compact && absIdr >= 1000000000) {
    final val = absIdr / 1000000000;
    formatted = '${val.toStringAsFixed(1).replaceAll('.', ',')} M';
  } else if (compact && absIdr >= 1000000) {
    final val = absIdr / 1000000;
    formatted = '${val.toStringAsFixed(1).replaceAll('.', ',')} Jt';
  } else {
    final str = absIdr.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    formatted = buffer.toString();
  }

  final sign = isNegative ? '-' : '';
  final prefix = withPrefix ? 'Rp ' : '';
  return '$sign$prefix$formatted';
}

