import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/churn_result.dart';
import '../models/retention_action.dart';
import '../services/churn_api.dart';
import '../theme/app_theme.dart';
import '../widgets/customer_shap_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.onSelectCustomer,
    this.onNavigateToActionCenter,
    this.onActionCreated,
  });

  final void Function(ChurnResult customer) onSelectCustomer;
  final VoidCallback? onNavigateToActionCenter;
  final VoidCallback? onActionCreated;

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final ChurnApi _api = ChurnApi();
  late Future<ChurnAlertsResponse> _future;
  String _searchQuery = '';
  String _riskFilter = 'ALL';
  String _sortBy = 'RISK_DESC';
  Map<String, String> _customerActionStatus = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<ChurnAlertsResponse> _fetchData() async {
    final results = await Future.wait([
      _api.fetchAlerts(limit: 50),
      _api.fetchActions(),
    ]);
    final alertsResp = results[0] as ChurnAlertsResponse;
    final actionsResp = results[1] as RetentionActionsResponse;
    final statusMap = {
      for (final a in actionsResp.data) a.customerId: a.status
    };
    if (mounted) {
      setState(() {
        _customerActionStatus = statusMap;
      });
    } else {
      _customerActionStatus = statusMap;
    }
    return alertsResp;
  }

  void refresh() {
    setState(() {
      _future = _fetchData();
    });
  }

  void _onTaskCreated(String customerId, String status) {
    setState(() {
      _customerActionStatus[customerId] = status;
    });
    widget.onActionCreated?.call();
  }


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChurnAlertsResponse>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: accentCyan),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, color: criticalColor, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Gagal memuat data pelanggan:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Coba Lagi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentCyan,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final alerts = snapshot.data?.data ?? [];
        return _DashboardView(
          alerts: alerts,
          onRefresh: refresh,
          searchQuery: _searchQuery,
          riskFilter: _riskFilter,
          sortBy: _sortBy,
          customerActionStatus: _customerActionStatus,
          searchController: _searchController,
          onSearchChanged: (v) => setState(() => _searchQuery = v),
          onRiskFilterChanged: (v) => setState(() => _riskFilter = v),
          onSortChanged: (v) => setState(() => _sortBy = v),
          onSelectCustomer: widget.onSelectCustomer,
          onTaskCreated: _onTaskCreated,
          onNavigateToActionCenter: widget.onNavigateToActionCenter,
          onActionCreated: widget.onActionCreated,
        );
      },
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView({
    required this.alerts,
    required this.onRefresh,
    required this.searchQuery,
    required this.riskFilter,
    required this.sortBy,
    required this.customerActionStatus,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRiskFilterChanged,
    required this.onSortChanged,
    required this.onSelectCustomer,
    required this.onTaskCreated,
    this.onNavigateToActionCenter,
    this.onActionCreated,
  });

  final List<ChurnResult> alerts;
  final VoidCallback onRefresh;
  final String searchQuery;
  final String riskFilter;
  final String sortBy;
  final Map<String, String> customerActionStatus;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onRiskFilterChanged;
  final ValueChanged<String> onSortChanged;
  final void Function(ChurnResult) onSelectCustomer;
  final void Function(String customerId, String status) onTaskCreated;
  final VoidCallback? onNavigateToActionCenter;
  final VoidCallback? onActionCreated;

  bool _isSaved(ChurnResult a) {
    return (customerActionStatus[a.customerId] == 'RESOLVED') || (a.actionStatus == 'RESOLVED');
  }

  String _effectiveRisk(ChurnResult a) {
    if (_isSaved(a)) return 'LOW';
    return a.riskLevel;
  }

  double _effectiveProb(ChurnResult a) {
    if (_isSaved(a)) return 0.05;
    return a.churnProbability;
  }

  int get _criticalCount => alerts.where((a) => _effectiveRisk(a) == 'CRITICAL').length;
  int get _highCount => alerts.where((a) => _effectiveRisk(a) == 'HIGH').length;
  int get _lowCount => alerts.where((a) => _effectiveRisk(a) == 'LOW').length;

  double get _revenueAtRisk {
    return alerts
        .where((a) {
          final r = _effectiveRisk(a);
          return r == 'CRITICAL' || r == 'HIGH';
        })
        .fold(0.0, (acc, item) => acc + item.monthlyCharges);
  }

  List<ChurnResult> get _filteredAlerts {
    var list = alerts.toList();
    if (riskFilter != 'ALL') {
      list = list.where((a) => _effectiveRisk(a) == riskFilter).toList();
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list
          .where((a) =>
              a.customerId.toLowerCase().contains(q) ||
              a.contract.toLowerCase().contains(q) ||
              a.topFactor.toLowerCase().contains(q))
          .toList();
    }
    switch (sortBy) {
      case 'BILL_DESC':
        list.sort((a, b) => b.monthlyCharges.compareTo(a.monthlyCharges));
        break;
      case 'TENURE_ASC':
        list.sort((a, b) => a.tenureMonths.compareTo(b.tenureMonths));
        break;
      case 'RISK_DESC':
      default:
        list.sort((a, b) => _effectiveProb(b).compareTo(_effectiveProb(a)));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAlerts;

    return RefreshIndicator(
      color: accentCyan,
      backgroundColor: Colors.white,
      onRefresh: () async => onRefresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // ─── Flowing Portal Header & Hero Banner ──────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Brand Bar
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderDefault),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/splash/splash_logo.png',
                                  width: 24,
                                  height: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Retain Enterprise Hub',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          color: accentTeal,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      const Expanded(
                                        child: Text(
                                          'Prediksi Aktif • Real-Time',
                                          style: TextStyle(
                                            color: textSecondary,
                                            fontSize: 11,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        onPressed: onRefresh,
                        tooltip: 'Muat Ulang',
                        icon: const Icon(Icons.sync_rounded, color: textSecondary, size: 21),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ─── Hero Welcome Banner (Deep Slate Obsidian) ────────────
                  _buildHeroWelcomeBanner(context),
                  const SizedBox(height: 16),

                  // ─── Flowing Service Highlight Cards (Reference Style) ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Ringkasan Intelijen Retensi',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${alerts.length} pelanggan terpantau',
                        style: const TextStyle(
                          color: textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildServiceHighlightCards(context),
                  const SizedBox(height: 16),

                  // ─── Interactive Risk Donut Chart ────────────────────────
                  _buildDonutChartCard(),
                  const SizedBox(height: 16),

                  // ─── Search Bar & Quick Filter Chips ─────────────────────
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderDefault),
                      boxShadow: softCardShadow,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            style: const TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Cari ID pelanggan, kontrak, atau faktor risiko...',
                              hintStyle: TextStyle(
                                color: textTertiary,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                              fillColor: Colors.transparent,
                            ),
                            onChanged: onSearchChanged,
                          ),
                        ),
                        if (searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Quick Filter Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _quickFilterChip('Semua (${alerts.length})', 'ALL', navyPrimary),
                        const SizedBox(width: 8),
                        _quickFilterChip('Kritis ($_criticalCount)', 'CRITICAL', criticalColor),
                        const SizedBox(width: 8),
                        _quickFilterChip('Tinggi ($_highCount)', 'HIGH', highColor),
                        const SizedBox(width: 8),
                        _quickFilterChip('Rendah ($_lowCount)', 'LOW', lowColor),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Daftar Pantau (${filtered.length})',
                          style: const TextStyle(
                            color: textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        initialValue: sortBy,
                        onSelected: onSortChanged,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        color: Colors.white,
                        elevation: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderDefault),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sort_rounded, size: 14, color: navyPrimary),
                              const SizedBox(width: 4),
                              Text(
                                sortBy == 'BILL_DESC'
                                    ? 'Tagihan'
                                    : sortBy == 'TENURE_ASC'
                                        ? 'Tenor'
                                        : 'Risiko',
                                style: const TextStyle(
                                  color: textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: textSecondary),
                            ],
                          ),
                        ),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'RISK_DESC',
                            child: Row(
                              children: [
                                Icon(Icons.local_fire_department_rounded, size: 15, color: criticalColor),
                                SizedBox(width: 8),
                                Text('Risiko Tertinggi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'BILL_DESC',
                            child: Row(
                              children: [
                                Icon(Icons.attach_money_rounded, size: 15, color: accentOrange),
                                SizedBox(width: 8),
                                Text('Tagihan Terbesar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'TENURE_ASC',
                            child: Row(
                              children: [
                                Icon(Icons.hourglass_bottom_rounded, size: 15, color: navyLight),
                                SizedBox(width: 8),
                                Text('Tenor Terendah', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ─── Customer Card List ──────────────────────────────────────────────
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: bgTertiary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.search_off_rounded,
                          color: textSecondary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tidak ada pelanggan yang cocok',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Coba ubah kata kunci atau ganti filter risiko',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = filtered[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CustomerCard(
                        customer: item,
                        actionStatus: customerActionStatus[item.customerId],
                        onTapCard: () => _showCustomerDetailModal(context, item),
                        onTapSimulate: () => onSelectCustomer(item),
                      ),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  Widget _quickFilterChip(String label, String filterKey, Color activeColor) {
    final isSelected = riskFilter == filterKey;
    return GestureDetector(
      onTap: () => onRiskFilterChanged(filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : borderDefault,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : softCardShadow,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroWelcomeBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Solid Deep Obsidian
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: heroBannerShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Pusat Intelijen Retensi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: accentTeal,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Monitoring Prediktif • ${alerts.length} Akun Terdaftar',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InkWell(
                onTap: () => onRiskFilterChanged('CRITICAL'),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: criticalColor),
                      const SizedBox(width: 6),
                      Text(
                        'Fokus Kritis ($_criticalCount)',
                        style: const TextStyle(
                          color: criticalColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: onRefresh,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync_rounded, size: 15, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Refresh',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceHighlightCards(BuildContext context) {
    final criticalRate = alerts.isNotEmpty
        ? (_criticalCount / alerts.length * 100).toStringAsFixed(1)
        : '0';

    return FutureBuilder<RetentionStats>(
      future: ChurnApi().fetchActionStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        final hasSaved = stats != null && stats.revenueSavedMonthly > 0;

        final cards = [
          _HighlightServiceCard(
            icon: Icons.trending_down_rounded,
            iconColor: criticalColor,
            iconBg: rosePastelBg,
            title: 'Potensi Pendapatan Hilang',
            subtitle: 'Potensi churn akun bernilai tinggi yang butuh intervensi.',
            primaryMetric: formatRupiah(_revenueAtRisk, compact: true),
            metricUnit: '/bulan',
            badgeText: '$criticalRate% Kritis',
            badgeColor: criticalColor,
            badgeBg: criticalBg,
            buttonText: 'Filter Kritis ($_criticalCount)',
            onTapButton: () => onRiskFilterChanged('CRITICAL'),
          ),
          _HighlightServiceCard(
            icon: Icons.savings_rounded,
            iconColor: lowColor,
            iconBg: emeraldPastelBg,
            title: 'Pendapatan Diselamatkan',
            subtitle: 'Nilai MRR terlindungi melalui persetujuan paket retensi.',
            primaryMetric: hasSaved ? formatRupiah(stats.revenueSavedMonthly, compact: true) : 'Rp 0',
            metricUnit: '/bulan',
            badgeText: hasSaved ? '${stats.successRate.toStringAsFixed(0)}% Berhasil' : '0% Berhasil',
            badgeColor: lowColor,
            badgeBg: lowBg,
            buttonText: 'Buka Pusat Aksi',
            onTapButton: onNavigateToActionCenter,
          ),
          _HighlightServiceCard(
            icon: Icons.tune_rounded,
            iconColor: navyLight,
            iconBg: bluePastelBg,
            title: 'Simulasi What-If',
            subtitle: 'Kalkulasi peluang retensi & margin sebelum penawaran.',
            primaryMetric: 'Simulasi Retensi',
            metricUnit: 'Interaktif',
            badgeText: 'Preskriptif',
            badgeColor: navyPrimary,
            badgeBg: bluePastelBg,
            buttonText: 'Buka Simulator',
            onTapButton: () {
              if (alerts.isNotEmpty) {
                onSelectCustomer(alerts.first);
              }
            },
          ),
        ];

        return SizedBox(
          height: 215,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => SizedBox(
              width: 275,
              child: cards[index],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDonutChartCard() {
    final total = alerts.length;
    if (total == 0) return const SizedBox.shrink();

    final critVal = _criticalCount.toDouble();
    final highVal = _highCount.toDouble();
    final lowVal = _lowCount.toDouble();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderDefault),
        boxShadow: softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sebaran Tingkat Risiko Pelanggan',
            style: TextStyle(
              color: textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Donut Chart
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 32,
                        sections: [
                          if (critVal > 0)
                            PieChartSectionData(
                              color: criticalColor,
                              value: critVal,
                              title: '',
                              radius: riskFilter == 'CRITICAL' ? 20 : 16,
                            ),
                          if (highVal > 0)
                            PieChartSectionData(
                              color: highColor,
                              value: highVal,
                              title: '',
                              radius: riskFilter == 'HIGH' ? 20 : 16,
                            ),
                          if (lowVal > 0)
                            PieChartSectionData(
                              color: lowColor,
                              value: lowVal,
                              title: '',
                              radius: riskFilter == 'LOW' ? 20 : 16,
                            ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(
                            color: textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'Total',
                          style: TextStyle(color: textTertiary, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),

              // Interactive Legend Pills
              Expanded(
                child: Column(
                  children: [
                    _legendItem('Kritis', _criticalCount, criticalColor, 'CRITICAL'),
                    const SizedBox(height: 6),
                    _legendItem('Tinggi', _highCount, highColor, 'HIGH'),
                    const SizedBox(height: 6),
                    _legendItem('Rendah', _lowCount, lowColor, 'LOW'),
                    const SizedBox(height: 6),
                    _legendItem('Semua', total, accentCyan, 'ALL'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, int count, Color color, String filterKey) {
    final isSelected = riskFilter == filterKey;
    final total = alerts.length;
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';

    return GestureDetector(
      onTap: () => onRiskFilterChanged(filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : borderDefault,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? color : textSecondary,
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text(
              filterKey == 'ALL' ? '$count unit' : '$count ($pct%)',
              style: TextStyle(
                color: isSelected ? color : textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }



  void _showCustomerDetailModal(BuildContext context, ChurnResult c) {
    final cleanPhone = '+62800${c.customerId.replaceAll(RegExp(r'[^0-9]'), '').padRight(8, '0').substring(0, 8)}';
    final isSaved = _isSaved(c);
    CustomerShapSheet.show(
      context,
      customerId: c.customerId,
      phoneNumber: cleanPhone,
      churnProbability: isSaved ? 0.05 : c.churnProbability,
      riskLevel: isSaved ? 'LOW' : c.riskLevel,
      tenureMonths: c.tenureMonths,
      monthlyCharges: c.monthlyCharges,
      contract: c.contract,
      onSimulate: () => onSelectCustomer(c),
      onAddToActions: () => _createQuickTask(context, c),
      onActionUpdated: () {
        onActionCreated?.call();
        onRefresh();
      },
    );
  }

  void _createQuickTask(BuildContext context, ChurnResult c) async {
    try {
      final api = ChurnApi();
      await api.createAction(
        customerId: c.customerId,
        actionType: c.contract == 'Month-to-month' ? 'UPGRADE_CONTRACT' : 'OFFER_DISCOUNT',
        title: 'Follow-up Retensi: ${c.topFactor}',
        note: 'Prioritas ${formatRiskLabel(c.riskLevel)} (${(c.churnProbability * 100).toStringAsFixed(1)}%). Tagihan ${formatRupiah(c.monthlyCharges)}/bln.',
      );
      onTaskCreated(c.customerId, 'PENDING');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tugas untuk ${c.customerId} ditambahkan ke Action Center!'),
          backgroundColor: accentTeal,
          duration: const Duration(seconds: 4),
          action: onNavigateToActionCenter != null
              ? SnackBarAction(
                  label: 'Lihat',
                  textColor: Colors.white,
                  onPressed: () {
                    onNavigateToActionCenter?.call();
                  },
                )
              : null,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat tugas: $e'), backgroundColor: criticalColor),
      );
    }
  }
}

class _HighlightServiceCard extends StatelessWidget {
  const _HighlightServiceCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.primaryMetric,
    required this.metricUnit,
    required this.badgeText,
    required this.badgeColor,
    required this.badgeBg,
    required this.buttonText,
    this.onTapButton,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String primaryMetric;
  final String metricUnit;
  final String badgeText;
  final Color badgeColor;
  final Color badgeBg;
  final String buttonText;
  final VoidCallback? onTapButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: softCardShadow,
        border: Border.all(color: borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 20),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    primaryMetric,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    metricUnit,
                    style: const TextStyle(
                      color: textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          InkWell(
            onTap: onTapButton,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: bgTertiary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderDefault),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    buttonText,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: textPrimary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.onTapCard,
    required this.onTapSimulate,
    this.actionStatus,
  });

  final ChurnResult customer;
  final VoidCallback onTapCard;
  final VoidCallback onTapSimulate;
  final String? actionStatus;

  String? get _effectiveActionStatus => actionStatus ?? customer.actionStatus;
  bool get _isResolved => _effectiveActionStatus == 'RESOLVED';

  Widget _buildStatusBadge(double? baselineProb) {
    final status = _effectiveActionStatus;
    if (status == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: bgTertiary,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderDefault),
        ),
        child: const Text(
          '⚪ Belum Ada Tugas',
          style: TextStyle(
            color: textTertiary,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    Color color;
    Color bg;
    Color border;
    String text;

    switch (status) {
      case 'RESOLVED':
        color = lowColor;
        bg = lowBg;
        border = lowColor.withValues(alpha: 0.35);
        if (baselineProb != null && baselineProb > 0.05) {
          text = '🟢 Terselamatkan • Turun dari ${(baselineProb * 100).toStringAsFixed(1)}%';
        } else {
          text = '🟢 Terselamatkan';
        }
        break;
      case 'IN_PROGRESS':
        color = highColor;
        bg = highBg;
        border = highColor.withValues(alpha: 0.35);
        text = '🟠 Sedang Diproses';
        break;
      case 'PENDING':
      default:
        color = criticalColor;
        bg = criticalBg;
        border = criticalColor.withValues(alpha: 0.35);
        text = '🔴 Butuh Tindakan';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final isResolved = _isResolved;
    final baselineProb = c.baselineChurnProbability ?? (c.churnProbability > 0.05 ? c.churnProbability : 0.652);
    final effectiveProb = isResolved ? 0.05 : c.churnProbability;
    final churnPct = (effectiveProb * 100).toStringAsFixed(1);

    Color riskColor;
    Color riskBg;
    Color avatarBg;
    String riskText;

    if (isResolved) {
      riskColor = lowColor;
      riskBg = lowBg;
      avatarBg = emeraldPastelBg;
      riskText = 'Rendah';
    } else {
      switch (c.riskLevel) {
        case 'CRITICAL':
          riskColor = criticalColor;
          riskBg = criticalBg;
          avatarBg = rosePastelBg;
          riskText = 'Kritis';
          break;
        case 'HIGH':
          riskColor = highColor;
          riskBg = highBg;
          avatarBg = amberPastelBg;
          riskText = 'Tinggi';
          break;
        default:
          riskColor = lowColor;
          riskBg = lowBg;
          avatarBg = emeraldPastelBg;
          riskText = 'Rendah';
      }
    }

    return GestureDetector(
      onTap: onTapCard,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: softCardShadow,
          border: Border.all(
            color: isResolved
                ? lowColor.withValues(alpha: 0.35)
                : (c.riskLevel == 'CRITICAL'
                    ? criticalColor.withValues(alpha: 0.25)
                    : borderDefault),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Customer ID & Contract + Churn Risk Pill Badge
            Row(
              children: [
                // Clean Customer Avatar Circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: riskColor.withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: Center(
                    child: Icon(
                      isResolved ? Icons.verified_user_rounded : Icons.person_outline_rounded,
                      color: riskColor,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.customerId,
                              style: const TextStyle(
                                color: textPrimary,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: bgTertiary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${c.tenureMonths} bln',
                              style: const TextStyle(
                                color: textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${formatContractLabel(c.contract)} • ${formatRupiah(c.monthlyCharges)}/bln',
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 12.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      _buildStatusBadge(baselineProb),
                    ],
                  ),
                ),
                // Churn Risk Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: riskBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: riskColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$churnPct%',
                        style: TextStyle(
                          color: riskColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        riskText,
                        style: TextStyle(
                          color: riskColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Top Factor Pill Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isResolved ? lowBg.withValues(alpha: 0.5) : bgTertiary.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
                border: isResolved ? Border.all(color: lowColor.withValues(alpha: 0.25)) : null,
              ),
              child: Row(
                children: [
                  Icon(
                    isResolved ? Icons.verified_rounded : Icons.insights_rounded,
                    size: 15,
                    color: isResolved ? lowColor : riskColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isResolved
                          ? 'Intervensi Berhasil: Risiko Churn Terkendali (Aman)'
                          : 'Faktor Utama: ${c.topFactor}',
                      style: TextStyle(
                        color: isResolved ? lowColor : textSecondary,
                        fontSize: 12.5,
                        fontWeight: isResolved ? FontWeight.w700 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Bottom CTA Pill Row
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tagihan: ${formatRupiah(c.monthlyCharges)}',
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onTapSimulate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: navyPrimary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Simulasi Retensi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
