import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/widgets/price_change_text.dart';
import '../../assets/domain/asset.dart';
import '../../auth/presentation/login_screen.dart';
import '../data/portfolio_repository.dart';
import 'asset_analytics_screen.dart';
import 'asset_position_screen.dart';
import 'asset_search_screen.dart';
import 'news_detail_screen.dart';
import 'transaction_screen.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key, required this.apiClient});
  final ApiClient apiClient;

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  late final PortfolioRepository repository;
  Map<String, dynamic>? summary;
  String? portfolioId;
  bool isLoading = true;
  int tabIndex = 1;
  int alertsVersion = 0;
  Timer? _portfolioTimer;
  Timer? _alertTimer;

  @override
  void initState() {
    super.initState();
    repository = PortfolioRepository(widget.apiClient);
    _load();
    _portfolioTimer = Timer.periodic(const Duration(seconds: 60), (_) => _load(showLoading: false));
    _alertTimer = Timer.periodic(const Duration(seconds: 60), (_) => _checkAlertsInBackground());
  }

  @override
  void dispose() {
    _portfolioTimer?.cancel();
    _alertTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAlertsInBackground() async {
    try {
      final triggered = await repository.checkAlerts();
      if (!mounted || triggered.isEmpty) return;

      for (final event in triggered) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(event['message'] as String? ?? 'Сработало уведомление'),
          ),
        );
      }

      if (!mounted) return;
      setState(() => alertsVersion++);
    } catch (_) {
      // Фоновая проверка уведомлений не должна мешать пользователю.
    }
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => isLoading = true);
    try {
      final portfolios = await repository.getPortfolios();
      final Map<String, dynamic> portfolio = portfolios.isEmpty
          ? await repository.createPortfolio()
          : portfolios.first as Map<String, dynamic>;
      final id = portfolio['id'] as String;
      final loadedSummary = await repository.getSummary(id);
      if (!mounted) return;
      setState(() {
        portfolioId = id;
        summary = loadedSummary;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось загрузить портфель: $e')));
    }
  }

  Future<void> _openAddTransaction() async {
    final id = portfolioId;
    if (id == null) return;
    final asset = await Navigator.of(context).push<Asset>(MaterialPageRoute(builder: (_) => AssetSearchScreen(repository: repository)));
    if (asset == null || !mounted) return;
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => TransactionScreen(repository: repository, portfolioId: id, asset: asset)));
    if (changed == true) await _load();
  }

  Future<void> _openCreateAlert() async {
    final asset = await Navigator.of(context).push<Asset>(
      MaterialPageRoute(builder: (_) => AssetSearchScreen(repository: repository)),
    );
    if (asset == null || !mounted) return;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => CreateAlertSheet(
        repository: repository,
        asset: asset,
        portfolioId: portfolioId,
      ),
    );
    if (created == true && mounted) {
      setState(() {
        tabIndex = 2;
        alertsVersion++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Уведомление для ${asset.ticker} создано')),
      );
    }
  }

  String _money(num? value, {String? currency}) => formatMoney(value, currency: currency ?? 'USD');

  @override
  Widget build(BuildContext context) {
    final pages = [
      NewsTab(repository: repository),
      PortfolioTab(summary: summary, isLoading: isLoading, reload: _load, money: _money, repository: repository, portfolioId: portfolioId),
      AlertsTab(key: ValueKey(alertsVersion), repository: repository),
      SettingsTab(repository: repository, onLogout: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => LoginScreen(apiClient: widget.apiClient)), (_) => false)),
    ];

    final showAdd = tabIndex == 1 || tabIndex == 2;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(index: tabIndex, children: pages),
            if (showAdd)
              Positioned(
                right: 22,
                bottom: 98,
                child: RoundAddButton(onTap: () {
                  if (tabIndex == 1) {
                    _openAddTransaction();
                  } else {
                    _openCreateAlert();
                  }
                }),
              ),
            Positioned(
              left: 34,
              right: 34,
              bottom: 24,
              child: BottomNav(currentIndex: tabIndex, onChanged: (index) => setState(() => tabIndex = index)),
            ),
          ],
        ),
      ),
    );
  }
}

class PortfolioTab extends StatelessWidget {
  const PortfolioTab({super.key, required this.summary, required this.isLoading, required this.reload, required this.money, required this.repository, required this.portfolioId});
  final Map<String, dynamic>? summary;
  final bool isLoading;
  final Future<void> Function() reload;
  final String Function(num? value, {String? currency}) money;
  final PortfolioRepository repository;
  final String? portfolioId;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final positions = (s?['positions'] as List<dynamic>?) ?? const [];
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 38, 10, 154),
        children: [
          Text('Ваш портфель', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.text)),
          const SizedBox(height: 30),
          if (isLoading || s == null)
            const Center(child: Padding(padding: EdgeInsets.all(44), child: CircularProgressIndicator()))
          else ...[
            SummaryCard(summary: s, money: money),
            const SizedBox(height: 20),
            const PositionsHeader(),
            const SizedBox(height: 8),
            for (final p in positions)
              PositionRow(
                position: p as Map<String, dynamic>,
                money: money,
                onTap: () async {
                  final id = portfolioId;
                  if (id == null) return;
                  final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => AssetPositionScreen(repository: repository, portfolioId: id, position: p)));
                  if (changed == true) {
                    await reload();
                  }
                },
                onLongPress: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => AssetAnalyticsScreen(
                    repository: repository,
                    asset: Asset(id: p['asset_id'] as String, ticker: p['ticker'] as String? ?? '-', name: p['asset_name'] as String? ?? '', assetType: '', marketType: '', currencyCode: (p['currency_code'] as String?) ?? 'USD'),
                    position: p,
                  )));
                },
              ),
            if (positions.isEmpty)
              const Padding(padding: EdgeInsets.only(top: 20), child: Text('Пока нет сделок. Нажмите +, чтобы добавить покупку или продажу.')),
          ],
        ],
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.summary, required this.money});
  final Map<String, dynamic> summary;
  final String Function(num? value, {String? currency}) money;

  @override
  Widget build(BuildContext context) {
    final profit = summary['profit_loss'] as num? ?? 0;
    final percent = summary['profit_percent'] as num? ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Стоимость портфеля', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(money(summary['current_value'] as num?, currency: summary['base_currency'] as String? ?? 'USD'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            Text(money(summary['invested_value'] as num?, currency: summary['base_currency'] as String? ?? 'USD'), style: Theme.of(context).textTheme.titleLarge),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Прибыль/Убыток', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('${profit >= 0 ? '+' : '-'}${money(profit.abs(), currency: summary['base_currency'] as String? ?? 'USD')}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: profit >= 0 ? AppTheme.success : Colors.red)),
            const SizedBox(height: 14),
            Text('${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: percent >= 0 ? AppTheme.success : Colors.red)),
          ]),
        ]),
      ),
    );
  }
}

class PositionsHeader extends StatelessWidget {
  const PositionsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600);

    return Column(
      children: [
        Row(
          children: [
            Expanded(flex: 3, child: Text('Актив', style: style, textAlign: TextAlign.left)),
            Expanded(flex: 3, child: Text('Инвестировано', style: style, textAlign: TextAlign.center)),
            Expanded(flex: 3, child: Text('Позиция', style: style, textAlign: TextAlign.right)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(flex: 3, child: Text('Количество', style: style, textAlign: TextAlign.left)),
            Expanded(flex: 3, child: Text('Ср. цена', style: style, textAlign: TextAlign.center)),
            Expanded(flex: 3, child: Text('P&L', style: style, textAlign: TextAlign.right)),
          ],
        ),
      ],
    );
  }
}

class PositionRow extends StatelessWidget {
  const PositionRow({super.key, required this.position, required this.money, required this.onTap, required this.onLongPress});
  final Map<String, dynamic> position;
  final String Function(num? value, {String? currency}) money;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final profit = position['profit_loss'] as num? ?? 0;
    final qty = ((position['quantity'] as num?) ?? 0).toDouble();
    final currency = position['currency_code'] as String? ?? 'USD';
    final ticker = position['ticker'] as String? ?? '-';
    final titleColor = Theme.of(context).colorScheme.onSurface;
    final mutedColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.55);

    return Card(
      margin: const EdgeInsets.only(top: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticker,
                      textAlign: TextAlign.left,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: titleColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 4)} $ticker',
                      textAlign: TextAlign.left,
                      style: TextStyle(fontSize: 17, color: mutedColor),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      money(position['invested_value'] as num?, currency: currency),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: titleColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      money(position['avg_buy_price'] as num?, currency: currency),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, color: mutedColor),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money(position['current_value'] as num?, currency: currency),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: titleColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profit >= 0 ? '+' : '-'}${money(profit.abs(), currency: currency)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 17, color: profit >= 0 ? AppTheme.success : Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NewsTab extends StatefulWidget {
  const NewsTab({super.key, required this.repository});
  final PortfolioRepository repository;
  @override
  State<NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<NewsTab> {
  List<Map<String, dynamic>> news = [];
  String market = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final loaded = await widget.repository.getNews(market: market);
      if (!mounted) return;
      setState(() => news = loaded.isEmpty ? _fallbackNews() : loaded);
    } catch (_) {
      if (!mounted) return;
      setState(() => news = _fallbackNews());
    }
  }

  List<Map<String, dynamic>> _fallbackNews() => const [
    {'title': 'S&P повысило прогноз по Latam Airlines до позитивного', 'source': 'Mock', 'date': '2026-06-10', 'description': 'S&P Global Ratings пересмотрело прогноз по Latam Airlines Group S.A. со стабильного на позитивный.'},
    {'title': 'ЦБ РФ может снизить ключевую ставку до 9% к концу 2026 года', 'source': 'Mock', 'date': '2026-06-10', 'description': 'Аналитики ожидают постепенное снижение ставки при замедлении инфляции.'},
    {'title': 'ФИНАМ: Рынок в надежде на позитив от ЦБ', 'source': 'Mock', 'date': '2026-06-10', 'description': 'Инвесторы ждут сигналов регулятора и пересматривают риск-профиль портфелей.'},
    {'title': 'ЯПОНИЯ - СТАВКА ЦБ = 0.75%', 'source': 'Mock', 'date': '2026-06-10', 'description': 'Банк Японии сохранил осторожный подход к монетарной политике.'},
    {'title': 'Следующий глава ФРС снизит ставку — глава Минторга США Латник', 'source': 'Mock', 'date': '2026-06-10', 'description': 'Рынок обсуждает возможную траекторию ставки ФРС.'},
    {'title': 'Набиуллина: экономика выйдет из перегрева в первом полугодии 2026г', 'source': 'Mock', 'date': '2026-06-10', 'description': 'Регулятор ожидает охлаждение спроса и стабилизацию инфляции.'},
    {'title': 'Трамп заявил, что его пошлины сократили торговый дефицит США более чем вдвое', 'source': 'Mock', 'date': '2026-06-10', 'description': 'Новости о внешней торговле влияют на ожидания инвесторов.'},
    {'title': 'Китай ввел антидемпинговые пошлины на поставки свинины из ЕС — Xinhua', 'source': 'Mock', 'date': '2026-06-10', 'description': 'Торговые ограничения могут отразиться на отдельных секторах рынка.'},
  ];

  @override
  Widget build(BuildContext context) {
    final items = news.isEmpty ? _fallbackNews() : news;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 150),
      children: [
        Text('Новости', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        Row(children: [
          _NewsFilter(label: 'Все', value: '', selected: market, onTap: (v) { setState(() => market = v); _load(); }),
          const SizedBox(width: 8),
          _NewsFilter(label: 'Акции', value: 'stock', selected: market, onTap: (v) { setState(() => market = v); _load(); }),
          const SizedBox(width: 8),
          _NewsFilter(label: 'Крипто', value: 'crypto', selected: market, onTap: (v) { setState(() => market = v); _load(); }),
        ]),
        const SizedBox(height: 22),
        for (final item in items)
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              title: Text(item['title'] as String? ?? '', style: const TextStyle(fontSize: 18, height: 1.3, fontWeight: FontWeight.w700)),
              subtitle: Padding(padding: const EdgeInsets.only(top: 8), child: Text('${item['source'] ?? ''} · ${item['market'] ?? ''} · ${item['date'] ?? ''}')),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewsDetailScreen(news: item))),
            ),
          ),
      ],
    );
  }
}


class _NewsFilter extends StatelessWidget {
  const _NewsFilter({required this.label, required this.value, required this.selected, required this.onTap});
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => onTap(value),
    );
  }
}


class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key, required this.repository});
  final PortfolioRepository repository;

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  List<Map<String, dynamic>> alerts = [];
  List<Map<String, dynamic>> events = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }


  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => isLoading = true);
    try {
      final loadedAlerts = await widget.repository.getAlerts();
      final loadedEvents = await widget.repository.getAlertEvents();
      if (!mounted) return;
      setState(() {
        alerts = loadedAlerts;
        events = loadedEvents;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _checkAlerts() async {
    try {
      final triggered = await widget.repository.checkAlerts();
      if (!mounted) return;
      if (triggered.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Новых срабатываний нет')));
      } else {
        for (final event in triggered) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(event['message'] as String? ?? 'Сработало уведомление')));
        }
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось проверить уведомления: $e')));
    }
  }

  Future<void> _toggle(String id) async {
    await widget.repository.toggleAlert(id);
    await _load();
  }

  Future<void> _delete(String id) async {
    await widget.repository.deleteAlert(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 34, 24, 150),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Уведомления', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
              IconButton(onPressed: _checkAlerts, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 28),
          if (isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (alerts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Пока нет правил. Нажмите +, выберите актив и задайте целевую цену.'),
              ),
            )
          else ...[
            Text('Правила', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            for (final alert in alerts)
              AlertRuleCard(
                alert: alert,
                onToggle: () => _toggle(alert['id'] as String),
                onDelete: () => _delete(alert['id'] as String),
              ),
          ],
          if (events.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('События', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            for (final event in events.take(8))
              Card(
                child: ListTile(
                  title: Text(event['message'] as String? ?? ''),
                  subtitle: Text('${event['ticker'] ?? ''} · ${event['event_status'] ?? ''}'),
                  leading: const Icon(Icons.notifications_active_outlined),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class AlertRuleCard extends StatelessWidget {
  const AlertRuleCard({super.key, required this.alert, required this.onToggle, required this.onDelete});
  final Map<String, dynamic> alert;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ticker = alert['ticker'] as String? ?? '-';
    final op = alert['comparison_operator'] as String? ?? 'above';
    final currency = alert['currency_code'] as String? ?? 'USD';
    final target = alert['target_value'] as num? ?? 0;
    final enabled = alert['is_enabled'] as bool? ?? true;
    final condition = op == 'below' ? 'Цена ниже' : 'Цена выше';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ticker, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('$condition ${formatMoney(target, currency: currency)}'),
                const SizedBox(height: 4),
                Text(enabled ? 'Активно' : 'Выключено', style: TextStyle(color: enabled ? AppTheme.success : Colors.grey)),
              ]),
            ),
            Switch(value: enabled, onChanged: (_) => onToggle()),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Удалить'))],
            ),
          ],
        ),
      ),
    );
  }
}

class CreateAlertSheet extends StatefulWidget {
  const CreateAlertSheet({super.key, required this.repository, required this.asset, required this.portfolioId});
  final PortfolioRepository repository;
  final Asset asset;
  final String? portfolioId;

  @override
  State<CreateAlertSheet> createState() => _CreateAlertSheetState();
}

class _CreateAlertSheetState extends State<CreateAlertSheet> {
  final targetController = TextEditingController();
  String operator = 'above';
  bool isSaving = false;

  @override
  void dispose() {
    targetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final target = double.tryParse(targetController.text.replaceAll(',', '.'));
    if (target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите корректную целевую цену')));
      return;
    }
    setState(() => isSaving = true);
    try {
      await widget.repository.createAlert(
        assetId: widget.asset.id,
        portfolioId: widget.portfolioId,
        targetValue: target,
        comparisonOperator: operator,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось создать уведомление: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Новое уведомление', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              title: Text(widget.asset.ticker, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(widget.asset.name),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'above', label: Text('Цена выше')),
              ButtonSegment(value: 'below', label: Text('Цена ниже')),
            ],
            selected: {operator},
            onSelectionChanged: (value) => setState(() => operator = value.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: targetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Целевая цена (${widget.asset.currencyCode})'),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: isSaving ? null : _save,
            child: Text(isSaving ? 'Сохранение...' : 'Создать уведомление'),
          ),
        ],
      ),
    );
  }
}

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key, required this.repository, required this.onLogout});
  final PortfolioRepository repository;
  final VoidCallback onLogout;
  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  Map<String, dynamic>? me;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final loaded = await widget.repository.getMe(); if (mounted) setState(() => me = loaded); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final name = me?['display_name'] as String? ?? 'Пользователь';
    final email = me?['email'] as String? ?? 'email не загружен';
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 70, 14, 150),
      children: [
        Card(child: Padding(padding: const EdgeInsets.all(24), child: Row(children: [
          Icon(Icons.person_outline, size: 70, color: Theme.of(context).colorScheme.onSurface),
          const SizedBox(width: 22),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.text)),
            Text(email, style: const TextStyle(fontSize: 18, color: Color(0xFFA4A1AA))),
          ]),
        ]))),
        const SizedBox(height: 34),
        Card(child: Padding(padding: const EdgeInsets.fromLTRB(22, 24, 22, 24), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Тёмная тема', style: TextStyle(fontSize: 22)),
          Consumer<ThemeController>(builder: (context, theme, _) => Switch(value: theme.isDark, onChanged: theme.setDark)),
        ]))),
        const SizedBox(height: 240),
        OutlinedButton.icon(
          onPressed: () async {
            await widget.repository.logout();
            if (!context.mounted) return;
            widget.onLogout();
          },
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text('Log out', style: TextStyle(color: Colors.red, fontSize: 18)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        ),
      ],
    );
  }
}

class RoundAddButton extends StatelessWidget {
  const RoundAddButton({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(color: Theme.of(context).colorScheme.surface, shape: const CircleBorder(), elevation: 5, child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: const SizedBox(width: 58, height: 58, child: Icon(Icons.add, size: 46))));
  }
}

class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.currentIndex, required this.onChanged});
  final int currentIndex;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final icons = [Icons.newspaper_outlined, Icons.pie_chart_outline, Icons.notifications_none, Icons.settings_outlined];
    return Container(
      height: 72,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(40), border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.35))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        for (var i = 0; i < icons.length; i++)
          IconButton(iconSize: 40, color: currentIndex == i ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface, onPressed: () => onChanged(i), icon: Icon(icons[i])),
      ]),
    );
  }
}
