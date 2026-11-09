import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/adaptive_scenario.dart';
import '../models/churn_result.dart';
import '../models/simulation_result.dart';
import '../services/churn_api.dart';
import '../theme/app_theme.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({
    super.key,
    this.initialCustomer,
    this.onClearCustomer,
    this.onCustomerChanged,
    this.onActionCreated,
    this.onNavigateToActionCenter,
  });

  final ChurnResult? initialCustomer;
  final VoidCallback? onClearCustomer;
  final ValueChanged<ChurnResult?>? onCustomerChanged;
  final VoidCallback? onActionCreated;
  final VoidCallback? onNavigateToActionCenter;

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  final ChurnApi _api = ChurnApi();
  final TextEditingController _chargesController = TextEditingController();
  Timer? _debounce;

  ChurnResult? _currentCustomer;
  double _tenure = 12;
  String _contract = 'One year';
  String _internet = 'Fiber optic';
  String _payment = 'Bank transfer (automatic)';
  bool _loading = false;
  SimulationResult? _result;

  List<AdaptiveScenario> _scenarios = [];
  int _selectedScenarioIndex = 0;
  bool _loadingScenarios = false;

  final List<Map<String, String>> _contractOptions = const [
    {'label': 'Bulanan', 'value': 'Month-to-month'},
    {'label': '1 Tahun', 'value': 'One year'},
    {'label': '2 Tahun', 'value': 'Two year'},
  ];

  final List<Map<String, String>> _internetOptions = const [
    {'label': 'Reguler (DSL)', 'value': 'DSL'},
    {'label': 'Fiber Optik', 'value': 'Fiber optic'},
    {'label': 'Hanya Telepon', 'value': 'No'},
  ];

  final List<Map<String, String>> _paymentOptions = const [
    {'label': 'E-Check (Manual)', 'value': 'Electronic check'},
    {'label': 'Tagihan Pos (Manual)', 'value': 'Mailed check'},
    {'label': 'Autodebit Bank', 'value': 'Bank transfer (automatic)'},
    {'label': 'Autodebit Kartu Kredit', 'value': 'Credit card (automatic)'},
  ];

  @override
  void initState() {
    super.initState();
    _currentCustomer = widget.initialCustomer;
    _applyCustomer(_currentCustomer);
  }

  @override
  void didUpdateWidget(covariant SimulationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCustomer != oldWidget.initialCustomer) {
      _currentCustomer = widget.initialCustomer;
      _applyCustomer(_currentCustomer);
    }
  }

  void _openCustomerPickerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomerPickerSheet(
        api: _api,
        onSelect: (customer) {
          setState(() {
            _currentCustomer = customer;
          });
          _applyCustomer(customer);
          widget.onCustomerChanged?.call(customer);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pelanggan ${customer.customerId} berhasil dimuat sebagai basis simulasi!'),
              backgroundColor: accentTeal,
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  void _applyCustomer(ChurnResult? c) {
    if (c != null) {
      _tenure = c.tenureMonths.toDouble().clamp(1.0, 72.0);
      _chargesController.text = (c.monthlyCharges * usdToIdrRate).round().toString();

      // Validate contract
      if (_contractOptions.any((o) => o['value'] == c.contract)) {
        _contract = c.contract;
      } else {
        _contract = 'One year';
      }

      // Validate internet
      final internet = c.internetService ?? 'Fiber optic';
      if (_internetOptions.any((o) => o['value'] == internet)) {
        _internet = internet;
      } else {
        _internet = 'Fiber optic';
      }

      // Validate payment
      final payment = c.paymentMethod ?? 'Electronic check';
      if (_paymentOptions.any((o) => o['value'] == payment)) {
        _payment = payment;
      } else {
        _payment = 'Bank transfer (automatic)';
      }
      _result = null;
      _generateAndFetchScenarios(c);
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSimulation());
    } else {
      _tenure = 12.0;
      _chargesController.text = (65.0 * usdToIdrRate).round().toString();
      _contract = 'One year';
      _internet = 'Fiber optic';
      _payment = 'Bank transfer (automatic)';
      _result = null;
      _generateAndFetchScenarios(null);
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSimulation());
    }
  }

  void _generateAndFetchScenarios(ChurnResult? c) {
    final currentTenure = c?.tenureMonths.toDouble() ?? _tenure;
    final currentCharges = c?.monthlyCharges ?? (idrToUsd(double.tryParse(_chargesController.text.trim().replaceAll(RegExp(r'[^0-9.]'), '')) ?? (65.0 * usdToIdrRate)));
    final currentContract = c?.contract ?? _contract;
    final currentInternet = c?.internetService ?? _internet;
    final currentPayment = c?.paymentMethod ?? _payment;

    setState(() {
      _scenarios = AdaptiveScenarioEngine.generate(
        baseTenure: currentTenure,
        baseMonthlyCharges: currentCharges,
        baseContract: currentContract,
        baseInternet: currentInternet,
        basePayment: currentPayment,
      );
      _selectedScenarioIndex = 0;
    });

    if (c != null && c.customerId.isNotEmpty) {
      _fetchBackendScenarios(c.customerId);
    }
  }

  Future<void> _fetchBackendScenarios(String customerId) async {
    setState(() => _loadingScenarios = true);
    try {
      final remoteScenarios = await _api.fetchRecommendedScenarios(customerId);
      if (mounted && remoteScenarios.isNotEmpty) {
        setState(() {
          _scenarios = remoteScenarios;
        });
      }
    } catch (_) {
      // Keep client-side adapted scenarios if offline or error
    } finally {
      if (mounted) setState(() => _loadingScenarios = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _chargesController.dispose();
    super.dispose();
  }

  void _triggerRealtimeSimulation() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _runSimulation();
    });
  }

  Future<void> _runSimulation() async {
    final rawInput = _chargesController.text.trim().replaceAll(RegExp(r'[^0-9.]'), '');
    final idrMonthly = double.tryParse(rawInput);
    if (idrMonthly == null || idrMonthly < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Masukkan nominal tagihan bulanan yang valid (Rupiah)'),
          ),
        );
      }
      return;
    }
    final monthly = idrToUsd(idrMonthly);

    setState(() => _loading = true);
    try {
      final tenure = _tenure.round();
      final result = await _api.simulate(
        tenure: tenure,
        monthlyCharges: monthly,
        totalCharges: monthly * tenure,
        contract: _contract,
        internetService: _internet,
        paymentMethod: _payment,
        baselineProbability: _currentCustomer?.churnProbability,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Simulasi gagal: $error')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyAdaptiveScenario(AdaptiveScenario scenario) {
    setState(() {
      _contract = scenario.targetContract;
      _chargesController.text = (scenario.targetMonthlyCharges * usdToIdrRate).round().toString();
      _payment = scenario.targetPaymentMethod;
      _internet = scenario.targetInternetService;
      _tenure = scenario.targetTenure.clamp(1.0, 72.0);
    });
    _runSimulation();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Skenario "${scenario.title}" diterapkan! Menjalankan kalkulasi model...'),
        backgroundColor: accentTeal,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _createActionFromSimulation() async {
    if (_currentCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Silakan pilih pelanggan terlebih dahulu untuk menyimpan tindakan.'),
          backgroundColor: highColor,
          action: SnackBarAction(
            label: 'Pilih Pelanggan',
            textColor: Colors.white,
            onPressed: () => _openCustomerPickerModal(context),
          ),
        ),
      );
      return;
    }

    final customer = _currentCustomer!;
    final cid = customer.customerId;
    final rawInput = _chargesController.text.trim().replaceAll(RegExp(r'[^0-9.]'), '');
    final monthlyUsd = idrToUsd(double.tryParse(rawInput) ?? (65.0 * usdToIdrRate));
    final res = _result;

    try {
      await _api.createAction(
        customerId: cid,
        actionType: _contract == 'Month-to-month' ? 'OFFER_DISCOUNT' : 'UPGRADE_CONTRACT',
        title: 'Paket Retensi: Kontrak ${formatContractLabel(_contract)} (${formatRupiah(monthlyUsd)}/bln)',
        note: 'Hasil simulasi: ${formatContractLabel(_contract)}, ${formatInternetLabel(_internet)}, ${formatPaymentLabel(_payment)}. '
            'Risiko diproyeksikan ${formatRiskLabel(res?.riskLevel ?? "LOW")} (${res != null ? (res.newChurnProbability * 100).toStringAsFixed(1) : ""}%). '
            'Reduksi: ${res?.riskReductionPercentage ?? 0}%. Rekomendasi: ${res?.recommendation ?? ""}',
      );
      widget.onActionCreated?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paket hasil simulasi untuk $cid berhasil ditambahkan ke Action Center!'),
          backgroundColor: accentTeal,
          action: widget.onNavigateToActionCenter != null
              ? SnackBarAction(
                  label: 'Lihat',
                  textColor: Colors.white,
                  onPressed: () => widget.onNavigateToActionCenter?.call(),
                )
              : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan tugas: $e'), backgroundColor: criticalColor),
      );
    }
  }

  void _showSimulatedWhatsAppDialog() {
    if (_currentCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Silakan pilih pelanggan terlebih dahulu untuk membuat draf WhatsApp.'),
          backgroundColor: highColor,
          action: SnackBarAction(
            label: 'Pilih Pelanggan',
            textColor: Colors.white,
            onPressed: () => _openCustomerPickerModal(context),
          ),
        ),
      );
      return;
    }

    final customer = _currentCustomer!;
    final cid = customer.customerId;
    final rawInput = _chargesController.text.trim().replaceAll(RegExp(r'[^0-9.]'), '');
    final monthlyUsd = idrToUsd(double.tryParse(rawInput) ?? (65.0 * usdToIdrRate));
    final cleanPhone =
        '+62800${customer.customerId.replaceAll(RegExp(r'[^0-9]'), '').padRight(8, '0').substring(0, 8)}';

    final talkingPoints = <String>[];
    if (_contract == 'Month-to-month') {
      talkingPoints.add('Tawarkan Program Kunci Harga & Diskon Komitmen Tahunan 15%.');
    } else {
      talkingPoints.add('Tekankan proteksi harga tetap selama komitmen kontrak ${formatContractLabel(_contract)}.');
    }
    if (monthlyUsd >= 70) {
      talkingPoints.add('Evaluasi Efisiensi Tarif & Paket Hemat Loyalitas pelanggan.');
    }
    if (_internet == 'Fiber optic') {
      talkingPoints.add('Prioritas Stabilitas Jaringan Fiber & Bebas Biaya Admin Autodebit.');
    }

    final draft =
        'Halo Bapak/Ibu Pelanggan ID $cid,\n\n'
        'Kabar gembira! Berdasarkan evaluasi loyalitas layanan, kami menyiapkan paket retensi khusus untuk Anda hari ini:\n'
        '• Kontrak Komitmen: ${formatContractLabel(_contract)}\n'
        '• Tagihan Bulanan Baru: ${formatRupiah(monthlyUsd)} / bulan\n'
        '• Layanan Internet: ${formatInternetLabel(_internet)}\n'
        '• Metode Pembayaran: ${formatPaymentLabel(_payment)}\n\n'
        'Paket ini memberikan jaminan stabilitas layanan dan diskon hemat tagihan. Balas pesan ini untuk aktivasi instan. Terima kasih! 🙏';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 20),
            SizedBox(width: 8),
            Text('Kirim Penawaran WhatsApp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nomor Tujuan: $cleanPhone', style: const TextStyle(color: textSecondary, fontSize: 13)),
              const SizedBox(height: 10),

              // Kotak Panduan Bicara Sales
              Container(
                padding: const EdgeInsets.all(12),
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
                        Icon(Icons.lightbulb_rounded, size: 16, color: accentOrange),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '💡 Panduan Bicara Sales (Talking Points)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...talkingPoints.map((pt) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontSize: 12.5, color: accentOrange, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(pt, style: const TextStyle(fontSize: 12.5, color: textSecondary, height: 1.35)),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              const Text(
                'Draf Penawaran Resmi:',
                style: TextStyle(color: textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgTertiary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderDefault),
                ),
                child: Text(draft, style: const TextStyle(fontSize: 13, color: textPrimary, height: 1.45)),
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
                  content: Text('Draf penawaran disalin ke clipboard!'),
                  backgroundColor: Color(0xFF25D366),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 14),
            label: const Text('Salin Draf'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF25D366),
              side: const BorderSide(color: Color(0xFF25D366)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final numOnly = cleanPhone.replaceAll(RegExp(r'[^0-9]'), '');
              final uri = Uri.parse('https://wa.me/$numOnly?text=${Uri.encodeComponent(draft)}');
              try {
                if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                  await launchUrl(uri, mode: LaunchMode.platformDefault);
                }
              } catch (_) {
                Clipboard.setData(ClipboardData(text: draft));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Gagal membuka WhatsApp langsung. Draf telah disalin.'),
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

  Widget _buildPresetsSection() {
    if (_scenarios.isEmpty) return const SizedBox.shrink();

    final selectedScenario = _selectedScenarioIndex < _scenarios.length
        ? _scenarios[_selectedScenarioIndex]
        : _scenarios.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: navyPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.psychology_rounded, color: navyPrimary, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preset Skenario & Solusi AI',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Skenario preskriptif profil risiko akun',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_loadingScenarios) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: navyLight),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Horizontal Scenario Selector Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: List.generate(_scenarios.length, (index) {
              final sc = _scenarios[index];
              final isSelected = index == _selectedScenarioIndex;
              final badgeColor = sc.getBadgeColor();

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedScenarioIndex = index);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? bluePastelBg : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? navyPrimary : borderDefault,
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected ? null : softCardShadow,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          sc.getIcon(),
                          size: 15,
                          color: isSelected ? navyPrimary : badgeColor,
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              sc.title,
                              style: TextStyle(
                                color: isSelected ? navyPrimary : textPrimary,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              ),
                            ),
                            Text(
                              sc.badge,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 12),

        // Detailed AI Solution Analysis Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: navyLight.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge and Projected Reduction
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: selectedScenario.getBadgeBg(),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: selectedScenario.getBadgeColor().withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      selectedScenario.badge,
                      style: TextStyle(
                        color: selectedScenario.getBadgeColor(),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.trending_down_rounded, color: accentTeal, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Proyeksi Reduksi: ~${selectedScenario.projectedRiskReduction.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: accentTeal,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 1. Diagnosa Masalah Pelanggan
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderDefault),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.troubleshoot_rounded, color: accentOrange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Diagnosa Kebutuhan Akun:',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            selectedScenario.diagnosis,
                            style: const TextStyle(
                              color: textSecondary,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 2. Analisa Solusi AI
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: bluePastelBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: navyLight.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_rounded, color: navyPrimary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Analisa Solusi Preskriptif (AI Strategy):',
                            style: TextStyle(
                              color: navyPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            selectedScenario.solutionAnalysis,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Parameter Pills
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _paramPill(Icons.description_outlined, 'Kontrak', formatContractLabel(selectedScenario.targetContract)),
                  _paramPill(Icons.account_balance_wallet_rounded, 'Tagihan', '${formatRupiah(selectedScenario.targetMonthlyCharges)} (${selectedScenario.discountTag})'),
                  _paramPill(Icons.payment_rounded, 'Metode', formatPaymentLabel(selectedScenario.targetPaymentMethod)),
                  _paramPill(Icons.wifi_rounded, 'Internet', formatInternetLabel(selectedScenario.targetInternetService)),
                ],
              ),
              const SizedBox(height: 12),

              // Apply and Simulate Button
              SizedBox(
                width: double.infinity,
                height: 38,
                child: ElevatedButton.icon(
                  onPressed: () => _applyAdaptiveScenario(selectedScenario),
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text(
                    'Terapkan Solusi & Jalankan Simulasi',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navyPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _paramPill(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textSecondary),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: const TextStyle(color: textTertiary, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = _currentCustomer;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header / Baseline Info Card ─────────────────────────────────
          if (customer != null)
            _BaselineCustomerHeader(
              customer: customer,
              onChangeCustomer: () => _openCustomerPickerModal(context),
              onClear: () {
                setState(() => _currentCustomer = null);
                _applyCustomer(null);
                widget.onClearCustomer?.call();
                widget.onCustomerChanged?.call(null);
              },
            )
          else
            _EmptyCustomerHeader(
              onPickCustomer: () => _openCustomerPickerModal(context),
            ),

          const SizedBox(height: 16),

          // ─── Form Container ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      color: accentCyan,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Parameter Simulasi',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Preset Skenario Retensi Instan ──
                _buildPresetsSection(),
                const SizedBox(height: 18),
                const Divider(color: borderMuted, height: 1),
                const SizedBox(height: 16),

                // ── 1. Tenor Slider ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Masa Berlangganan (Tenor)',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: accentCyan.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${_tenure.round()} Bulan',
                        style: const TextStyle(
                          color: accentCyan,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _tenure,
                  min: 1,
                  max: 72,
                  divisions: 71,
                  onChanged: (v) {
                    setState(() => _tenure = v);
                    _triggerRealtimeSimulation();
                  },
                ),

                const SizedBox(height: 14),

                // ── 2. Tagihan Bulanan ──
                const Text(
                  'Tagihan Bulanan (Rp)',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _chargesController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  onChanged: (v) => _triggerRealtimeSimulation(),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: accentCyan,
                      size: 20,
                    ),
                    prefixText: 'Rp ',
                    prefixStyle: const TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    hintText: '1178000',
                    suffixText: '/ bln',
                    suffixStyle: const TextStyle(
                      color: textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── 3. Tipe Kontrak ──
                const Text(
                  'Tipe Kontrak',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: _contractOptions.map((opt) {
                    final selected = _contract == opt['value'];
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _SelectChip(
                          label: opt['label']!,
                          selected: selected,
                          onTap: () {
                            setState(() => _contract = opt['value']!);
                            _triggerRealtimeSimulation();
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // ── 4. Layanan Internet ──
                const Text(
                  'Layanan Internet',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: _internetOptions.map((opt) {
                    final selected = _internet == opt['value'];
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _SelectChip(
                          label: opt['label']!,
                          selected: selected,
                          onTap: () {
                            setState(() => _internet = opt['value']!);
                            _triggerRealtimeSimulation();
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // ── 5. Metode Pembayaran ──
                const Text(
                  'Metode Pembayaran',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: bgTertiary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderDefault),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _payment,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: textSecondary,
                      ),
                      items: _paymentOptions.map((opt) {
                        return DropdownMenuItem<String>(
                          value: opt['value'],
                          child: Text(
                            opt['label']!,
                            style: const TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _payment = v);
                          _triggerRealtimeSimulation();
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Submit Button ──
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _runSimulation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentCyan,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: accentCyan.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bolt_rounded, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Jalankan Simulasi Retensi',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Simulation Result Display ───────────────────────────────────
          if (_result != null) ...[
            const SizedBox(height: 16),
            _SimulationResultCard(
              result: _result!,
              initialCustomer: _currentCustomer,
              simulatedCharges: idrToUsd(double.tryParse(_chargesController.text.trim().replaceAll(RegExp(r'[^0-9.]'), '')) ?? (65.0 * usdToIdrRate)),
              simulatedContract: _contract,
              simulatedInternet: _internet,
              simulatedPayment: _payment,
              onApplyToActionCenter: _createActionFromSimulation,
              onSendWhatsApp: _showSimulatedWhatsAppDialog,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Baseline Customer Header ─────────────────────────────────────────────────
class _BaselineCustomerHeader extends StatelessWidget {
  const _BaselineCustomerHeader({
    required this.customer,
    this.onChangeCustomer,
    this.onClear,
  });

  final ChurnResult customer;
  final VoidCallback? onChangeCustomer;
  final VoidCallback? onClear;

  Color get _riskColor {
    switch (customer.riskLevel) {
      case 'CRITICAL':
        return criticalColor;
      case 'HIGH':
        return highColor;
      default:
        return lowColor;
    }
  }

  Widget _buildTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgTertiary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final churnPct = (customer.churnProbability * 100).toStringAsFixed(1);
    final displayId = customer.customerId.isNotEmpty ? customer.customerId : 'Pelanggan Terpilih';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softCardShadow,
        border: Border.all(color: borderDefault),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Baris 1: Avatar + ID Pelanggan + Basis Simulasi Badge + Badge Risiko ──
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _riskColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: _riskColor.withValues(alpha: 0.35), width: 1.5),
                ),
                child: Center(
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: _riskColor,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayId,
                            style: const TextStyle(
                              color: textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: bluePastelBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: navyLight.withValues(alpha: 0.2)),
                          ),
                          child: const Text(
                            'Basis Simulasi',
                            style: TextStyle(
                              color: navyPrimary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Data acuan sebelum kalkulasi skenario',
                      style: TextStyle(
                        color: textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Badge Risiko Awal Tegas
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _riskColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _riskColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$churnPct%',
                      style: TextStyle(
                        color: _riskColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Risiko Awal',
                      style: TextStyle(
                        color: _riskColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // ── Baris 2: Atribut Akun dalam Format Pill Rapi & Proporsional ──
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildTag(Icons.calendar_today_rounded, 'Tenor: ${customer.tenureMonths} bln'),
              _buildTag(Icons.account_balance_wallet_rounded, '${formatRupiah(customer.monthlyCharges)}/bln'),
              _buildTag(Icons.assignment_outlined, formatContractLabel(customer.contract)),
            ],
          ),

          const SizedBox(height: 10),

          // ── Baris 3: Banner Faktor Risiko Utama ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: bgTertiary.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.flag_rounded, size: 13, color: _riskColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Faktor Risiko Utama: ${customer.topFactor}',
                    style: const TextStyle(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // ── Baris 4: Aksi Ganti Pelanggan & Reset ──
          if (onChangeCustomer != null || onClear != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onChangeCustomer != null)
                  InkWell(
                    onTap: onChangeCustomer,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz_rounded, size: 15, color: navyPrimary),
                          SizedBox(width: 4),
                          Text('Ganti Pelanggan', style: TextStyle(color: navyPrimary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                if (onClear != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onClear,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded, size: 14, color: textSecondary),
                          SizedBox(width: 4),
                          Text('Reset', style: TextStyle(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Empty / Standalone Customer Header ──────────────────────────────────────
class _EmptyCustomerHeader extends StatelessWidget {
  const _EmptyCustomerHeader({
    required this.onPickCustomer,
  });

  final VoidCallback onPickCustomer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: softCardShadow,
        border: Border.all(color: navyLight.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bluePastelBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: navyLight.withValues(alpha: 0.2)),
                ),
                child: const Center(
                  child: Icon(
                    Icons.person_search_rounded,
                    color: navyPrimary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Belum Ada Pelanggan Dipilih',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pilih pelanggan dari daftar pantau untuk memuat data baseline, kalkulasi penurunan churn, dan rekomendasi AI adaptif.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: onPickCustomer,
              icon: const Icon(Icons.person_search_rounded, size: 18),
              label: const Text(
                'Pilih Pelanggan dari Watchlist',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: navyPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Customer Picker Modal Sheet ──────────────────────────────────────────────
class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet({
    required this.onSelect,
    required this.api,
  });

  final ValueChanged<ChurnResult> onSelect;
  final ChurnApi api;

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  late Future<ChurnAlertsResponse> _futureAlerts;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _riskFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _futureAlerts = widget.api.fetchAlerts(limit: 50);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ChurnResult> _filterCustomers(List<ChurnResult> list) {
    var filtered = list;
    if (_riskFilter != 'ALL') {
      filtered = filtered.where((c) => c.riskLevel == _riskFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      filtered = filtered
          .where((c) =>
              c.customerId.toLowerCase().contains(q) ||
              c.contract.toLowerCase().contains(q) ||
              (c.topFactor.toLowerCase().contains(q)))
          .toList();
    }
    return filtered;
  }

  Color _riskColor(String risk) {
    switch (risk) {
      case 'CRITICAL':
        return criticalColor;
      case 'HIGH':
        return highColor;
      default:
        return lowColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: bluePastelBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: navyLight.withValues(alpha: 0.2)),
                  ),
                  child: const Center(
                    child: Icon(Icons.person_search_rounded, color: navyPrimary, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih Pelanggan untuk Simulasi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        'Pilih pelanggan berisiko untuk menerapkan data awal',
                        style: TextStyle(fontSize: 11.5, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20, color: textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Cari ID Pelanggan, Kontrak...',
                prefixIcon: const Icon(Icons.search_rounded, color: navyPrimary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: bgTertiary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Risk Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'Semua'),
                const SizedBox(width: 6),
                _buildFilterChip('CRITICAL', 'Kritis'),
                const SizedBox(width: 6),
                _buildFilterChip('HIGH', 'Tinggi'),
                const SizedBox(width: 6),
                _buildFilterChip('LOW', 'Rendah'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: borderDefault),

          // Customer List
          Expanded(
            child: FutureBuilder<ChurnAlertsResponse>(
              future: _futureAlerts,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: accentCyan),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Gagal memuat data pelanggan:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    ),
                  );
                }

                final rawList = snapshot.data?.data ?? [];
                final list = _filterCustomers(rawList);

                if (list.isEmpty) {
                  return const Center(
                    child: Text(
                      'Tidak ada pelanggan yang cocok dengan pencarian.',
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  physics: const BouncingScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final c = list[index];
                    final color = _riskColor(c.riskLevel);
                    final riskPct = (c.churnProbability * 100).toStringAsFixed(1);

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onSelect(c);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderDefault),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c.customerId,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: color.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '${formatRiskLabel(c.riskLevel)} ($riskPct%)',
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right_rounded, color: textSecondary, size: 18),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  'Tenor: ${c.tenureMonths} bln',
                                  style: const TextStyle(color: textSecondary, fontSize: 12.5),
                                ),
                                const Text(' • ', style: TextStyle(color: borderDefault)),
                                Text(
                                  '${formatRupiah(c.monthlyCharges)}/bln',
                                  style: const TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                                const Text(' • ', style: TextStyle(color: borderDefault)),
                                Flexible(
                                  child: Text(
                                    formatContractLabel(c.contract),
                                    style: const TextStyle(color: textSecondary, fontSize: 12.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (c.topFactor.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Faktor: ${c.topFactor}',
                                style: const TextStyle(color: textTertiary, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String risk, String label) {
    final selected = _riskFilter == risk;
    return GestureDetector(
      onTap: () => setState(() => _riskFilter = risk),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? navyPrimary : bgTertiary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? navyPrimary : borderDefault),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : textSecondary,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── Select Chip ──────────────────────────────────────────────────────────────
class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? accentCyan.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? accentCyan
                : borderDefault,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected ? [
            BoxShadow(
              color: accentCyan.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? accentCyan : textPrimary,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── Simulation Result Card ────────────────────────────────────────────────────
class _SimulationResultCard extends StatelessWidget {
  const _SimulationResultCard({
    required this.result,
    this.initialCustomer,
    required this.simulatedCharges,
    required this.simulatedContract,
    required this.simulatedInternet,
    required this.simulatedPayment,
    required this.onApplyToActionCenter,
    required this.onSendWhatsApp,
  });

  final SimulationResult result;
  final ChurnResult? initialCustomer;
  final double simulatedCharges;
  final String simulatedContract;
  final String simulatedInternet;
  final String simulatedPayment;
  final VoidCallback onApplyToActionCenter;
  final VoidCallback onSendWhatsApp;

  Color get _riskColor {
    switch (result.riskLevel) {
      case 'CRITICAL':
        return criticalColor;
      case 'HIGH':
        return highColor;
      default:
        return lowColor;
    }
  }

  Color get _riskBg {
    switch (result.riskLevel) {
      case 'CRITICAL':
        return criticalBg;
      case 'HIGH':
        return highBg;
      default:
        return lowBg;
    }
  }

  String get _riskLabel {
    switch (result.riskLevel) {
      case 'CRITICAL':
        return 'Kritis';
      case 'HIGH':
        return 'Tinggi';
      default:
        return 'Rendah';
    }
  }

  @override
  Widget build(BuildContext context) {
    final newProbPct = (result.newChurnProbability * 100).toStringAsFixed(1);
    final reduction = result.riskReductionPercentage;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _riskColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _riskColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.insights_rounded,
                    color: accentTeal,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Hasil Simulasi',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _riskBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _riskColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'Risiko $_riskLabel',
                  style: TextStyle(
                    color: _riskColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Stats row
          Row(
            children: [
              // Skor Risiko Baru
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: bgTertiary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Skor Risiko',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$newProbPct%',
                        style: TextStyle(
                          color: _riskColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Penurunan Risiko
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: bgTertiary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reduksi',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reduction > 0 ? '-$reduction%' : '0%',
                        style: const TextStyle(
                          color: accentTeal,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Potensi Customer Setuju (Acceptance Probability)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: result.acceptanceProbability != null
                        ? accentPurple.withValues(alpha: 0.06)
                        : bgTertiary,
                    borderRadius: BorderRadius.circular(10),
                    border: result.acceptanceProbability != null
                        ? Border.all(color: accentPurple.withValues(alpha: 0.2))
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Peluang ACC',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.acceptanceProbability != null
                            ? '${(result.acceptanceProbability! * 100).toStringAsFixed(0)}%'
                            : '-',
                        style: const TextStyle(
                          color: accentPurple,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Progress visual
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: result.newChurnProbability.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: bgTertiary,
              valueColor: AlwaysStoppedAnimation<Color>(_riskColor),
            ),
          ),

          if (initialCustomer != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Risiko Awal: ${(initialCustomer!.churnProbability * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: textSecondary,
                      fontSize: 12.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Simulasi: $newProbPct%',
                  style: TextStyle(
                    color: _riskColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // ── 0. Acceptance Probability Insight Banner ──
          if (result.acceptanceProbability != null) ...[
            _buildAcceptanceInsightBanner(result.acceptanceProbability!),
            const SizedBox(height: 14),
          ],

          // ── 1. Financial Trade-Off / ROI Box ──
          _buildFinancialTradeOffBox(),

          const SizedBox(height: 14),

          // ── 2. AI Recommendation Box ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentCyan.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accentCyan.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_rounded,
                  color: accentOrange,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rekomendasi Tindakan Retensi',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        result.recommendation,
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── 3. Action Bridge Buttons ──
          _buildActionBridgeButtons(),
        ],
      ),
    );
  }

  Widget _buildAcceptanceInsightBanner(double acceptance) {
    final pct = (acceptance * 100).toStringAsFixed(0);
    String label;
    String insight;
    Color bannerColor;
    IconData bannerIcon;

    if (acceptance >= 0.70) {
      label = 'Peluang Tinggi';
      insight = 'Customer sangat mungkin menerima penawaran ini. Segera tindak lanjuti melalui WhatsApp atau telepon.';
      bannerColor = lowColor;
      bannerIcon = Icons.thumb_up_rounded;
    } else if (acceptance >= 0.50) {
      label = 'Peluang Moderat';
      insight = 'Kemungkinan customer menerima cukup baik. Pertimbangkan tambahan insentif kecil untuk meningkatkan daya tarik.';
      bannerColor = accentOrange;
      bannerIcon = Icons.thumbs_up_down_rounded;
    } else {
      label = 'Peluang Rendah';
      insight = 'Customer mungkin keberatan dengan penawaran ini. Coba kurangi agresivitas kontrak atau tambah diskon.';
      bannerColor = highColor;
      bannerIcon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bannerColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bannerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(bannerIcon, color: bannerColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      child: Text(
                        'Peluang Penerimaan Solusi',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: bannerColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '$pct% • $label',
                        style: TextStyle(
                          color: bannerColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  insight,
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialTradeOffBox() {
    final baselineMonthly = initialCustomer?.monthlyCharges ?? (simulatedCharges / 0.85);
    final baselineAnnual = baselineMonthly * 12;
    final simulatedAnnual = simulatedCharges * 12;
    final discountMonthly = (baselineMonthly - simulatedCharges).clamp(0.0, double.infinity);
    final discountAnnual = discountMonthly * 12;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: lowColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: lowBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.monetization_on_rounded, color: lowColor, size: 16),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Analisis Finansial (ROI)',
                  style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: lowBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: lowColor.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'Menguntungkan',
                  style: TextStyle(color: lowColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _finMetricPill(
                  'Biaya Diskon',
                  '-${formatRupiah(discountMonthly)}/bln',
                  '-${formatRupiah(discountAnnual, compact: true)}/thn',
                  accentOrange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _finMetricPill(
                  'Revenue Diamankan',
                  '+${formatRupiah(simulatedCharges)}/bln',
                  '+${formatRupiah(simulatedAnnual, compact: true)}/thn',
                  lowColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Tanpa intervensi, potensi kehilangan 100% pendapatan adalah ${formatRupiah(baselineAnnual, compact: true)}/thn. '
            'Memberikan insentif ini menyelamatkan net cashflow +${formatRupiah(simulatedAnnual, compact: true)}/thn bagi perusahaan.',
            style: const TextStyle(color: textTertiary, fontSize: 12.5, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _finMetricPill(String title, String valMonthly, String valAnnual, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgTertiary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: textSecondary, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            valMonthly,
            style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800),
          ),
          Text(
            valAnnual,
            style: const TextStyle(color: textTertiary, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBridgeButtons() {
    return Column(
      children: [
        if (initialCustomer == null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderDefault),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: textSecondary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pilih pelanggan riil untuk menyimpan tugas atau mengirim draf penawaran WhatsApp.',
                    style: TextStyle(fontSize: 12.5, color: textSecondary),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: onApplyToActionCenter,
                  icon: const Icon(Icons.add_task_rounded, size: 16),
                  label: const Text(
                    'Jadikan Tugas',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: navyPrimary,
                    side: const BorderSide(color: navyPrimary, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: onSendWhatsApp,
                  icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                  label: const Text(
                    'Kirim Penawaran WA',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
