import 'package:flutter/foundation.dart';
import '../data/auth_repository.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this.repository);
  final AuthRepository repository;

  bool isLoading = false;
  String? error;

  Future<bool> login(String email, String password) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await repository.login(email: email, password: password);
      return true;
    } catch (e) {
      error = 'Не удалось войти. Проверьте email и пароль.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
