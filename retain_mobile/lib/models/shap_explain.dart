class ShapContribution {
  final String feature;
  final double shapValue;
  final String impact; // "increase" | "decrease"

  const ShapContribution({
    required this.feature,
    required this.shapValue,
    required this.impact,
  });

  factory ShapContribution.fromJson(Map<String, dynamic> json) {
    return ShapContribution(
      feature: json['feature'] as String? ?? '',
      shapValue: (json['shap_value'] as num?)?.toDouble() ?? 0.0,
      impact: json['impact'] as String? ?? 'increase',
    );
  }
}

class ShapExplainResponse {
  final String status;
  final String customerId;
  final double churnProbability;
  final String riskLevel;
  final List<ShapContribution> contributions;

  const ShapExplainResponse({
    required this.status,
    required this.customerId,
    required this.churnProbability,
    required this.riskLevel,
    required this.contributions,
  });

  factory ShapExplainResponse.fromJson(Map<String, dynamic> json) {
    return ShapExplainResponse(
      status: json['status'] as String? ?? 'success',
      customerId: json['customer_id'] as String? ?? '',
      churnProbability: (json['churn_probability'] as num?)?.toDouble() ?? 0.0,
      riskLevel: json['risk_level'] as String? ?? 'LOW',
      contributions: (json['contributions'] as List<dynamic>? ?? [])
          .map((e) => ShapContribution.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
