class Asset {
  const Asset({
    required this.id,
    required this.ticker,
    required this.name,
    required this.assetType,
    required this.marketType,
    required this.currencyCode,
    this.currentPrice,
    this.change24hPercent,
  });

  final String id;
  final String ticker;
  final String name;
  final String assetType;
  final String marketType;
  final String currencyCode;
  final num? currentPrice;
  final num? change24hPercent;

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'] as String,
      ticker: json['ticker'] as String,
      name: json['name'] as String,
      assetType: json['asset_type'] as String? ?? '',
      marketType: json['market_type'] as String? ?? '',
      currencyCode: json['currency_code'] as String? ?? 'USD',
      currentPrice: json['current_price'] as num?,
      change24hPercent: json['change_24h_percent'] as num?,
    );
  }
}
