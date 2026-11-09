import 'dart:convert';
import 'dart:io' show Directory, File;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/adaptive_scenario.dart';
import '../models/churn_result.dart';
import '../models/retention_action.dart';
import '../models/shap_explain.dart';
import '../models/simulation_result.dart';



class ChurnApi {
  ChurnApi({String? baseUrl}) : _customUrl = baseUrl;

  final String? _customUrl;
  String get baseUrl => _customUrl ?? currentBaseUrl;

  static String? customBaseUrl;
  static File get _configFile => File('${Directory.systemTemp.path}/retain_api_url.txt');

  static String? _readSavedBaseUrl() {
    try {
      if (!kIsWeb && _configFile.existsSync()) {
        final val = _configFile.readAsStringSync().trim();
        if (val.isNotEmpty && !val.contains('127.0.0.1') && !val.contains('localhost')) {
          return val;
        }
      }
    } catch (_) {}
    return null;
  }

  static void _writeSavedBaseUrl(String? url) {
    try {
      if (!kIsWeb) {
        if (url != null && url.trim().isNotEmpty) {
          _configFile.writeAsStringSync(url.trim());
        } else if (_configFile.existsSync()) {
          _configFile.deleteSync();
        }
      }
    } catch (_) {}
  }

  static String get currentBaseUrl =>
      customBaseUrl ?? (_readSavedBaseUrl() ?? _defaultBaseUrl());

  static void setCustomBaseUrl(String? url) {
    customBaseUrl = (url != null && url.trim().isNotEmpty) ? url.trim() : null;
    _writeSavedBaseUrl(customBaseUrl);
  }

  static const String permanentDomain = 'https://headfirst-oil-confining.ngrok-free.dev';

  static String _defaultBaseUrl() {
    // 1. Jika di-pass melalui --dart-define=API_BASE_URL=...
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    // 2. Default: Domain permanen ngrok yang otomatis jalan saat docker compose up
    return permanentDomain;
  }

  static Map<String, String> _buildHeaders([Map<String, String>? extra]) {
    return {
      'ngrok-skip-browser-warning': 'true',
      ...?extra,
    };
  }

  Future<ChurnAlertsResponse> fetchAlerts({int limit = 20}) async {
    final uri = Uri.parse('$baseUrl/api/v1/churn-alerts').replace(
      queryParameters: {'limit': '$limit'},
    );
    final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat data peringatan (${response.statusCode})');
    }
    return ChurnAlertsResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SimulationResult> simulate({
    required int tenure,
    required double monthlyCharges,
    required double totalCharges,
    required String contract,
    required String internetService,
    required String paymentMethod,
    double? baselineProbability,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/simulate');
    final Map<String, dynamic> body = {
      'tenure': tenure,
      'monthly_charges': monthlyCharges,
      'total_charges': totalCharges,
      'contract': contract,
      'internet_service': internetService,
      'payment_method': paymentMethod,
    };
    if (baselineProbability != null) {
      body['baseline_probability'] = baselineProbability;
    }
    final response = await http.post(
      uri,
      headers: _buildHeaders({'Content-Type': 'application/json'}),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Simulasi gagal (${response.statusCode})');
    }
    return SimulationResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<RetentionActionsResponse> fetchCustomerActions(String customerId) async {
    final uri = Uri.parse('$baseUrl/api/v1/customers/$customerId/actions');
    final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat riwayat intervensi ($customerId: ${response.statusCode})');
    }
    return RetentionActionsResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<RetentionActionsResponse> fetchActions() async {
    final uri = Uri.parse('$baseUrl/api/v1/actions');
    final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat daftar tindakan (${response.statusCode})');
    }
    return RetentionActionsResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<RetentionActionItem> createAction({
    required String customerId,
    required String title,
    String actionType = 'OFFER_DISCOUNT',
    String status = 'PENDING',
    String? note,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/actions');
    final response = await http.post(
      uri,
      headers: _buildHeaders({'Content-Type': 'application/json'}),
      body: jsonEncode({
        'customer_id': customerId,
        'title': title,
        'action_type': actionType,
        'status': status,
        'note': note,
      }),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Gagal membuat tindakan retensi (${response.statusCode})');
    }
    return RetentionActionItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<RetentionActionItem> updateActionStatus({
    required int actionId,
    required String status,
    String? note,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/actions/$actionId');
    final response = await http.patch(
      uri,
      headers: _buildHeaders({'Content-Type': 'application/json'}),
      body: jsonEncode({
        'status': status,
        'note': note,
      }),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Gagal memperbarui status (${response.statusCode})');
    }
    return RetentionActionItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<RetentionStats> fetchActionStats() async {
    final uri = Uri.parse('$baseUrl/api/v1/actions/stats');
    final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat statistik retensi (${response.statusCode})');
    }
    return RetentionStats.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<ShapExplainResponse> fetchCustomerExplain(String customerId) async {
    final uri = Uri.parse('$baseUrl/api/v1/customers/$customerId/explain');
    final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat analisis profil risiko (${response.statusCode})');
    }
    return ShapExplainResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<AdaptiveScenario>> fetchRecommendedScenarios(String customerId) async {
    final uri = Uri.parse('$baseUrl/api/v1/customers/$customerId/recommended-scenarios');
    final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat rekomendasi skenario (${response.statusCode})');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = data['scenarios'] as List<dynamic>? ?? [];
    return list.map((e) => AdaptiveScenario.fromJson(e as Map<String, dynamic>)).toList();
  }
}


