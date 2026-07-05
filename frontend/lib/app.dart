import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/auth_gate.dart';

class InvestPortfolioApp extends StatefulWidget {
  const InvestPortfolioApp({super.key});

  @override
  State<InvestPortfolioApp> createState() => _InvestPortfolioAppState();
}

class _InvestPortfolioAppState extends State<InvestPortfolioApp> {
  final ThemeController themeController = ThemeController();

  @override
  void initState() {
    super.initState();
    themeController.load();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: themeController,
      child: Consumer<ThemeController>(
        builder: (context, controller, _) {
          return MaterialApp(
            title: 'Invest Portfolio',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: controller.themeMode,
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}
