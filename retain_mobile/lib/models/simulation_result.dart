class SimulationResult {
  final String status;
  final double newChurnProbability;
  final String riskLevel;
  final double riskReductionPercentage;
  final String recommendation;
  final double? acceptanceProbability;

  const SimulationResult({
    required this.status,
    required this.newChurnProbability,
    required this.riskLevel,
    required this.riskReductionPercentage,
    required this.recommendation,
    this.acceptanceProbability,
  });

  factory SimulationResult.fromJson(Map<String, dynamic> json) {
    return SimulationResult(
      status: json['status'] as String,
      newChurnProbability: (json['new_churn_probability'] as num).toDouble(),
      riskLevel: json['risk_level'] as String,
      riskReductionPercentage:
          (json['risk_reduction_percentage'] as num).toDouble(),
      recommendation: json['recommendation'] as String,
      acceptanceProbability: json['acceptance_probability'] != null
          ? (json['acceptance_probability'] as num).toDouble()
          : null,
    );
  }
}
