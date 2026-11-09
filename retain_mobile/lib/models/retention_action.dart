class RetentionActionItem {
  final int id;
  final String customerId;
  final String phoneNumber;
  final String actionType;
  final String title;
  final String status;
  final String? note;
  final String? createdAt;
  final int? tenureMonths;
  final double? monthlyCharges;
  final String? contract;
  final String? internetService;

  const RetentionActionItem({
    required this.id,
    required this.customerId,
    required this.phoneNumber,
    required this.actionType,
    required this.title,
    required this.status,
    this.note,
    this.createdAt,
    this.tenureMonths,
    this.monthlyCharges,
    this.contract,
    this.internetService,
  });

  factory RetentionActionItem.fromJson(Map<String, dynamic> json) {
    return RetentionActionItem(
      id: (json['id'] as num).toInt(),
      customerId: json['customer_id'] as String,
      phoneNumber: json['phone_number'] as String? ?? '+6280000000000',
      actionType: json['action_type'] as String? ?? 'OFFER_DISCOUNT',
      title: json['title'] as String? ?? 'Tindakan Retensi',
      status: json['status'] as String? ?? 'PENDING',
      note: json['note'] as String?,
      createdAt: json['created_at'] as String?,
      tenureMonths: (json['tenure_months'] as num?)?.toInt(),
      monthlyCharges: (json['monthly_charges'] as num?)?.toDouble(),
      contract: json['contract'] as String?,
      internetService: json['internet_service'] as String?,
    );
  }
}


class RetentionActionsResponse {
  final String status;
  final int totalRecords;
  final List<RetentionActionItem> data;

  const RetentionActionsResponse({
    required this.status,
    required this.totalRecords,
    required this.data,
  });

  factory RetentionActionsResponse.fromJson(Map<String, dynamic> json) {
    return RetentionActionsResponse(
      status: json['status'] as String? ?? 'success',
      totalRecords: (json['total_records'] as num?)?.toInt() ?? 0,
      data: (json['data'] as List<dynamic>? ?? [])
          .map((e) => RetentionActionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RetentionStats {
  final int totalActions;
  final int pendingCount;
  final int inProgressCount;
  final int resolvedCount;
  final double successRate;
  final double revenueSavedMonthly;
  final double revenueSavedAnnual;
  final double revenueAtRisk;

  const RetentionStats({
    required this.totalActions,
    required this.pendingCount,
    required this.inProgressCount,
    required this.resolvedCount,
    required this.successRate,
    required this.revenueSavedMonthly,
    required this.revenueSavedAnnual,
    required this.revenueAtRisk,
  });

  factory RetentionStats.fromJson(Map<String, dynamic> json) {
    return RetentionStats(
      totalActions: (json['total_actions'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      inProgressCount: (json['in_progress_count'] as num?)?.toInt() ?? 0,
      resolvedCount: (json['resolved_count'] as num?)?.toInt() ?? 0,
      successRate: (json['success_rate'] as num?)?.toDouble() ?? 0.0,
      revenueSavedMonthly: (json['revenue_saved_monthly'] as num?)?.toDouble() ?? 0.0,
      revenueSavedAnnual: (json['revenue_saved_annual'] as num?)?.toDouble() ?? 0.0,
      revenueAtRisk: (json['revenue_at_risk'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory RetentionStats.empty() {
    return const RetentionStats(
      totalActions: 0,
      pendingCount: 0,
      inProgressCount: 0,
      resolvedCount: 0,
      successRate: 0.0,
      revenueSavedMonthly: 0.0,
      revenueSavedAnnual: 0.0,
      revenueAtRisk: 0.0,
    );
  }
}
