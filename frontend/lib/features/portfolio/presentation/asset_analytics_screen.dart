import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../assets/domain/asset.dart';
import '../data/portfolio_repository.dart';

class AssetAnalyticsScreen extends StatefulWidget {
  const AssetAnalyticsScreen({super.key, required this.repository, required this.asset, this.position});
  final PortfolioRepository repository;
  final Asset asset;
  final Map<String, dynamic>? position;

  @override
  State<AssetAnalyticsScreen> createState() => _AssetAnalyticsScreenState();
}

class _AssetAnalyticsScreenState extends State<AssetAnalyticsScreen> {
  final periods = const ['1D', '1W', '1M', '3M', '1Y'];
  String selected = '1D';
  bool showRsi = false;
  bool showBollinger = false;
  bool showMacd = false;
  bool showMovingAverage = true;
  Map<String, dynamic>? overview;
  List<Map<String, dynamic>> candles = [];
  bool isLoading = true;
  String? note;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final data = await widget.repository.getAnalyticsOverview(widget.asset.id, timeframe: selected.toLowerCase());
      final loadedCandles = ((data['candles'] ?? []) as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
      if (!mounted) return;
      setState(() {
        overview = data;
        candles = loadedCandles.isEmpty ? _mockCandles() : loadedCandles;
        note = data['note'] as String?;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        candles = _mockCandles();
        overview = null;
        note = 'Данные аналитики временно недоступны. Показаны демонстрационные значения.';
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _mockCandles() {
    final price = (widget.position?['current_price'] as num?)?.toDouble() ??
        (widget.asset.currencyCode.toUpperCase() == 'RUB' ? 320.0 : 65000.0);
    final isCrypto = widget.asset.marketType.toLowerCase() == 'crypto' || widget.asset.currencyCode.toUpperCase() == 'USD';
    final volatility = isCrypto ? 0.025 : 0.008;
    const count = 90;

    return List.generate(count, (i) {
      final t = i / (count - 1);
      final wave = math.sin(t * math.pi * 4) * price * volatility +
          math.sin(t * math.pi * 9) * price * volatility * 0.35;
      final trend = (t - 1) * price * (isCrypto ? 0.018 : 0.006);
      final close = i == count - 1 ? price : price + wave + trend;
      final previous = i == 0 ? close : price + math.sin((i - 1) / 7) * price * volatility;
      final spread = price * volatility * 0.15;
      return {
        'open_price': previous,
        'high_price': math.max(previous, close) + spread,
        'low_price': math.max(0.01, math.min(previous, close) - spread),
        'close_price': close,
        'recorded_at': DateTime.now().subtract(Duration(hours: count - i)).toIso8601String(),
      };
    });
  }

  double get currentPrice {
    final p = overview?['price'];
    if (p is Map<String, dynamic>) return ((p['price'] ?? 0) as num).toDouble();
    if (candles.isNotEmpty) return _close(candles.last);
    return (widget.position?['current_price'] as num?)?.toDouble() ?? 0;
  }

  double get previousPrice {
    if (candles.length >= 2) return _close(candles.first);
    return currentPrice;
  }

  Map<String, dynamic> get indicators => (overview?['indicators'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get bands => (indicators['bollinger_bands'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get rsi => (indicators['rsi'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get macd => (indicators['macd'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get ma => (indicators['moving_average'] as Map<String, dynamic>?) ?? {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = currentPrice - previousPrice;
    final changePercent = previousPrice == 0 ? 0 : change / previousPrice * 100;
    final positive = change >= 0;
    final currency = ((overview?['price'] as Map<String, dynamic>?)?['currency'] ?? widget.asset.currencyCode).toString();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 28),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.asset.ticker, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                      Text(widget.asset.name, style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.62))),
                    ],
                  ),
                  const Spacer(),
                  IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                formatMoney(currentPrice, currency: currency),
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1.2),
              ),
              const SizedBox(height: 8),
              Text(
                '${_formatSignedMoney(change, currency)} (${positive ? '+' : ''}${changePercent.toStringAsFixed(2)}%)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: positive ? _successColor(context) : Colors.redAccent,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: periods.map((p) {
                  final selectedPeriod = selected == p;
                  return ChoiceChip(
                    label: Text(p),
                    selected: selectedPeriod,
                    onSelected: (_) {
                      setState(() => selected = p);
                      _load();
                    },
                    labelStyle: TextStyle(fontWeight: FontWeight.w700, color: selectedPeriod ? Colors.white : null),
                    selectedColor: const Color(0xFF5865D9),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              isLoading
                  ? const SizedBox(height: 330, child: Center(child: CircularProgressIndicator()))
                  : _AnalyticsChartCard(
                      candles: candles,
                      currentPrice: currentPrice,
                      currency: currency,
                      selectedPeriod: selected,
                      smaValue: _asDouble(ma['sma_20']),
                      emaValue: _asDouble(ma['ema_50']),
                      bands: bands,
                      showRsi: showRsi,
                      showBollinger: showBollinger,
                      showMacd: showMacd,
                      showMovingAverage: showMovingAverage,
                    ),
              if (note != null && note!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(note!, style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.58))),
              ],
              const SizedBox(height: 16),
              GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.02,
                children: [
                  _RsiCard(
                    value: _asDouble(rsi['value']),
                    signal: rsi['signal'],
                    selected: showRsi,
                    onTap: () => setState(() => showRsi = !showRsi),
                  ),
                  _BollingerCard(
                    bands: bands,
                    selected: showBollinger,
                    onTap: () => setState(() => showBollinger = !showBollinger),
                  ),
                  _MacdCard(
                    macd: macd,
                    selected: showMacd,
                    onTap: () => setState(() => showMacd = !showMacd),
                  ),
                  _MovingAverageCard(
                    ma: ma,
                    selected: showMovingAverage,
                    onTap: () => setState(() => showMovingAverage = !showMovingAverage),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: theme.textTheme.bodySmall?.color?.withOpacity(0.55), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Данные предоставлены в информационных целях и не являются инвестиционной рекомендацией.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.58)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSignedMoney(num value, String currency) {
    final sign = value >= 0 ? '+' : '-';
    return '$sign${formatMoney(value.abs(), currency: currency)}';
  }

  String _formatPlain(num? value) => value == null || value == 0 ? '—' : value.toStringAsFixed(2);
  double _asDouble(dynamic v) => v is num ? v.toDouble() : 0;
  Color _successColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? AppTheme.successDark : AppTheme.success;
}

class _AnalyticsChartCard extends StatelessWidget {
  const _AnalyticsChartCard({
    required this.candles,
    required this.currentPrice,
    required this.currency,
    required this.selectedPeriod,
    required this.smaValue,
    required this.emaValue,
    required this.bands,
    required this.showRsi,
    required this.showBollinger,
    required this.showMacd,
    required this.showMovingAverage,
  });

  final List<Map<String, dynamic>> candles;
  final double currentPrice;
  final String currency;
  final String selectedPeriod;
  final double smaValue;
  final double emaValue;
  final Map<String, dynamic> bands;
  final bool showRsi;
  final bool showBollinger;
  final bool showMacd;
  final bool showMovingAverage;

  @override
  Widget build(BuildContext context) {
    final normalized = candles.where((c) => _close(c) > 0 && _high(c) > 0 && _low(c) > 0).toList();
    final closes = normalized.map(_close).toList();
    if (closes.length < 2) return const SizedBox.shrink();

    final performance = _performanceRows(closes);

    return LayoutBuilder(builder: (context, constraints) {
      final chartHeight = constraints.maxWidth > 700 ? 380.0 : 330.0;
      final cardPadding = constraints.maxWidth > 700 ? 20.0 : 14.0;

      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xFF101724),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.36 : 0.14),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Column(
            children: [
              Row(
                children: [
                  const _LegendDot(color: Color(0xFF35E3C3), label: 'Свечи'),
                  if (showMovingAverage) ...[
                    const SizedBox(width: 18),
                    const _LegendDot(color: Color(0xFF7C6DFF), label: 'SMA'),
                    const SizedBox(width: 18),
                    const _LegendDot(color: Color(0xFFFFB84D), label: 'EMA'),
                  ],
                  if (showBollinger) ...[
                    const SizedBox(width: 18),
                    const _LegendDot(color: Color(0xFF4B8BFF), label: 'BB'),
                  ],
                  const Spacer(),
                  Text(currency.toUpperCase(), style: const TextStyle(color: Color(0xFF9CA3B7), fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: chartHeight,
                child: _CandlestickChart(
                  candles: normalized,
                  currentPrice: currentPrice,
                  currency: currency,
                  selectedPeriod: selectedPeriod,
                  showMovingAverage: showMovingAverage,
                  showBollinger: showBollinger,
                ),
              ),
              if (showRsi) ...[
                const SizedBox(height: 12),
                _MiniRsiPanel(closes: closes),
              ],
              if (showMacd) ...[
                const SizedBox(height: 12),
                _MiniMacdPanel(closes: closes),
              ],
              const SizedBox(height: 10),
              const Divider(color: Color(0x1FFFFFFF), height: 1),
              const SizedBox(height: 12),
              Row(
                children: performance.map((item) {
                  final positive = item.value >= 0;
                  return Expanded(
                    child: Column(
                      children: [
                        Text(item.label, style: const TextStyle(color: Color(0xFF9CA3B7), fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 5),
                        Text(
                          '${positive ? '+' : ''}${item.value.toStringAsFixed(2)}%',
                          style: TextStyle(color: positive ? const Color(0xFF35E3C3) : Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    });
  }

  List<_PerformanceItem> _performanceRows(List<double> closes) {
    double changeFor(int back) {
      if (closes.length < 2) return 0;
      final index = math.max(0, closes.length - 1 - back);
      final base = closes[index];
      return base == 0 ? 0 : (closes.last - base) / base * 100;
    }
    return [
      _PerformanceItem('24ч', changeFor(1)),
      _PerformanceItem('7д', changeFor(math.min(7, closes.length - 1))),
      _PerformanceItem('30д', changeFor(math.min(30, closes.length - 1))),
      _PerformanceItem(selectedPeriod, changeFor(closes.length - 1)),
    ];
  }
}

class _CandlestickChart extends StatelessWidget {
  const _CandlestickChart({
    required this.candles,
    required this.currentPrice,
    required this.currency,
    required this.selectedPeriod,
    required this.showMovingAverage,
    required this.showBollinger,
  });

  final List<Map<String, dynamic>> candles;
  final double currentPrice;
  final String currency;
  final String selectedPeriod;
  final bool showMovingAverage;
  final bool showBollinger;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CandlestickPainter(
        candles: candles,
        currentPrice: currentPrice,
        currency: currency,
        selectedPeriod: selectedPeriod,
        showMovingAverage: showMovingAverage,
        showBollinger: showBollinger,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _CandlestickPainter extends CustomPainter {
  _CandlestickPainter({
    required this.candles,
    required this.currentPrice,
    required this.currency,
    required this.selectedPeriod,
    required this.showMovingAverage,
    required this.showBollinger,
  });

  final List<Map<String, dynamic>> candles;
  final double currentPrice;
  final String currency;
  final String selectedPeriod;
  final bool showMovingAverage;
  final bool showBollinger;

  static const _upColor = Color(0xFF35E3C3);
  static const _downColor = Colors.redAccent;
  static const _smaColor = Color(0xFF7C6DFF);
  static const _emaColor = Color(0xFFFFB84D);
  static const _bbUpperColor = Color(0xFF4B8BFF);
  static const _bbLowerColor = Color(0xFFA970FF);

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.length < 2) return;

    final left = 18.0;
    final right = 72.0;
    final top = 8.0;
    final bottom = 34.0;
    final chart = Rect.fromLTWH(left, top, size.width - left - right, size.height - top - bottom);

    final highs = candles.map(_high).toList();
    final lows = candles.map(_low).toList();
    final closes = candles.map(_close).toList();
    final sma = _movingAverageValues(closes, period: math.min(20, math.max(3, closes.length ~/ 4)));
    final ema = _emaValues(closes, period: math.min(50, math.max(4, closes.length ~/ 3)));
    final bb = _bollingerSeries(closes, period: 20, factor: 2);

    // Keep the price scale based on candles and current price only.
    // Indicator overlays, especially Bollinger Bands after a sharp move, can be
    // much wider than the candles and should not squash/distort the chart.
    final allValues = <double>[...highs, ...lows, currentPrice];

    var minValue = allValues.reduce(math.min);
    var maxValue = allValues.reduce(math.max);
    if ((maxValue - minValue).abs() < 0.0001) {
      final pad = math.max(maxValue * 0.01, 1.0);
      minValue -= pad;
      maxValue += pad;
    }
    final padding = math.max((maxValue - minValue) * 0.12, maxValue * 0.004);
    final minY = math.max(0.0, minValue - padding);
    final maxY = maxValue + padding;

    double xFor(int i) {
      if (candles.length == 1) return chart.left + chart.width / 2;
      return chart.left + chart.width * i / (candles.length - 1);
    }

    double yFor(double value) {
      final ratio = ((maxY - value) / (maxY - minY)).clamp(0.0, 1.0).toDouble();
      return chart.top + chart.height * ratio;
    }

    final gridPaint = Paint()..color = Colors.white.withOpacity(0.065)..strokeWidth = 1;
    final dashedPaint = Paint()..color = Colors.white.withOpacity(0.085)..strokeWidth = 1;
    for (var i = 0; i <= 5; i++) {
      final y = chart.top + chart.height * i / 5;
      _drawDashedLine(canvas, Offset(chart.left, y), Offset(chart.right, y), dashedPaint);
      final value = maxY - (maxY - minY) * i / 5;
      _drawText(canvas, _axisPrice(value), Offset(chart.right + 10, y - 8), const Color(0xFF9CA3B7), 11, FontWeight.w700);
    }
    for (var i = 0; i <= 4; i++) {
      final x = chart.left + chart.width * i / 4;
      canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), gridPaint..color = Colors.white.withOpacity(0.045));
    }

    final candleWidth = math.max(3.0, math.min(12.0, chart.width / candles.length * 0.55));
    for (var i = 0; i < candles.length; i++) {
      final c = candles[i];
      final open = _open(c);
      final high = _high(c);
      final low = _low(c);
      final close = _close(c);
      final x = xFor(i);
      final up = close >= open;
      final color = up ? _upColor : _downColor;
      final paint = Paint()..color = color..strokeWidth = math.max(1.4, candleWidth * 0.16)..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, yFor(low)), Offset(x, yFor(high)), paint);
      final yOpen = yFor(open);
      final yClose = yFor(close);
      final bodyTop = math.min(yOpen, yClose);
      final bodyBottom = math.max(yOpen, yClose);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - candleWidth / 2, bodyTop, candleWidth, math.max(bodyBottom - bodyTop, 2.0)),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, Paint()..color = color.withOpacity(up ? 0.95 : 0.86));
    }

    canvas.save();
    canvas.clipRect(chart);
    final overlayMin = minY - (maxY - minY) * 0.25;
    final overlayMax = maxY + (maxY - minY) * 0.25;

    if (showBollinger) {
      _drawSeries(canvas, bb.map((r) => r[0]).toList(), xFor, yFor, _bbUpperColor, 1.5, dashed: false, minValue: overlayMin, maxValue: overlayMax);
      _drawSeries(canvas, bb.map((r) => r[1]).toList(), xFor, yFor, _emaColor.withOpacity(0.78), 1.2, dashed: false, minValue: overlayMin, maxValue: overlayMax);
      _drawSeries(canvas, bb.map((r) => r[2]).toList(), xFor, yFor, _bbLowerColor, 1.5, dashed: false, minValue: overlayMin, maxValue: overlayMax);
    }

    if (showMovingAverage) {
      _drawSeries(canvas, sma, xFor, yFor, _smaColor, 2.0, minValue: overlayMin, maxValue: overlayMax);
      _drawSeries(canvas, ema, xFor, yFor, _emaColor, 2.0, minValue: overlayMin, maxValue: overlayMax);
    }
    canvas.restore();

    final currentY = yFor(currentPrice);
    _drawDashedLine(canvas, Offset(chart.left, currentY), Offset(chart.right, currentY), Paint()..color = _upColor.withOpacity(0.42)..strokeWidth = 1);
    _drawPriceBadge(canvas, Offset(chart.right + 8, currentY), currentPrice);

    final bottomPaint = Paint()..color = Colors.white.withOpacity(0.10)..strokeWidth = 1;
    canvas.drawLine(Offset(chart.left, chart.bottom + 14), Offset(chart.right, chart.bottom + 14), bottomPaint);
    for (var i = 0; i <= 4; i++) {
      final index = ((candles.length - 1) * i / 4).round().clamp(0, candles.length - 1).toInt();
      final x = xFor(index);
      _drawCenteredText(canvas, _dateLabel(candles[index], selectedPeriod), Offset(x, chart.bottom + 22), const Color(0xFF9CA3B7), 11, FontWeight.w700);
    }
  }

  void _drawSeries(
    Canvas canvas,
    List<double> values,
    double Function(int) xFor,
    double Function(double) yFor,
    Color color,
    double width, {
    bool dashed = false,
    double? minValue,
    double? maxValue,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final segments = <List<Offset>>[];
    var current = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final visible = v > 0 && (minValue == null || v >= minValue) && (maxValue == null || v <= maxValue);
      if (!visible) {
        if (current.length > 1) segments.add(current);
        current = <Offset>[];
        continue;
      }
      current.add(Offset(xFor(i), yFor(v)));
    }
    if (current.length > 1) segments.add(current);

    for (final points in segments) {
      if (dashed) {
        for (var i = 1; i < points.length; i++) {
          _drawDashedLine(canvas, points[i - 1], points[i], paint, dash: 7, gap: 5);
        }
      } else {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (var i = 1; i < points.length; i++) {
          path.lineTo(points[i].dx, points[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint, {double dash = 6, double gap = 6}) {
    final total = (end - start).distance;
    if (total == 0) return;
    final direction = (end - start) / total;
    var distance = 0.0;
    while (distance < total) {
      final from = start + direction * distance;
      final to = start + direction * math.min(distance + dash, total);
      canvas.drawLine(from, to, paint);
      distance += dash + gap;
    }
  }

  void _drawPriceBadge(Canvas canvas, Offset anchor, double value) {
    final text = value.toStringAsFixed(2);
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(anchor.dx, anchor.dy - 16, tp.width + 18, 32),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xFF20C997));
    tp.paint(canvas, Offset(anchor.dx + 9, anchor.dy - tp.height / 2));
  }

  void _drawText(Canvas canvas, String text, Offset offset, Color color, double fontSize, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  void _drawCenteredText(Canvas canvas, String text, Offset center, Color color, double fontSize, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy));
  }

  String _axisPrice(double value) {
    if (value.abs() >= 1000) return value.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
    return value.toStringAsFixed(2);
  }

  String _dateLabel(Map<String, dynamic> candle, String period) {
    final raw = candle['recorded_at']?.toString();
    final dt = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    const months = ['янв.', 'фев.', 'мар.', 'апр.', 'май', 'июн.', 'июл.', 'авг.', 'сен.', 'окт.', 'ноя.', 'дек.'];
    if (period == '1D') return '${dt.hour.toString().padLeft(2, '0')}:00';
    if (period == '1W' || period == '1M') return '${dt.day} ${months[dt.month - 1]}';
    return '${months[dt.month - 1]} ${dt.year.toString().substring(2)}';
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.currentPrice != currentPrice ||
        oldDelegate.showMovingAverage != showMovingAverage ||
        oldDelegate.showBollinger != showBollinger ||
        oldDelegate.selectedPeriod != selectedPeriod;
  }
}


class _MiniRsiPanel extends StatelessWidget {
  const _MiniRsiPanel({required this.closes});
  final List<double> closes;

  @override
  Widget build(BuildContext context) {
    final values = _rsiSeries(closes, period: 14);
    if (values.length < 2) return const SizedBox.shrink();
    final spots = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }

    return _MiniPanelShell(
      title: 'RSI',
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: math.max(values.length - 1, 1).toDouble(),
          minY: 0,
          maxY: 100,
          lineTouchData: const LineTouchData(enabled: false),
          gridData: FlGridData(
            show: true,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(0.06), strokeWidth: 1),
            drawVerticalLine: false,
          ),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(horizontalLines: [
            HorizontalLine(y: 70, color: Colors.redAccent.withOpacity(0.55), strokeWidth: 1, dashArray: [4, 4]),
            HorizontalLine(y: 30, color: const Color(0xFF35E3C3).withOpacity(0.55), strokeWidth: 1, dashArray: [4, 4]),
          ]),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.18,
              barWidth: 2,
              color: const Color(0xFFA970FF),
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMacdPanel extends StatelessWidget {
  const _MiniMacdPanel({required this.closes});
  final List<double> closes;

  @override
  Widget build(BuildContext context) {
    final values = _macdHistogramSeries(closes);
    if (values.length < 2) return const SizedBox.shrink();
    final spots = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final pad = math.max((maxValue - minValue).abs() * 0.2, 0.01);

    return _MiniPanelShell(
      title: 'MACD histogram',
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: math.max(values.length - 1, 1).toDouble(),
          minY: minValue - pad,
          maxY: maxValue + pad,
          lineTouchData: const LineTouchData(enabled: false),
          gridData: FlGridData(
            show: true,
            horizontalInterval: math.max((maxValue - minValue).abs() / 2, 0.01),
            getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(0.06), strokeWidth: 1),
            drawVerticalLine: false,
          ),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(horizontalLines: [
            HorizontalLine(y: 0, color: Colors.white.withOpacity(0.30), strokeWidth: 1),
          ]),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.12,
              barWidth: 2,
              color: values.last >= 0 ? const Color(0xFF35E3C3) : Colors.redAccent,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPanelShell extends StatelessWidget {
  const _MiniPanelShell({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF9CA3B7), fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _PerformanceItem {
  const _PerformanceItem(this.label, this.value);
  final String label;
  final double value;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 18, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Color(0xFF9CA3B7), fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _RsiCard extends StatelessWidget {
  const _RsiCard({required this.value, required this.signal, required this.selected, required this.onTap});
  final double value;
  final dynamic signal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch ('$signal') {
      'overbought' => 'Перекуплен',
      'oversold' => 'Перепродан',
      'moderate_buying' => 'Бычий',
      _ => 'Нейтрально',
    };
    return _IndicatorShell(
      title: 'RSI (14)',
      selected: selected,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(value == 0 ? '—' : value.toStringAsFixed(2), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFA970FF))),
          const SizedBox(width: 10),
          _SignalPill(label: label, color: const Color(0xFF20C997)),
        ]),
        const SizedBox(height: 18),
        _RsiGauge(value: value),
        const Spacer(),
        Text(_rsiDescription(signal), style: _captionStyle(context)),
      ]),
    );
  }

  String _rsiDescription(dynamic signal) {
    return switch ('$signal') {
      'overbought' => 'Актив может быть перекуплен.',
      'oversold' => 'Актив может быть перепродан.',
      'moderate_buying' => 'RSI выше 60 — покупатели контролируют рынок.',
      _ => 'RSI находится в нейтральной зоне.',
    };
  }
}

class _BollingerCard extends StatelessWidget {
  const _BollingerCard({required this.bands, required this.selected, required this.onTap});
  final Map<String, dynamic> bands;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _IndicatorShell(
      title: 'Полосы Боллинджера',
      selected: selected,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _MetricLine('Верхняя', _fmt(bands['upper']), const Color(0xFF4B8BFF)),
        _MetricLine('Средняя', _fmt(bands['middle']), const Color(0xFFFFB84D)),
        _MetricLine('Нижняя', _fmt(bands['lower']), const Color(0xFFA970FF)),
        const Spacer(),
        Text('Показывают диапазон волатильности цены.', style: _captionStyle(context)),
      ]),
    );
  }
}

class _MacdCard extends StatelessWidget {
  const _MacdCard({required this.macd, required this.selected, required this.onTap});
  final Map<String, dynamic> macd;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trend = '${macd['trend']}' == 'bullish' ? 'Бычий' : '${macd['trend']}' == 'bearish' ? 'Медвежий' : 'Нейтральный';
    final value = _asDoubleStatic(macd['macd']);
    return _IndicatorShell(
      title: 'MACD (12, 26, 9)',
      selected: selected,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(value == 0 ? '—' : value.toStringAsFixed(2), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: value >= 0 ? AppTheme.successDark : Colors.redAccent)),
          const SizedBox(width: 10),
          _SignalPill(label: trend, color: value >= 0 ? AppTheme.successDark : Colors.redAccent),
        ]),
        const SizedBox(height: 10),
        _MetricLine('Сигнальная', _fmt(macd['signal']), const Color(0xFFFFB84D)),
        _MetricLine('Гистограмма', _fmt(macd['histogram']), value >= 0 ? AppTheme.successDark : Colors.redAccent),
        const Spacer(),
        Text(value >= 0 ? 'MACD выше сигнальной линии.' : 'MACD ниже сигнальной линии.', style: _captionStyle(context)),
      ]),
    );
  }
}

class _MovingAverageCard extends StatelessWidget {
  const _MovingAverageCard({required this.ma, required this.selected, required this.onTap});
  final Map<String, dynamic> ma;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trend = '${ma['trend']}' == 'uptrend' ? 'Восходящий' : '${ma['trend']}' == 'downtrend' ? 'Нисходящий' : 'Нейтральный';
    return _IndicatorShell(
      title: 'Скользящие средние',
      selected: selected,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _MetricLine('SMA (20)', _fmt(ma['sma_20']), const Color(0xFFFFB84D)),
        _MetricLine('EMA (50)', _fmt(ma['ema_50']), const Color(0xFF4B8BFF)),
        const Spacer(),
        Row(children: [
          Text('Тренд', style: _captionStyle(context)),
          const SizedBox(width: 8),
          _SignalPill(label: trend, color: trend == 'Восходящий' ? AppTheme.successDark : Colors.redAccent),
        ]),
      ]),
    );
  }
}

class _IndicatorShell extends StatelessWidget {
  const _IndicatorShell({required this.title, required this.child, required this.selected, required this.onTap});
  final String title;
  final Widget child;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1A1F2B) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? const Color(0xFF5865D9) : (dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04)),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(dark ? 0.24 : 0.06), blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
            Icon(selected ? Icons.visibility : Icons.visibility_off_outlined, size: 18, color: selected ? const Color(0xFF5865D9) : Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.55)),
          ]),
          const SizedBox(height: 12),
          Expanded(child: child),
        ]),
      ),
    );
  }
}

class _RsiGauge extends StatelessWidget {
  const _RsiGauge({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final clamped = (value / 100).clamp(0.0, 1.0).toDouble();
    return Column(children: [
      LayoutBuilder(builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(height: 7, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.25), borderRadius: BorderRadius.circular(99))),
            FractionallySizedBox(
              widthFactor: clamped,
              child: Container(height: 7, decoration: BoxDecoration(color: const Color(0xFFA970FF), borderRadius: BorderRadius.circular(99))),
            ),
            Positioned(
              left: (constraints.maxWidth * clamped - 5).clamp(0.0, constraints.maxWidth - 10).toDouble(),
              top: -3,
              child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            ),
          ],
        );
      }),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('0', style: _captionStyle(context)),
        Text('30', style: _captionStyle(context)),
        Text('70', style: _captionStyle(context)),
        Text('100', style: _captionStyle(context)),
      ]),
    ]);
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.72), fontWeight: FontWeight.w700))),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _SignalPill extends StatelessWidget {
  const _SignalPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.16), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

TextStyle _captionStyle(BuildContext context) {
  return TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.58), fontSize: 12.5, height: 1.35);
}

double _open(Map<String, dynamic> candle) => ((candle['open_price'] ?? candle['open'] ?? candle['close_price'] ?? candle['close'] ?? 0) as num).toDouble();
double _high(Map<String, dynamic> candle) => ((candle['high_price'] ?? candle['high'] ?? candle['close_price'] ?? candle['close'] ?? 0) as num).toDouble();
double _low(Map<String, dynamic> candle) => ((candle['low_price'] ?? candle['low'] ?? candle['close_price'] ?? candle['close'] ?? 0) as num).toDouble();
double _close(Map<String, dynamic> candle) => ((candle['close_price'] ?? candle['close'] ?? 0) as num).toDouble();

double _asDoubleStatic(dynamic v) => v is num ? v.toDouble() : 0;

String _fmt(dynamic v) => v is num && v != 0 ? v.toStringAsFixed(2) : '—';


List<double> _movingAverageValues(List<double> values, {required int period}) {
  if (values.isEmpty) return [];
  final safePeriod = period.clamp(2, math.max(2, values.length)).toInt();
  final out = <double>[];
  for (var i = 0; i < values.length; i++) {
    final from = math.max(0, i - safePeriod + 1);
    final window = values.sublist(from, i + 1);
    out.add(window.reduce((a, b) => a + b) / window.length);
  }
  return out;
}

List<List<double>> _bollingerSeries(List<double> values, {required int period, required double factor}) {
  if (values.isEmpty) return [];
  final safePeriod = period.clamp(2, math.max(2, values.length)).toInt();
  final out = <List<double>>[];
  for (var i = 0; i < values.length; i++) {
    final from = math.max(0, i - safePeriod + 1);
    final window = values.sublist(from, i + 1);
    final mean = window.reduce((a, b) => a + b) / window.length;
    final variance = window.map((v) => math.pow(v - mean, 2).toDouble()).reduce((a, b) => a + b) / window.length;
    final sd = math.sqrt(variance);
    out.add([mean + factor * sd, mean, math.max(0.0, mean - factor * sd)]);
  }
  return out;
}

List<FlSpot> _movingAverageSpots(List<double> values, {required int period}) {
  if (values.length < 2) return [];
  final safePeriod = period.clamp(2, values.length).toInt();
  final spots = <FlSpot>[];
  for (var i = 0; i < values.length; i++) {
    final from = math.max(0, i - safePeriod + 1);
    final window = values.sublist(from, i + 1);
    final avg = window.reduce((a, b) => a + b) / window.length;
    spots.add(FlSpot(i.toDouble(), avg));
  }
  return spots;
}


List<FlSpot> _emaSpots(List<double> values, {required int period}) {
  if (values.length < 2) return [];
  final safePeriod = period.clamp(2, values.length).toInt();
  final k = 2 / (safePeriod + 1);
  var ema = values.first;
  final spots = <FlSpot>[];
  for (var i = 0; i < values.length; i++) {
    ema = i == 0 ? values[i] : values[i] * k + ema * (1 - k);
    spots.add(FlSpot(i.toDouble(), ema));
  }
  return spots;
}

List<double> _emaValues(List<double> values, {required int period}) {
  if (values.isEmpty) return [];
  final safePeriod = period.clamp(2, math.max(2, values.length)).toInt();
  final k = 2 / (safePeriod + 1);
  var ema = values.first;
  final result = <double>[];
  for (var i = 0; i < values.length; i++) {
    ema = i == 0 ? values[i] : values[i] * k + ema * (1 - k);
    result.add(ema);
  }
  return result;
}

List<double> _rsiSeries(List<double> values, {required int period}) {
  if (values.length < 2) return [];
  final result = <double>[];
  for (var i = 0; i < values.length; i++) {
    final from = math.max(1, i - period + 1);
    var gain = 0.0;
    var loss = 0.0;
    var count = 0;
    for (var j = from; j <= i; j++) {
      final diff = values[j] - values[j - 1];
      if (diff >= 0) {
        gain += diff;
      } else {
        loss += diff.abs();
      }
      count++;
    }
    if (count == 0) {
      result.add(50);
      continue;
    }
    final avgGain = gain / count;
    final avgLoss = loss / count;
    if (avgLoss == 0) {
      result.add(avgGain == 0 ? 50 : 100);
    } else {
      final rs = avgGain / avgLoss;
      result.add(100 - (100 / (1 + rs)));
    }
  }
  return result;
}

List<double> _macdHistogramSeries(List<double> values) {
  if (values.length < 2) return [];
  final ema12 = _emaValues(values, period: 12);
  final ema26 = _emaValues(values, period: 26);
  final macd = <double>[];
  for (var i = 0; i < values.length; i++) {
    macd.add(ema12[i] - ema26[i]);
  }
  final signal = _emaValues(macd, period: 9);
  final histogram = <double>[];
  for (var i = 0; i < macd.length; i++) {
    histogram.add(macd[i] - signal[i]);
  }
  return histogram;
}
