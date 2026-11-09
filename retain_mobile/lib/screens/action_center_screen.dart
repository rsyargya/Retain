import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/retention_action.dart';
import '../services/churn_api.dart';
import '../theme/app_theme.dart';
import '../widgets/customer_shap_sheet.dart';

class ActionCenterScreen extends StatefulWidget {
  const ActionCenterScreen({super.key, this.onStatusChanged});

  final VoidCallback? onStatusChanged;

  @override
  State<ActionCenterScreen> createState() => ActionCenterScreenState();
}

class ActionCenterScreenState extends State<ActionCenterScreen> {
  final ChurnApi _api = ChurnApi();
  late Future<RetentionActionsResponse> _future;
  late Future<RetentionStats> _statsFuture;
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _future = _api.fetchActions();
    _statsFuture = _api.fetchActionStats();
  }

  void refresh() {
    setState(() {
      _future = _api.fetchActions();
      _statsFuture = _api.fetchActionStats();
    });
    widget.onStatusChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPrimary,
      body: FutureBuilder<RetentionActionsResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: accentCyan));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: criticalColor, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Gagal memuat tugas: ${snapshot.error}',
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
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final allActions = snapshot.data?.data ?? [];
          final pendingCount = allActions.where((a) => a.status == 'PENDING').length;
          final inProgressCount = allActions.where((a) => a.status == 'IN_PROGRESS').length;
          final resolvedCount = allActions.where((a) => a.status == 'RESOLVED').length;

          final filtered = _statusFilter == 'ALL'
              ? allActions
              : allActions.where((a) => a.status == _statusFilter).toList();

          return RefreshIndicator(
            color: accentCyan,
            backgroundColor: Colors.white,
            onRefresh: () async => refresh(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // ─── Header ──────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Action Center Hub',
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontSize: 16.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Follow-Up & Penyelamatan MRR',
                                          style: TextStyle(
                                            color: textSecondary,
                                            fontSize: 11,
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
                            const SizedBox(width: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _showCreateActionDialog(context),
                                  tooltip: 'Tambah Tugas',
                                  icon: const Icon(Icons.add_task_rounded, color: navyLight, size: 21),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(),
                                  onPressed: refresh,
                                  tooltip: 'Muat Ulang',
                                  icon: const Icon(Icons.sync_rounded, color: textSecondary, size: 21),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ─── Hero Welcome Banner for Action Center ────────────────
                        Container(
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
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Pusat Eksekusi Retensi',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFF334155)),
                                    ),
                                    child: Text(
                                      '${allActions.length} Tugas Terdaftar',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Eksekusi outreach WhatsApp resmi & pantau pipeline penyelamatan MRR pelanggan realtime.',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: () => _showCreateActionDialog(context),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_task_rounded, size: 14, color: navyPrimary),
                                      SizedBox(width: 6),
                                      Text(
                                        '+ Buat Tugas Manual',
                                        style: TextStyle(
                                          color: navyPrimary,
                                          fontSize: 11.5,
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
                        const SizedBox(height: 16),

                        // ─── ROI & Revenue Saved Tracker Card ───────────────
                        _buildRoiTrackerCard(),

                        // ─── Status Pipeline KPI Cards ──────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _statusKpiBox(
                                'Antrean',
                                '$pendingCount',
                                criticalColor,
                                _statusFilter == 'PENDING',
                                () => setState(() => _statusFilter = 'PENDING'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _statusKpiBox(
                                'Diproses',
                                '$inProgressCount',
                                highColor,
                                _statusFilter == 'IN_PROGRESS',
                                () => setState(() => _statusFilter = 'IN_PROGRESS'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _statusKpiBox(
                                'Selesai',
                                '$resolvedCount',
                                lowColor,
                                _statusFilter == 'RESOLVED',
                                () => setState(() => _statusFilter = 'RESOLVED'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ─── Filter Chips ───────────────────────────────────
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _filterChip('Semua (${allActions.length})', 'ALL'),
                              const SizedBox(width: 6),
                              _filterChip('Butuh Tindakan ($pendingCount)', 'PENDING'),
                              const SizedBox(width: 6),
                              _filterChip('Sedang Diproses ($inProgressCount)', 'IN_PROGRESS'),
                              const SizedBox(width: 6),
                              _filterChip('Terselamatkan ($resolvedCount)', 'RESOLVED'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daftar Tugas (${filtered.length})',
                              style: const TextStyle(
                                color: textPrimary,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Nomor WhatsApp & profil terhubung otomatis',
                              style: TextStyle(color: textTertiary, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── Task List ─────────────────────────────────────────────
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
                              decoration: const BoxDecoration(
                                color: bgTertiary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.done_all_rounded,
                                color: accentTeal,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Tidak ada tugas pada filter ini',
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Semua intervensi telah ditangani dengan baik.',
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
                            child: _ActionCard(
                              item: item,
                              onUpdateStatus: (newStatus) => _handleUpdateStatus(item.id, newStatus),
                              onOpenWhatsApp: () => _showWhatsAppDialog(context, item),
                              onViewDetail: () => _showCustomerDetailDialog(context, item),
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
        },
      ),
    );
  }

  Widget _statusKpiBox(String title, String count, Color color, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : borderDefault,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : softCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? color : textSecondary,
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              count,
              style: TextStyle(
                color: isSelected ? color : textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String filterKey) {
    final selected = _statusFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accentCyan.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accentCyan : borderDefault,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accentCyan : textSecondary,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdateStatus(int id, String newStatus) async {
    try {
      await _api.updateActionStatus(actionId: id, status: newStatus);
      refresh();
      widget.onStatusChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status berhasil diubah ke: $newStatus'),
          backgroundColor: bgCard,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengubah status: $e'), backgroundColor: criticalColor),
      );
    }
  }

  void _showWhatsAppDialog(BuildContext context, RetentionActionItem item) {
    final draftMessage =
        'Halo Bapak/Ibu Pelanggan ID ${item.customerId},\n\n'
        'Kami dari Tim Layanan Pelanggan. Kami memiliki penawaran eksklusif retensi khusus hari ini: '
        '${item.title}.\n\n'
        'Dapatkan diskon spesial biaya bulanan dan jaminan stabilitas layanan dengan membalas pesan ini. Terima kasih! 🙏';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Kirim Penawaran WhatsApp',
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
                // Phone number box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.phone_rounded, color: Color(0xFF25D366), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${item.phoneNumber} (Dummy)',
                                style: const TextStyle(
                                  color: textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Salin Nomor',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.copy_rounded, color: Color(0xFF25D366), size: 16),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: item.phoneNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nomor WA dummy berhasil disalin!'),
                              backgroundColor: Color(0xFF25D366),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: bgTertiary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderDefault),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 13, color: textSecondary),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Nomor dummy simulasi demonstrasi. Pesan siap disalin atau diuji tanpa menghubungi nomor pribadi.',
                          style: TextStyle(color: textSecondary, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Draf Pesan Resmi:',
                  style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgPrimary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderDefault),
                  ),
                  child: Text(
                    draftMessage,
                    style: const TextStyle(color: textPrimary, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup', style: TextStyle(color: textSecondary)),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: draftMessage));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Draf chat berhasil disalin ke clipboard!'),
                    backgroundColor: Color(0xFF25D366),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 15),
              label: const Text('Salin Draf'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF25D366),
                side: const BorderSide(color: Color(0xFF25D366)),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                final cleanPhone = item.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
                final uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(draftMessage)}');
                try {
                  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (!launched) {
                    await launchUrl(uri, mode: LaunchMode.platformDefault);
                  }
                } catch (e) {
                  Clipboard.setData(ClipboardData(text: draftMessage));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tidak dapat membuka WA langsung. Draf telah disalin ($e)'),
                      backgroundColor: highColor,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              label: const Text('Buka WA Langsung', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCustomerDetailDialog(BuildContext context, RetentionActionItem item) {
    CustomerShapSheet.show(
      context,
      customerId: item.customerId,
      phoneNumber: item.phoneNumber,
      tenureMonths: item.tenureMonths,
      monthlyCharges: item.monthlyCharges,
      contract: item.contract,
      internetService: item.internetService,
      onActionUpdated: refresh,
    );
  }

  Widget _buildRoiTrackerCard() {
    return FutureBuilder<RetentionStats>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final stats = snapshot.data ?? RetentionStats.empty();
        if (stats.totalActions == 0) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: lowBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.savings_rounded,
                            color: lowColor,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Dampak Finansial & ROI',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: lowBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: lowColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${stats.successRate.toStringAsFixed(1)}% Berhasil',
                      style: const TextStyle(
                        color: lowColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pendapatan Terselamatkan:',
                        style: TextStyle(color: textSecondary, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatRupiah(stats.revenueSavedMonthly)} / bln',
                        style: const TextStyle(
                          color: lowColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Estimasi Tahunan:',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatRupiah(stats.revenueSavedAnnual, compact: true)} / thn',
                        style: const TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: stats.totalActions > 0 ? (stats.resolvedCount / stats.totalActions) : 0,
                  minHeight: 6,
                  backgroundColor: bgTertiary,
                  valueColor: const AlwaysStoppedAnimation<Color>(lowColor),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${stats.resolvedCount} dari ${stats.totalActions} pelanggan terselamatkan',
                      style: const TextStyle(color: textTertiary, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Berisiko: ${formatRupiah(stats.revenueAtRisk)}/bln',
                    style: const TextStyle(color: criticalColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () {
                  final report =
                      '📊 LAPORAN KINERJA TIM RETENSI (RETAIN HUB)\n'
                      '• Total Akun Ditangani: ${stats.totalActions} Pelanggan\n'
                      '• Berhasil Diselamatkan (Resolved): ${stats.resolvedCount} Akun (${stats.successRate.toStringAsFixed(1)}%)\n'
                      '• Sedang Diproses / Pending: ${stats.inProgressCount} Diproses, ${stats.pendingCount} Pending\n'
                      '• Total MRR Diselamatkan: ${formatRupiah(stats.revenueSavedMonthly)}/bln (${formatRupiah(stats.revenueSavedAnnual)}/thn)\n'
                      '• Sisa Revenue at Risk: ${formatRupiah(stats.revenueAtRisk)}/bln';
                  Clipboard.setData(ClipboardData(text: report));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Laporan ringkasan ROI berhasil disalin! Siap dikirim ke Supervisor.'),
                      backgroundColor: lowColor,
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: lowColor.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: lowColor.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.copy_all_rounded, size: 14, color: lowColor),
                      SizedBox(width: 6),
                      Text(
                        'Salin Laporan ROI Retensi',
                        style: TextStyle(
                          color: lowColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateActionDialog(BuildContext context) {
    final custController = TextEditingController();
    final titleController = TextEditingController(text: 'Tawarkan Kontrak 1 Tahun + Diskon 15%');
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Buat Tugas Retensi Baru',
            style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: custController,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'ID Pelanggan (e.g. 7590-VHVEG)',
                    hintText: 'Masukkan customer ID',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Judul Tindakan Retensi',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Catatan Tim (Opsional)',
                    hintText: 'Contoh: Pelanggan sensitif harga',
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
                final custId = custController.text.trim();
                final title = titleController.text.trim();
                if (custId.isEmpty || title.isEmpty) return;

                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                try {
                  await _api.createAction(
                    customerId: custId,
                    title: title,
                    note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                  );
                  refresh();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Tugas baru berhasil ditambahkan!'),
                      backgroundColor: accentTeal,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Gagal menambah tugas: $e'), backgroundColor: criticalColor),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: accentCyan, foregroundColor: Colors.white),
              child: const Text('Simpan Tugas', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.item,
    required this.onUpdateStatus,
    required this.onOpenWhatsApp,
    required this.onViewDetail,
  });

  final RetentionActionItem item;
  final ValueChanged<String> onUpdateStatus;
  final VoidCallback onOpenWhatsApp;
  final VoidCallback onViewDetail;

  Color get _statusColor {
    switch (item.status) {
      case 'PENDING':
        return criticalColor;
      case 'IN_PROGRESS':
        return highColor;
      default:
        return lowColor;
    }
  }

  String get _statusLabel {
    switch (item.status) {
      case 'PENDING':
        return 'Butuh Tindakan';
      case 'IN_PROGRESS':
        return 'Sedang Diproses';
      default:
        return 'Terselamatkan';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: softCardShadow,
        border: Border.all(color: borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar + Customer ID & Status Pill
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: _statusColor.withValues(alpha: 0.35), width: 1.5),
                ),
                child: Center(
                  child: Icon(
                    Icons.assignment_ind_rounded,
                    color: _statusColor,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.customerId,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: onUpdateStatus,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'PENDING', child: Text('🔴 Butuh Tindakan (Pending)', style: TextStyle(color: textPrimary, fontSize: 13))),
                  const PopupMenuItem(value: 'IN_PROGRESS', child: Text('🟡 Sedang Diproses (In Progress)', style: TextStyle(color: textPrimary, fontSize: 13))),
                  const PopupMenuItem(value: 'RESOLVED', child: Text('🟢 Terselamatkan (Resolved)', style: TextStyle(color: textPrimary, fontSize: 13))),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _statusLabel,
                        style: TextStyle(
                          color: _statusColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: _statusColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Action Title
          Text(
            item.title,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),

          // Phone Number Pill + Contract Info
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone_rounded, color: Color(0xFF25D366), size: 12),
                    const SizedBox(width: 5),
                    Text(
                      '${item.phoneNumber} (Dummy)',
                      style: const TextStyle(
                        color: Color(0xFF25D366),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.monthlyCharges != null)
                Text(
                  '${formatRupiah(item.monthlyCharges)}/bln',
                  style: const TextStyle(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              if (item.contract != null)
                Text(
                  '• ${formatContractLabel(item.contract)}',
                  style: const TextStyle(color: textTertiary, fontSize: 11),
                ),
            ],
          ),

          if (item.note != null && item.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: bgTertiary.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item.note!,
                style: const TextStyle(color: textSecondary, fontSize: 11, height: 1.3),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Bottom Action Row: Detail + WhatsApp Button
          Row(
            children: [
              Expanded(
                flex: 1,
                child: InkWell(
                  onTap: onViewDetail,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: bgTertiary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderDefault),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.badge_rounded, size: 15, color: textPrimary),
                        SizedBox(width: 5),
                        Text(
                          'Profil',
                          style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onOpenWhatsApp,
                  icon: const Icon(Icons.chat_rounded, size: 15),
                  label: const Text(
                    'Kirim WA Promo',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
