import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../assets/domain/asset.dart';
import '../../../shared/widgets/price_change_text.dart';
import '../data/portfolio_repository.dart';
import 'asset_analytics_screen.dart';
import 'transaction_screen.dart';

class AssetPositionScreen extends StatefulWidget {
  const AssetPositionScreen({super.key, required this.repository, required this.portfolioId, required this.position});
  final PortfolioRepository repository;
  final String portfolioId;
  final Map<String, dynamic> position;

  @override
  State<AssetPositionScreen> createState() => _AssetPositionScreenState();
}

class _AssetPositionScreenState extends State<AssetPositionScreen> {
  List<Map<String, dynamic>> transactions = [];
  Map<String, dynamic>? currentPosition;
  bool isLoading = true;
  bool hasChanges = false;

  String get assetId => widget.position['asset_id'] as String? ?? '';
  String get ticker => widget.position['ticker'] as String? ?? '-';
  String get name => widget.position['asset_name'] as String? ?? ticker;
  String get currency => widget.position['currency_code'] as String? ?? 'USD';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final loaded = await widget.repository.getTransactions(widget.portfolioId);
      final positions = await widget.repository.getPositions(widget.portfolioId);
      Map<String, dynamic>? freshPosition;
      for (final p in positions) {
        if (p['asset_id'] == assetId) {
          freshPosition = p;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        transactions = loaded.where((tx) => tx['asset_id'] == assetId).toList();
        currentPosition = freshPosition ?? currentPosition ?? widget.position;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось загрузить сделки: $e')));
    }
  }

  String money(num? value) => formatMoney(value, currency: currency);

  void _openAnalytics() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AssetAnalyticsScreen(
        repository: widget.repository,
        asset: Asset(id: assetId, ticker: ticker, name: name, assetType: '', marketType: '', currencyCode: currency),
        position: currentPosition ?? widget.position,
      ),
    ));
  }

  Future<void> _openEditTransaction(Map<String, dynamic> tx) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TransactionScreen(
          repository: widget.repository,
          portfolioId: widget.portfolioId,
          asset: Asset(id: assetId, ticker: ticker, name: name, assetType: '', marketType: '', currencyCode: currency),
          initialTransaction: tx,
        ),
      ),
    );

    if (changed == true) {
      await _load();
      if (!mounted) return;
      hasChanges = true;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Транзакция обновлена')));
    }
  }


  Future<void> _deleteTransaction(Map<String, dynamic> tx) async {
    final transactionId = tx['id'] as String?;
    if (transactionId == null || transactionId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить транзакцию?'),
        content: const Text('Это действие нельзя отменить. Позиция по активу будет пересчитана.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.repository.deleteTransaction(
        portfolioId: widget.portfolioId,
        transactionId: transactionId,
      );
      await _load();
      if (!mounted) return;
      hasChanges = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Транзакция удалена')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить транзакцию: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = currentPosition ?? widget.position;
    final current = position['current_value'] as num? ?? 0;
    final invested = position['invested_value'] as num? ?? 0;
    final profitPercent = position['profit_percent'] as num? ?? 0;
    final profit = position['profit_loss'] as num? ?? 0;
    final change24h = position['change_24h_percent'] as num?;
    final quantity = position['quantity'] as num? ?? 0;
    final avgBuyPrice = position['avg_buy_price'] as num? ?? 0;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 30),
            children: [
              Row(
                children: [
                  IconButton(onPressed: () => Navigator.of(context).pop(hasChanges), icon: const Icon(Icons.arrow_back, size: 30)),
                  Expanded(child: Center(child: Text(ticker, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.text)))),
                  IconButton(onPressed: _openAnalytics, icon: const Icon(Icons.show_chart, size: 28)),
                ],
              ),
              const SizedBox(height: 34),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(money(current), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: profit >= 0 ? AppTheme.success : Colors.red)),
                    const SizedBox(height: 6),
                    Text('Инвестировано ${money(invested)} • Доходность ${profitPercent.toStringAsFixed(2)}%', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.text)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _MetricChip(label: '24ч', child: PriceChangeText(percent: change24h, fontSize: 14)),
                        _MetricChip(label: 'Ср. цена', value: money(avgBuyPrice)),
                        _MetricChip(label: 'Количество', value: '${quantity.toString()} $ticker'),
                        _MetricChip(label: 'P&L', value: '${profit >= 0 ? '+' : '-'}${money(profit.abs())}', valueColor: profit >= 0 ? AppTheme.success : Colors.red),
                      ],
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(onPressed: _openAnalytics, icon: const Icon(Icons.analytics_outlined), label: const Text('Открыть аналитику')),
                  ]),
                ),
              ),
              const SizedBox(height: 22),
              if (isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
              else if (transactions.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('По этому активу пока нет сделок.')))
              else
                for (final tx in transactions) _TransactionCard(tx: tx, money: money, onEdit: () => _openEditTransaction(tx), onDelete: () => _deleteTransaction(tx)),
            ],
          ),
        ),
      ),
    );
  }
}


class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, this.value, this.child, this.valueColor});
  final String label;
  final String? value;
  final Widget? child;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final mutedColor = textColor.withOpacity(0.58);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.42),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: mutedColor, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          child ?? Text(value ?? '—', style: TextStyle(color: valueColor ?? textColor, fontSize: 15, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.tx, required this.money, required this.onEdit, required this.onDelete});
  final Map<String, dynamic> tx;
  final String Function(num? value) money;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final type = tx['transaction_type'] as String? ?? 'buy';
    final amount = tx['total_amount'] as num? ?? 0;
    final qty = tx['quantity'] as num? ?? 0;
    final price = tx['unit_price'] as num? ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
        title: Text('${type == 'buy' ? 'Покупка' : 'Продажа'} ${tx['ticker'] ?? ''}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.text)),
        subtitle: Text('${money(price)} • $qty', style: const TextStyle(fontSize: 16, color: Color(0xFFA4A1AA))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${type == 'buy' ? '+' : '-'}${money(amount)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: type == 'buy' ? AppTheme.success : Colors.red)),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                PopupMenuItem(value: 'delete', child: Text('Удалить')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
