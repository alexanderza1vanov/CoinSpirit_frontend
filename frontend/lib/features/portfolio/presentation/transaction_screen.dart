import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/money_formatter.dart';
import '../../assets/domain/asset.dart';
import '../data/portfolio_repository.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({
    super.key,
    required this.repository,
    required this.portfolioId,
    required this.asset,
    this.initialTransaction,
  });

  final PortfolioRepository repository;
  final String portfolioId;
  final Asset asset;
  final Map<String, dynamic>? initialTransaction;

  bool get isEditing => initialTransaction != null;

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final quantityController = TextEditingController();
  final priceController = TextEditingController();
  final feeController = TextEditingController(text: '0');
  final noteController = TextEditingController();

  String transactionType = 'buy';
  bool isSaving = false;
  bool isPriceLoading = true;
  String currency = 'USD';
  String source = 'fallback';

  @override
  void initState() {
    super.initState();
    currency = widget.asset.currencyCode.isEmpty ? _defaultCurrency() : widget.asset.currencyCode;

    final tx = widget.initialTransaction;
    if (tx != null) {
      transactionType = tx['transaction_type'] as String? ?? 'buy';
      quantityController.text = _formatNumber(tx['quantity']);
      priceController.text = _formatNumber(tx['unit_price']);
      feeController.text = _formatNumber(tx['fee_amount']);
      noteController.text = tx['note'] as String? ?? '';
      isPriceLoading = false;
      source = 'transaction';
    } else {
      _loadPrice();
    }

    quantityController.addListener(() => setState(() {}));
    priceController.addListener(() => setState(() {}));
    feeController.addListener(() => setState(() {}));
  }

  String _defaultCurrency() => widget.asset.marketType.toLowerCase() == 'moex' ? 'RUB' : 'USD';

  String _formatNumber(dynamic value) {
    final number = value is num ? value.toDouble() : _parse('$value');
    if (number == 0) return '0';
    final fixed = number.toStringAsFixed(8);
    return fixed.replaceFirst(RegExp(r'\.0+$'), '').replaceFirst(RegExp(r'(\.\d*?)0+$'), r'$1');
  }

  Future<void> _loadPrice() async {
    try {
      final price = await widget.repository.getAssetPrice(widget.asset.id);
      if (!mounted) return;
      setState(() {
        final loadedPrice = price['price'];
        if (loadedPrice is num && loadedPrice > 0) {
          priceController.text = loadedPrice.toStringAsFixed(2);
        }
        currency = (price['currency'] as String?) ?? currency;
        source = (price['source'] as String?) ?? source;
        isPriceLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isPriceLoading = false);
    }
  }

  @override
  void dispose() {
    quantityController.dispose();
    priceController.dispose();
    feeController.dispose();
    noteController.dispose();
    super.dispose();
  }

  double _parse(String value) {
    final cleaned = value
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.\-]'), '');
    final normalized = cleaned.replaceFirst(RegExp(r'(?<=.)-'), '');
    final firstDot = normalized.indexOf('.');
    final safe = firstDot < 0
        ? normalized
        : normalized.substring(0, firstDot + 1) + normalized.substring(firstDot + 1).replaceAll('.', '');
    return double.tryParse(safe) ?? 0;
  }
  double get quantity => _parse(quantityController.text);
  double get price => _parse(priceController.text);
  double get fee => _parse(feeController.text);
  double get total => quantity * price + fee;

  Future<void> _save() async {
    if (quantity <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите количество и цену')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      if (widget.isEditing) {
        await widget.repository.updateTransaction(
          portfolioId: widget.portfolioId,
          transactionId: widget.initialTransaction!['id'] as String,
          transactionType: transactionType,
          quantity: quantity,
          unitPrice: price,
          feeAmount: fee,
          note: noteController.text.trim(),
        );
      } else {
        await widget.repository.addTransaction(
          portfolioId: widget.portfolioId,
          assetId: widget.asset.id,
          transactionType: transactionType,
          quantity: quantity,
          unitPrice: price,
          feeAmount: fee,
          note: noteController.text.trim(),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить сделку: $e')),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBuy = transactionType == 'buy';
    final title = widget.isEditing
        ? 'Редактирование транзакции'
        : isBuy
            ? 'Добавить покупку'
            : 'Добавить продажу';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 28),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      child: Text(
                        widget.asset.ticker.isNotEmpty ? widget.asset.ticker.substring(0, 1) : '?',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.asset.ticker, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text(widget.asset.name, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isPriceLoading ? '...' : formatMoney(price, currency: currency),
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(source, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _SegmentedType(value: transactionType, onChanged: (v) => setState(() => transactionType = v)),
            const SizedBox(height: 18),
            _InputCard(
              title: 'Количество',
              suffix: widget.asset.ticker,
              controller: quantityController,
              hint: widget.asset.marketType.toLowerCase() == 'moex' ? '1' : '0.1',
            ),
            const SizedBox(height: 12),
            _InputCard(title: 'Цена за единицу', suffix: currencySymbol(currency), controller: priceController, hint: '0.00'),
            const SizedBox(height: 12),
            _InputCard(title: 'Комиссия', suffix: currencySymbol(currency), controller: feeController, hint: '0.00'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: noteController,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Заметка',
                    hintText: 'Например: покупка для долгосрочного портфеля',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _TotalLine(label: 'Стоимость сделки', value: formatMoney(quantity * price, currency: currency)),
                    const SizedBox(height: 8),
                    _TotalLine(label: 'Комиссия', value: formatMoney(fee, currency: currency)),
                    const Divider(height: 24),
                    _TotalLine(label: 'Итого', value: formatMoney(total, currency: currency), bold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: isSaving ? null : _save,
              child: Text(
                isSaving
                    ? 'Сохранение...'
                    : widget.isEditing
                        ? 'Сохранить изменения'
                        : isBuy
                            ? 'Добавить покупку'
                            : 'Добавить продажу',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedType extends StatelessWidget {
  const _SegmentedType({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'buy', label: Text('Покупка'), icon: Icon(Icons.add_chart)),
        ButtonSegment(value: 'sell', label: Text('Продажа'), icon: Icon(Icons.trending_down)),
      ],
      selected: {value},
      onSelectionChanged: (v) => onChanged(v.first),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({required this.title, required this.suffix, required this.controller, required this.hint});
  final String title;
  final String suffix;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: InputDecoration(
            labelText: title,
            hintText: hint,
            suffixText: suffix,
          ),
        ),
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.label, required this.value, this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: bold ? 20 : 16, fontWeight: bold ? FontWeight.w900 : FontWeight.w500);
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: style), Text(value, style: style)]);
  }
}
