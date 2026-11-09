import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/retention_action.dart';
import '../models/shap_explain.dart';
import '../services/churn_api.dart';
import '../theme/app_theme.dart';

class CustomerShapSheet extends StatefulWidget {
  final String customerId;
  final String? phoneNumber;
  final double? churnProbability;
  final String? riskLevel;
  final int? tenureMonths;
  final double? monthlyCharges;
  final String? contract;
  final String? internetService;
  final VoidCallback? onSimulate;
  final VoidCallback? onAddToActions;
  final VoidCallback? onActionUpdated;

  const CustomerShapSheet({
    super.key,
    required this.customerId,
    this.phoneNumber,
    this.churnProbability,
    this.riskLevel,
    this.tenureMonths,
    this.monthlyCharges,
    this.contract,
    this.internetService,
    this.onSimulate,
    this.onAddToActions,
    this.onActionUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required String customerId,
    String? phoneNumber,
    double? churnProbability,
    String? riskLevel,
    int? tenureMonths,
    double? monthlyCharges,
    String? contract,
    String? internetService,
    VoidCallback? onSimulate,
    VoidCallback? onAddToActions,
    VoidCallback? onActionUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => CustomerShapSheet(
        customerId: customerId,
        phoneNumber: phoneNumber,
        churnProbability: churnProbability,
        riskLevel: riskLevel,
        tenureMonths: tenureMonths,
        monthlyCharges: monthlyCharges,
        contract: contract,
        internetService: internetService,
        onSimulate: onSimulate,
        onAddToActions: onAddToActions,
        onActionUpdated: onActionUpdated,
      ),
    );
  }

  @override
  State<CustomerShapSheet> createState() => _CustomerShapSheetState();
}

class _CustomerShapSheetState extends State<CustomerShapSheet> {
  final ChurnApi _api = ChurnApi();
  late Future<ShapExplainResponse> _explainFuture;
  late Future<RetentionActionsResponse> _actionsFuture;
  int _selectedTab = 0; // 0: Analisis AI & Risiko, 1: Riwayat Intervensi

  @override
  void initState() {
    super.initState();
    _loadExplanation();
    _loadActions();
  }

  void _loadExplanation() {
    setState(() {
      _explainFuture = _api.fetchCustomerExplain(widget.customerId);
    });
  }

  void _loadActions() {
    setState(() {
      _actionsFuture = _api.fetchCustomerActions(widget.customerId);
    });
  }

  Color _getRiskColor(String risk) {
    switch (risk.toUpperCase()) {
      case 'CRITICAL':
        return criticalColor;
      case 'HIGH':
        return highColor;
      default:
        return lowColor;
    }
  }

  void _openWhatsApp(BuildContext context, String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final contract = widget.contract ?? 'Month-to-month';
    final monthly = widget.monthlyCharges ?? 0.0;
    final internet = widget.internetService ?? 'Fiber optic';

    // 1. Tentukan narasi penawaran utama & poin bicara Sales berdasarkan faktor risiko
    String offerHighlight;
    final talkingPoints = <String>[];

    if (contract == 'Month-to-month') {
      offerHighlight =
          'Sebagai bentuk apresiasi kesetiaan Anda, kami menyiapkan Program Kunci Harga & Diskon Komitmen Tahunan 15% agar tagihan bulanan Anda lebih hemat dan terproteksi dari kenaikan tarif.';
      talkingPoints.add('Tawarkan penguncian tarif 1 tahun dengan diskon komitmen 15% (mengatasi risiko kontrak bulanan).');
      talkingPoints.add('Jelaskan kepastian biaya tanpa fluktuasi tarif selama 12 bulan.');
    } else if (monthly >= 70.0) {
      offerHighlight =
          'Berdasarkan Evaluasi Efisiensi Tarif khusus akun Anda, kami menyiapkan Paket Hemat Loyalitas untuk menurunkan beban tagihan bulanan tanpa mengurangi kenyamanan layanan.';
      talkingPoints.add('Tunjukkan rasionalisasi biaya & tawarkan diskon loyalty untuk menurunkan tagihan ${formatRupiah(monthly)}/bln.');
      talkingPoints.add('Tekankan transparansi rincian biaya tanpa biaya tersembunyi.');
    } else if (internet == 'Fiber optic') {
      offerHighlight =
          'Kami menghadirkan program khusus Prioritas Stabilitas Jaringan Fiber lengkap dengan fasilitas prioritas teknis serta Bebas Biaya Admin melalui migrasi autodebit.';
      talkingPoints.add('Tekankan jaminan stabilitas & kecepatan bandwidth fiber optik prioritas.');
      talkingPoints.add('Ajak migrasi ke autodebit bank dengan keuntungan bebas biaya admin setiap bulan.');
    } else {
      offerHighlight =
          'Kami menyiapkan paket penawaran khusus dan diskon retensi eksklusif untuk memastikan kenyamanan layanan terbaik untuk Anda hari ini.';
      talkingPoints.add('Apresiasi masa loyalitas (${widget.tenureMonths ?? 0} bulan) dan tawarkan penyesuaian paket sesuai kebutuhan.');
    }

    final draft =
        'Halo Bapak/Ibu Pelanggan ID ${widget.customerId},\n\n'
        'Saya dari Tim Layanan Pelanggan (Retain Care).\n\n'
        '$offerHighlight\n\n'
        'Boleh kami bantu aktivasi penawaran spesial ini untuk akun Anda hari ini? Terima kasih! 🙏';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 20),
            SizedBox(width: 8),
            Text('Kirim WhatsApp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: bgTertiary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderDefault),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_rounded, size: 14, color: Color(0xFF25D366)),
                    const SizedBox(width: 6),
                    Text(
                      'Tujuan: $phone (Dummy)',
                      style: const TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bgTertiary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Nomor simulasi demo agar aman & tidak menghubungi nomor pengguna asli.',
                  style: TextStyle(color: textSecondary, fontSize: 10.5),
                ),
              ),
              const SizedBox(height: 10),

              // Kotak Panduan Bicara Sales (Talking Points)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: amberPastelBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentOrange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_rounded, size: 14, color: accentOrange),
                        SizedBox(width: 6),
                        Text(
                          '💡 Panduan Bicara Sales (Talking Points)',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...talkingPoints.map((pt) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontSize: 11, color: accentOrange, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(pt, style: const TextStyle(fontSize: 11, color: textSecondary, height: 1.3)),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              const Text(
                'Draf Pesan Terpersonalisasi:',
                style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgTertiary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderDefault),
                ),
                child: Text(draft, style: const TextStyle(fontSize: 11.5, color: textPrimary, height: 1.35)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: textSecondary)),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: draft));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pesan disalin ke clipboard!'),
                  backgroundColor: Color(0xFF25D366),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 14),
            label: const Text('Salin'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF25D366),
              side: const BorderSide(color: Color(0xFF25D366)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(draft)}');
              try {
                if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                  await launchUrl(uri, mode: LaunchMode.platformDefault);
                }
              } catch (_) {
                Clipboard.setData(ClipboardData(text: draft));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tidak dapat membuka WA langsung, teks disalin.'),
                    backgroundColor: highColor,
                  ),
                );
              }
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 14),
            label: const Text('Buka WA', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final riskColor = _getRiskColor(widget.riskLevel ?? 'LOW');
    final probPct = widget.churnProbability != null
        ? (widget.churnProbability! * 100).toStringAsFixed(1)
        : null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        mediaQuery.viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: borderDefault,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgTertiary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.psychology_rounded, color: accentCyan, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.customerId,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'Faktor Risiko & Profil Akun',
                      style: TextStyle(color: textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (widget.riskLevel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: riskColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${formatRiskLabel(widget.riskLevel).toUpperCase()} ${probPct != null ? "$probPct%" : ""}',
                    style: TextStyle(
                      color: riskColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: 'Tutup',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, color: textSecondary, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Customer Attribute Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (widget.tenureMonths != null)
                  _infoPill(Icons.history_rounded, 'Tenor', '${widget.tenureMonths} bln'),
                if (widget.monthlyCharges != null)
                  _infoPill(Icons.account_balance_wallet_rounded, 'Tagihan', '${formatRupiah(widget.monthlyCharges)}/bln'),
                if (widget.contract != null)
                  _infoPill(Icons.description_rounded, 'Kontrak', formatContractLabel(widget.contract)),
                if (widget.internetService != null)
                  _infoPill(Icons.wifi_rounded, 'Internet', formatInternetLabel(widget.internetService)),
                if (widget.phoneNumber != null)
                  _infoPill(Icons.phone_rounded, 'WhatsApp', '${widget.phoneNumber!} (Dummy)'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ─── Segmented Tabs: Analisis AI vs Riwayat Intervensi ───
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: bgTertiary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderDefault),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _selectedTab == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.psychology_rounded,
                            size: 15,
                            color: _selectedTab == 0 ? navyPrimary : textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Analisis AI & SHAP',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: _selectedTab == 0 ? FontWeight.w700 : FontWeight.w500,
                              color: _selectedTab == 0 ? textPrimary : textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _selectedTab == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 15,
                            color: _selectedTab == 1 ? navyPrimary : textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Riwayat Intervensi',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: _selectedTab == 1 ? FontWeight.w700 : FontWeight.w500,
                              color: _selectedTab == 1 ? textPrimary : textSecondary,
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
          const SizedBox(height: 14),

          // Scrollable Tab Body: SHAP or History
          Flexible(
            child: SingleChildScrollView(
              child: _selectedTab == 0
                  ? _buildShapExplainSection()
                  : _buildInterventionHistorySection(),
            ),
          ),
          const SizedBox(height: 16),

          // Bottom Action Row (Uniform Height & Centered Content)
          Row(
            children: [
              if (widget.phoneNumber != null) ...[
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => _openWhatsApp(context, widget.phoneNumber!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_rounded, size: 15),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Chat WA',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (widget.onSimulate != null) ...[
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onSimulate!();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentCyan,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded, size: 15),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Simulasi',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (widget.onAddToActions != null)
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onAddToActions!();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentTeal,
                        side: const BorderSide(color: accentTeal),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_task_rounded, size: 15),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Buat Tugas',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShapExplainSection() {
    return FutureBuilder<ShapExplainResponse>(
      future: _explainFuture,
      builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(strokeWidth: 2.5, color: accentCyan),
                            SizedBox(height: 12),
                            Text(
                              'Menganalisis faktor pendorong risiko...',
                              style: TextStyle(color: textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: criticalBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: criticalColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: criticalColor, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Gagal memuat analisis profil risiko',
                                style: TextStyle(color: criticalColor, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('${snapshot.error}', style: const TextStyle(color: textSecondary, fontSize: 11)),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _loadExplanation,
                            icon: const Icon(Icons.refresh_rounded, size: 14),
                            label: const Text('Coba Lagi', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: accentCyan,
                              side: const BorderSide(color: accentCyan),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final data = snapshot.data!;
                  final contributions = data.contributions;

                  if (contributions.isEmpty) {
                    return const Center(
                      child: Text('Tidak ada kontribusi fitur signifikan', style: TextStyle(color: textSecondary)),
                    );
                  }

                  // Find max absolute value to normalize bar widths
                  final maxVal = contributions
                      .map((c) => c.shapValue.abs())
                      .reduce((a, b) => math.max(a, b));

                  // Top driver
                  final topDriver = contributions.first;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // XAI Header Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: bgTertiary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: accentPurple.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.auto_awesome_rounded, color: accentPurple, size: 15),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Faktor Pendorong Risiko (Key Risk Drivers)',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Menampilkan faktor utama yang menaikkan risiko churn atau mendukung bertahannya pelanggan berdasarkan data histori penggunaan.',
                              style: TextStyle(color: textSecondary, fontSize: 11, height: 1.3),
                            ),
                            const SizedBox(height: 10),

                            // Legend
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: criticalColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'Menaikkan Risiko Churn (+)',
                                      style: TextStyle(color: criticalColor, fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: lowColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'Menurunkan Risiko (-)',
                                      style: TextStyle(color: lowColor, fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Top Driver Callout
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: topDriver.shapValue > 0
                              ? criticalBg
                              : lowBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: topDriver.shapValue > 0
                                ? criticalColor.withValues(alpha: 0.3)
                                : lowColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              topDriver.shapValue > 0
                                  ? Icons.warning_amber_rounded
                                  : Icons.verified_user_rounded,
                              color: topDriver.shapValue > 0 ? criticalColor : lowColor,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(fontSize: 11, height: 1.3),
                                  children: [
                                    const TextSpan(
                                      text: 'Faktor Paling Berpengaruh: ',
                                      style: TextStyle(color: textSecondary),
                                    ),
                                    TextSpan(
                                      text: topDriver.feature,
                                      style: TextStyle(
                                        color: topDriver.shapValue > 0 ? criticalColor : lowColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(
                                      text: topDriver.shapValue > 0
                                          ? ' berkontribusi kuat mendorong pelanggan ingin berhenti.'
                                          : ' menahan pelanggan agar tetap setia.',
                                      style: const TextStyle(color: textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text(
                        'Rincian Bobot Kontribusi Fitur',
                        style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),

                      // Contribution Bar List
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: contributions.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = contributions[index];
                          final isPositive = item.shapValue > 0;
                          final barColor = isPositive ? criticalColor : lowColor;
                          final fraction = maxVal > 0 ? (item.shapValue.abs() / maxVal).clamp(0.08, 1.0) : 0.1;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: bgTertiary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.feature,
                                        style: const TextStyle(
                                          color: textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: barColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${isPositive ? "+" : ""}${item.shapValue.toStringAsFixed(3)}',
                                        style: TextStyle(
                                          color: barColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Normalized Bar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    height: 6,
                                    width: double.infinity,
                                    color: bgTertiary,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor: fraction,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: barColor,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Enterprise Footnote
                      const Center(
                        child: Text(
                          'Analisis kontribusi faktor risiko berbasis data transaksi historis real-time.',
                          style: TextStyle(color: textTertiary, fontSize: 10),
                        ),
                      ),
                    ],
                  );
                },
              );
  }

  Widget _buildInterventionHistorySection() {
    return FutureBuilder<RetentionActionsResponse>(
      future: _actionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5, color: accentCyan),
                  SizedBox(height: 12),
                  Text('Memuat riwayat intervensi...', style: TextStyle(color: textSecondary, fontSize: 12)),
                ],
              ),
            ),
          );
        }

        final actions = snapshot.data?.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sub-header with Add Action Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Histori Intervensi (${actions.length})',
                        style: const TextStyle(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Jejak penanganan, penawaran & status mitigasi retensi',
                        style: TextStyle(color: textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _showAddActionDialog(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: navyPrimary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Catat Log',
                          style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (actions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: bgTertiary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderDefault),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.history_toggle_off_rounded, size: 30, color: textSecondary),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Belum Ada Riwayat Intervensi',
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pelanggan ini belum pernah dihubungi atau ditambahkan ke Action Center.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondary, fontSize: 11.5),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => _showAddActionDialog(context),
                      icon: const Icon(Icons.add_task_rounded, size: 14),
                      label: const Text('Buat Tindakan Retensi Sekarang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: navyPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: actions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = actions[index];
                  return _buildHistoryItemCard(item);
                },
              ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildHistoryItemCard(RetentionActionItem item) {
    Color statusColor;
    Color statusBg;
    String statusText;

    switch (item.status) {
      case 'RESOLVED':
        statusColor = lowColor;
        statusBg = lowBg;
        statusText = '🟢 Terselamatkan';
        break;
      case 'IN_PROGRESS':
        statusColor = highColor;
        statusBg = highBg;
        statusText = '🟠 Sedang Diproses';
        break;
      case 'PENDING':
      default:
        statusColor = criticalColor;
        statusBg = criticalBg;
        statusText = '🔴 Butuh Tindakan';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.status == 'RESOLVED' ? lowColor.withValues(alpha: 0.3) : borderDefault,
        ),
        boxShadow: softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_note_rounded, size: 14, color: textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    item.createdAt ?? 'Baru saja',
                    style: const TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                onSelected: (newStatus) async {
                  try {
                    await _api.updateActionStatus(actionId: item.id, status: newStatus);
                    _loadActions();
                    widget.onActionUpdated?.call();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Status diubah ke: $newStatus'), backgroundColor: bgCard),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal mengubah status: $e'), backgroundColor: criticalColor),
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down_rounded, size: 14, color: statusColor),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'PENDING', child: Text('🔴 Butuh Tindakan')),
                  const PopupMenuItem(value: 'IN_PROGRESS', child: Text('🟠 Sedang Diproses')),
                  const PopupMenuItem(value: 'RESOLVED', child: Text('🟢 Terselamatkan')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: const TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: bgTertiary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.actionType,
                  style: const TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${item.phoneNumber} (Dummy)',
                style: const TextStyle(color: Color(0xFF25D366), fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (item.note != null && item.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bgTertiary.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Catatan: ${item.note}',
                style: const TextStyle(color: textSecondary, fontSize: 11.5, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddActionDialog(BuildContext context) {
    final titleController = TextEditingController(text: 'Follow-up Retensi: Penawaran Khusus');
    final noteController = TextEditingController();
    String actionType = 'OFFER_DISCOUNT';
    String status = 'PENDING';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgTertiary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_task_rounded, color: navyPrimary, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Catat Intervensi Baru',
                  style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pelanggan:', style: TextStyle(color: textSecondary, fontSize: 11)),
                Text(widget.customerId, style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Judul Tindakan',
                    hintText: 'Contoh: Courtesy Call atau Penawaran Diskon',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: actionType,
                  decoration: const InputDecoration(labelText: 'Jenis Intervensi'),
                  items: const [
                    DropdownMenuItem(value: 'OFFER_DISCOUNT', child: Text('Diskon / Penyesuaian Tarif', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'UPGRADE_CONTRACT', child: Text('Komitmen Kontrak Baru', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'CALL_FOLLOWUP', child: Text('Courtesy Call / Cek Masalah', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'SWITCH_AUTODEBIT', child: Text('Migrasi Autodebit', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => actionType = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status Awal'),
                  items: const [
                    DropdownMenuItem(value: 'PENDING', child: Text('🔴 Butuh Tindakan (Pending)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'IN_PROGRESS', child: Text('🟠 Sedang Diproses', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'RESOLVED', child: Text('🟢 Terselamatkan', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => status = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Catatan / Hasil Komunikasi',
                    hintText: 'Tuliskan kesepakatan atau kendala pelanggan...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await _api.createAction(
                    customerId: widget.customerId,
                    title: title,
                    actionType: actionType,
                    status: status,
                    note: noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
                  );
                  _loadActions();
                  widget.onActionUpdated?.call();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Intervensi berhasil dicatat!'),
                        backgroundColor: lowColor,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal menyimpan intervensi: $e'), backgroundColor: criticalColor),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: navyPrimary, foregroundColor: Colors.white),
              child: const Text('Simpan Intervensi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoPill(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgTertiary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accentCyan),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: const TextStyle(color: textSecondary, fontSize: 11),
          ),
          Text(
            value,
            style: const TextStyle(color: textPrimary, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
