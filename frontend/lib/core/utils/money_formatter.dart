String formatMoney(num? value, {String currency = 'USD', int fractionDigits = 2}) {
  final amount = (value ?? 0).toDouble();
  final code = currency.toUpperCase();
  final formatted = amount.toStringAsFixed(fractionDigits);
  switch (code) {
    case 'RUB':
      return '$formatted ₽';
    case 'USD':
      return '\$$formatted';
    default:
      return '$formatted $code';
  }
}

String currencySymbol(String currency) {
  switch (currency.toUpperCase()) {
    case 'RUB':
      return '₽';
    case 'USD':
      return '\$';
    default:
      return currency.toUpperCase();
  }
}
