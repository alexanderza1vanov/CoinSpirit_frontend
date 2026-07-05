import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../portfolio/presentation/portfolio_screen.dart';
import '../data/auth_repository.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final ApiClient apiClient;
  late final AuthRepository authRepository;
  bool isLoading = true;
  bool isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    apiClient = ApiClient();
    authRepository = AuthRepository(apiClient);
    _restore();
  }

  Future<void> _restore() async {
    final ok = await authRepository.restoreSession();
    if (!mounted) return;
    setState(() {
      isAuthenticated = ok;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (isAuthenticated) {
      return PortfolioScreen(apiClient: apiClient);
    }

    return LoginScreen(apiClient: apiClient);
  }
}
