import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/widgets/price_change_text.dart';
import '../../assets/domain/asset.dart';
import '../data/portfolio_repository.dart';

class AssetSearchScreen extends StatefulWidget {
  const AssetSearchScreen({super.key, required this.repository});

  final PortfolioRepository repository;

  @override
  State<AssetSearchScreen> createState() => _AssetSearchScreenState();
}

class _AssetSearchScreenState extends State<AssetSearchScreen> {
  final controller = TextEditingController();
  List<Asset> assets = [];
  bool isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search();
    controller.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
    setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final loaded = await widget.repository.getAssets(query: controller.text.trim());
      if (!mounted) return;
      setState(() => assets = loaded);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось найти активы')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 30),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      labelText: 'Поиск актива',
                      hintText: 'BTC, SBER, AFLT, XRP...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: controller.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.cancel),
                              onPressed: () {
                                controller.clear();
                                _search();
                              },
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (assets.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    controller.text.trim().isEmpty
                        ? 'Начните вводить тикер или название актива.'
                        : 'Актив не найден. Попробуйте тикер, например AFLT, GAZP, XRP или SOL.',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              )
            else
              for (final asset in assets)
                Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    title: Text(
                      asset.ticker,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      asset.name,
                      style: TextStyle(fontSize: 18, color: theme.colorScheme.onSurface.withOpacity(0.55)),
                    ),
                    trailing: asset.currentPrice == null
                        ? Chip(label: Text(asset.currencyCode))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatMoney(asset.currentPrice, currency: asset.currencyCode),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 3),
                              PriceChangeText(percent: asset.change24hPercent),
                            ],
                          ),
                    onTap: () => Navigator.of(context).pop(asset),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
