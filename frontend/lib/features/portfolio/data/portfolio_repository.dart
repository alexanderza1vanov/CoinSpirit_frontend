import '../../../core/api/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../../assets/domain/asset.dart';

class PortfolioRepository {
  PortfolioRepository(this.api);
  final ApiClient api;

  Future<List<dynamic>> getPortfolios() async {
    final response = await api.dio.get('/portfolios');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createPortfolio() async {
    final response = await api.dio.post('/portfolios', data: {
      'name': 'Основной портфель',
      'base_currency': 'USD',
      'description': 'MVP portfolio',
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSummary(String portfolioId) async {
    final response = await api.dio.get('/portfolios/$portfolioId/summary');
    return response.data as Map<String, dynamic>;
  }

  Future<List<Asset>> getAssets({String query = ''}) async {
    final response = await api.dio.get('/assets/search', queryParameters: {'q': query});
    final items = response.data as List<dynamic>;
    return items.map((e) => Asset.fromJson(e as Map<String, dynamic>)).toList();
  }


  Future<List<Map<String, dynamic>>> getPositions(String portfolioId) async {
    final response = await api.dio.get('/portfolios/$portfolioId/positions');
    final items = response.data as List<dynamic>;
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getTransactions(String portfolioId) async {
    final response = await api.dio.get('/portfolios/$portfolioId/transactions');
    final items = response.data as List<dynamic>;
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getPriceHistory(String assetId, {String timeframe = '1d'}) async {
    final response = await api.dio.get('/assets/$assetId/price-history', queryParameters: {'timeframe': timeframe});
    final items = response.data as List<dynamic>;
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> getAnalyticsOverview(String assetId, {String timeframe = '1d'}) async {
    final response = await api.dio.get('/analytics/assets/$assetId/overview', queryParameters: {'timeframe': timeframe});
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getNews({String market = ''}) async {
    final response = await api.dio.get('/news', queryParameters: {if (market.isNotEmpty) 'market': market});
    final items = response.data as List<dynamic>;
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await api.dio.get('/auth/me');
    return response.data as Map<String, dynamic>;
  }

  Future<void> logout() async {
    try {
      await api.dio.post('/auth/logout');
    } catch (_) {
      // Local logout should still happen if the backend is unavailable.
    }
    api.clearAccessToken();
    await SessionStorage().clear();
  }

  Future<Map<String, dynamic>> getAssetPrice(String assetId) async {
    final response = await api.dio.get('/assets/$assetId/price');
    return response.data as Map<String, dynamic>;
  }


  Future<List<Map<String, dynamic>>> getAlerts() async {
    final response = await api.dio.get('/alerts');
    final items = response.data as List<dynamic>;
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<void> createAlert({
    required String assetId,
    required double targetValue,
    required String comparisonOperator,
    String? portfolioId,
  }) async {
    await api.dio.post('/alerts', data: {
      'asset_id': assetId,
      'portfolio_id': portfolioId ?? '',
      'rule_type': 'price',
      'target_value': targetValue,
      'comparison_operator': comparisonOperator,
      'channels': ['in_app', 'email'],
      'is_enabled': true,
    });
  }

  Future<void> toggleAlert(String alertId) async {
    await api.dio.post('/alerts/$alertId/toggle');
  }

  Future<void> deleteAlert(String alertId) async {
    await api.dio.delete('/alerts/$alertId');
  }

  Future<List<Map<String, dynamic>>> getAlertEvents() async {
    final response = await api.dio.get('/alerts/events');
    final items = response.data as List<dynamic>;
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> checkAlerts() async {
    final response = await api.dio.post('/alerts/check');
    final items = response.data as List<dynamic>;
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<void> addTransaction({
    required String portfolioId,
    required String assetId,
    required String transactionType,
    required double quantity,
    required double unitPrice,
    required double feeAmount,
    String note = '',
  }) async {
    await api.dio.post('/portfolios/$portfolioId/transactions', data: {
      'asset_id': assetId,
      'transaction_type': transactionType,
      'quantity': quantity,
      'unit_price': unitPrice,
      'fee_amount': feeAmount,
      'note': note,
    });
  }

  Future<void> updateTransaction({
    required String portfolioId,
    required String transactionId,
    required String transactionType,
    required double quantity,
    required double unitPrice,
    required double feeAmount,
    String note = '',
  }) async {
    await api.dio.put('/portfolios/$portfolioId/transactions/$transactionId', data: {
      'transaction_type': transactionType,
      'quantity': quantity,
      'unit_price': unitPrice,
      'fee_amount': feeAmount,
      'note': note,
    });
  }

  Future<void> deleteTransaction({
    required String portfolioId,
    required String transactionId,
  }) async {
    await api.dio.delete('/portfolios/$portfolioId/transactions/$transactionId');
  }

}
