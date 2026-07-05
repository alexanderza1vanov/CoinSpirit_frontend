import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class PriceChangeText extends StatelessWidget {
  const PriceChangeText({super.key, required this.percent, this.fontSize = 13});

  final num? percent;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final value = percent;
    if (value == null) return const SizedBox.shrink();

    final isUp = value >= 0;
    final color = isUp ? AppTheme.success : Colors.red;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          size: fontSize + 6,
          color: color,
        ),
        Text(
          '${value.abs().toStringAsFixed(2)}%',
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
