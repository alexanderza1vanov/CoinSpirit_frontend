import '../../../core/api/api_client.dart';
import '../../../core/storage/session_storage.dart';

class AuthRepository {
  AuthRepository(this.api, {SessionStorage? storage}) : storage = storage ?? SessionStorage();

  final ApiClient api;
  final SessionStorage storage;

  Future<String> login({required String email, required String password}) async {
    final response = await api.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final token = response.data['access_token'] as String;
    final refreshToken = response.data['refresh_token'] as String? ?? '';
    api.setAccessToken(token);
    await storage.saveTokens(accessToken: token, refreshToken: refreshToken);
    return token;
  }

  Future<void> register({required String email, required String password, required String displayName}) async {
    await api.dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'display_name': displayName,
    });
  }

  Future<bool> restoreSession() async {
    final accessToken = await storage.getAccessToken();
    final refreshToken = await storage.getRefreshToken();

    if (accessToken != null && accessToken.isNotEmpty) {
      api.setAccessToken(accessToken);
      try {
        await api.dio.get('/auth/me');
        return true;
      } catch (_) {
        // Access token may be expired. Try refresh token below.
      }
    }

    if (refreshToken == null || refreshToken.isEmpty) {
      await logout(localOnly: true);
      return false;
    }

    try {
      final response = await api.dio.post('/auth/refresh', data: {'refresh_token': refreshToken});
      final newAccess = response.data['access_token'] as String;
      final newRefresh = response.data['refresh_token'] as String? ?? refreshToken;
      api.setAccessToken(newAccess);
      await storage.saveTokens(accessToken: newAccess, refreshToken: newRefresh);
      return true;
    } catch (_) {
      await logout(localOnly: true);
      return false;
    }
  }

  Future<void> logout({bool localOnly = false}) async {
    if (!localOnly && api.accessToken != null) {
      try {
        await api.dio.post('/auth/logout');
      } catch (_) {
        // Local logout should still happen if server is unreachable.
      }
    }
    api.clearAccessToken();
    await storage.clear();
  }
}
