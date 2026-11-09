class ChurnResult {
  final String customerId;
  final int tenureMonths;
  final double monthlyCharges;
  final String contract;
  final String? internetService;
  final String? paymentMethod;
  final double churnProbability;
  final String riskLevel;
  final String topFactor;

  final String? actionStatus;
  final double? baselineChurnProbability;

  const ChurnResult({
    required this.customerId,
    required this.tenureMonths,
    required this.monthlyCharges,
    required this.contract,
    this.internetService,
    this.paymentMethod,
    required this.churnProbability,
    required this.riskLevel,
    required this.topFactor,
    this.actionStatus,
    this.baselineChurnProbability,
  });

  factory ChurnResult.fromJson(Map<String, dynamic> json) {
    return ChurnResult(
      customerId: json['customer_id'] as String,
      tenureMonths: json['tenure_months'] as int,
      monthlyCharges: (json['monthly_charges'] as num).toDouble(),
      contract: json['contract'] as String,
      internetService: json['internet_service'] as String?,
      paymentMethod: json['payment_method'] as String?,
      churnProbability: (json['churn_probability'] as num).toDouble(),
      riskLevel: json['risk_level'] as String,
      topFactor: json['top_factor'] as String,
      actionStatus: json['action_status'] as String?,
      baselineChurnProbability: json['baseline_churn_probability'] != null
          ? (json['baseline_churn_probability'] as num).toDouble()
          : null,
    );
  }
}

class ChurnAlertsResponse {
  final String status;
  final int totalRecords;
  final List<ChurnResult> data;

  const ChurnAlertsResponse({
    required this.status,
    required this.totalRecords,
    required this.data,
  });

  factory ChurnAlertsResponse.fromJson(Map<String, dynamic> json) {
    return ChurnAlertsResponse(
      status: json['status'] as String,
      totalRecords: json['total_records'] as int,
      data: (json['data'] as List<dynamic>)
          .map((item) => ChurnResult.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
