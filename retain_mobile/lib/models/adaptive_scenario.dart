import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AdaptiveScenario {
  final String id;
  final String title;
  final String badge;
  final String badgeType;
  final String diagnosis; // Analisa Masalah Pelanggan
  final String solutionAnalysis; // Analisa Solusi AI
  final String targetContract;
  final double targetMonthlyCharges;
  final String targetPaymentMethod;
  final String targetInternetService;
  final double targetTenure;
  final String discountTag;
  final double projectedRiskReduction;
  final double projectedChurnProbability;
  final String projectedRiskLevel;

  const AdaptiveScenario({
    required this.id,
    required this.title,
    required this.badge,
    required this.badgeType,
    required this.diagnosis,
    required this.solutionAnalysis,
    required this.targetContract,
    required this.targetMonthlyCharges,
    required this.targetPaymentMethod,
    required this.targetInternetService,
    required this.targetTenure,
    required this.discountTag,
    required this.projectedRiskReduction,
    this.projectedChurnProbability = 0.0,
    this.projectedRiskLevel = 'LOW',
  });

  Color getBadgeColor() {
    switch (badgeType) {
      case 'primary':
        return navyPrimary;
      case 'warning':
        return accentOrange;
      case 'success':
        return lowColor;
      case 'purple':
        return accentPurple;
      case 'teal':
        return accentTeal;
      default:
        return navyLight;
    }
  }

  Color getBadgeBg() {
    switch (badgeType) {
      case 'primary':
        return bluePastelBg;
      case 'warning':
        return const Color(0xFFFFFBEB);
      case 'success':
        return lowBg;
      case 'purple':
        return const Color(0xFFF3E8FF);
      case 'teal':
        return const Color(0xFFECFDF5);
      default:
        return bgTertiary;
    }
  }

  IconData getIcon() {
    switch (id) {
      case 'CONTRACT_LOCK_1YR':
        return Icons.lock_clock_rounded;
      case 'BILL_SHOCK_RELIEF':
        return Icons.price_check_rounded;
      case 'AUTODEBIT_MIGRATION':
        return Icons.account_balance_rounded;
      case 'VIP_LOYALTY_2YR':
        return Icons.workspace_premium_rounded;
      case 'FIBER_UPGRADE_1YR':
        return Icons.speed_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  factory AdaptiveScenario.fromJson(Map<String, dynamic> json) {
    return AdaptiveScenario(
      id: json['id'] as String? ?? 'SCENARIO',
      title: json['title'] as String? ?? 'Skenario Retensi',
      badge: json['badge'] as String? ?? 'Rekomendasi',
      badgeType: json['badge_type'] as String? ?? 'primary',
      diagnosis: json['diagnosis'] as String? ?? '',
      solutionAnalysis: json['solution_analysis'] as String? ?? '',
      targetContract: json['target_contract'] as String? ?? 'One year',
      targetMonthlyCharges: (json['target_monthly_charges'] as num?)?.toDouble() ?? 65.0,
      targetPaymentMethod: json['target_payment_method'] as String? ?? 'Bank transfer (automatic)',
      targetInternetService: json['target_internet_service'] as String? ?? 'Fiber optic',
      targetTenure: (json['target_tenure'] as num?)?.toDouble() ?? 12.0,
      discountTag: json['discount_tag'] as String? ?? 'Optimal',
      projectedRiskReduction: (json['projected_risk_reduction'] as num?)?.toDouble() ?? 45.0,
      projectedChurnProbability: (json['projected_churn_probability'] as num?)?.toDouble() ?? 0.25,
      projectedRiskLevel: json['projected_risk_level'] as String? ?? 'LOW',
    );
  }
}

class AdaptiveScenarioEngine {
  /// Generate client-side adaptive scenarios tailored to customer features
  static List<AdaptiveScenario> generate({
    required double baseTenure,
    required double baseMonthlyCharges,
    required String baseContract,
    required String baseInternet,
    required String basePayment,
  }) {
    final List<AdaptiveScenario> scenarios = [];

    // 1. Kontrak Bulanan -> Solusi Kunci Komitmen 1 Tahun
    if (baseContract == 'Month-to-month') {
      scenarios.add(
        AdaptiveScenario(
          id: 'CONTRACT_LOCK_1YR',
          title: 'Paket Komitmen Hemat 1 Tahun',
          badge: 'Solusi Risiko Utama',
          badgeType: 'primary',
          diagnosis: 'Pelanggan berada pada kontrak bulanan fleksibel tanpa ikatan komitmen (penyumbang 38.4% bobot risiko churn).',
          solutionAnalysis: 'AI menganalisis bahwa mengunci komitmen 12 bulan dengan potongan harga 15% serta migrasi pembayaran otomatis akan menstabilkan retensi secara drastis.',
          targetContract: 'One year',
          targetMonthlyCharges: double.parse((baseMonthlyCharges * 0.85).toStringAsFixed(1)),
          targetPaymentMethod: (basePayment == 'Electronic check' || basePayment == 'Mailed check')
              ? 'Bank transfer (automatic)'
              : basePayment,
          targetInternetService: baseInternet,
          targetTenure: baseTenure < 12 ? 12.0 : baseTenure,
          discountTag: '-15% Diskon',
          projectedRiskReduction: 58.5,
          projectedChurnProbability: 0.28,
          projectedRiskLevel: 'LOW',
        ),
      );
    }

    // 2. Beban Tagihan Tinggi -> Relief Tagihan & Rasionalisasi
    if (baseMonthlyCharges >= 70.0) {
      scenarios.add(
        AdaptiveScenario(
          id: 'BILL_SHOCK_RELIEF',
          title: 'Relief Beban Tagihan (Anti-Bill Shock)',
          badge: 'Meredakan Beban Biaya',
          badgeType: 'warning',
          diagnosis: 'Beban tagihan saat ini (${formatRupiah(baseMonthlyCharges)}) berada di atas toleransi sensitivitas harga, memicu akun mencari alternatif kompetitor.',
          solutionAnalysis: 'AI merekomendasikan restrukturisasi paket dengan pemotongan tarif 22% dipadukan kontrak tahunan guna melindungi nilai Customer Lifetime Value (LTV).',
          targetContract: baseContract == 'Month-to-month' ? 'One year' : baseContract,
          targetMonthlyCharges: double.parse((baseMonthlyCharges * 0.78).toStringAsFixed(1)),
          targetPaymentMethod: (basePayment == 'Electronic check' || basePayment == 'Mailed check')
              ? 'Bank transfer (automatic)'
              : basePayment,
          targetInternetService: baseInternet,
          targetTenure: baseTenure,
          discountTag: '-22% Hemat',
          projectedRiskReduction: 48.2,
          projectedChurnProbability: 0.32,
          projectedRiskLevel: 'LOW',
        ),
      );
    }

    // 3. Friksi Pembayaran Manual -> Migrasi Autodebit
    if (basePayment == 'Electronic check' || basePayment == 'Mailed check') {
      scenarios.add(
        AdaptiveScenario(
          id: 'AUTODEBIT_MIGRATION',
          title: 'Migrasi Autodebit Bank + Bebas Admin',
          badge: 'Eliminasi Friksi Bayar',
          badgeType: 'success',
          diagnosis: 'Metode bayar ($basePayment) memicu friksi manual rutin setiap siklus penagihan, melipatgandakan churn pasif dibanding autodebit.',
          solutionAnalysis: 'AI menyarankan migrasi langsung ke Autodebit Bank dengan cashback potongan biaya admin ${formatRupiah(5.0)}/bln demi menjamin kelancaran siklus penagihan.',
          targetContract: baseContract,
          targetMonthlyCharges: double.parse((baseMonthlyCharges > 10 ? baseMonthlyCharges - 5.0 : baseMonthlyCharges).toStringAsFixed(1)),
          targetPaymentMethod: 'Bank transfer (automatic)',
          targetInternetService: baseInternet,
          targetTenure: baseTenure,
          discountTag: 'Bebas Admin',
          projectedRiskReduction: 28.0,
          projectedChurnProbability: 0.42,
          projectedRiskLevel: 'MEDIUM',
        ),
      );
    }

    // 4. Pelanggan Veteran (Tenure >= 24) -> VIP Loyalty Lock 2 Tahun
    if (baseTenure >= 24 || scenarios.length < 3) {
      scenarios.add(
        AdaptiveScenario(
          id: 'VIP_LOYALTY_2YR',
          title: 'Program Retensi VIP 2 Tahun',
          badge: 'Apresiasi Loyalitas VIP',
          badgeType: 'purple',
          diagnosis: 'Pelanggan dengan loyalitas ${baseTenure.round()} bulan memerlukan apresiasi khusus agar tidak tergiur promosi akuisisi provider kompetitor.',
          solutionAnalysis: 'AI merekomendasikan komitmen 2 tahun dengan diskon VIP 20% dan prioritas layanan untuk memaksimalkan retensi akun jangka panjang.',
          targetContract: 'Two year',
          targetMonthlyCharges: double.parse((baseMonthlyCharges * 0.80).toStringAsFixed(1)),
          targetPaymentMethod: 'Bank transfer (automatic)',
          targetInternetService: baseInternet,
          targetTenure: baseTenure < 24 ? 24.0 : baseTenure,
          discountTag: '-20% VIP',
          projectedRiskReduction: 74.5,
          projectedChurnProbability: 0.12,
          projectedRiskLevel: 'LOW',
        ),
      );
    }

    // 5. Layanan Non-Fiber -> Upgrade Fiber Optic
    if ((baseInternet == 'DSL' || baseInternet == 'No') && scenarios.length < 4) {
      scenarios.add(
        AdaptiveScenario(
          id: 'FIBER_UPGRADE_1YR',
          title: 'Upgrade Kecepatan Fiber + Promo 1 Tahun',
          badge: 'Peningkatan Kualitas',
          badgeType: 'teal',
          diagnosis: 'Koneksi $baseInternet memiliki keterbatasan bandwidth yang rentan memicu ketidakpuasan performa jaringan.',
          solutionAnalysis: 'AI menyarankan upgrade ke Fiber Optic berkecepatan tinggi dengan kontrak komitmen 1 tahun untuk meningkatkan kepuasan dan keterikatan layanan.',
          targetContract: 'One year',
          targetMonthlyCharges: double.parse((baseMonthlyCharges * 0.95).toStringAsFixed(1)),
          targetPaymentMethod: 'Bank transfer (automatic)',
          targetInternetService: 'Fiber optic',
          targetTenure: baseTenure < 12 ? 12.0 : baseTenure,
          discountTag: 'Promo Fiber',
          projectedRiskReduction: 54.0,
          projectedChurnProbability: 0.22,
          projectedRiskLevel: 'LOW',
        ),
      );
    }

    return scenarios.take(4).toList();
  }
}
