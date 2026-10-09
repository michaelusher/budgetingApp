class Currency {
  final String code;
  final String symbol;
  final String name;
  const Currency(this.code, this.symbol, this.name);
}

const List<Currency> kCurrencies = [
  Currency('USD', '\$', 'US Dollar'),
  Currency('EUR', '€', 'Euro'),
  Currency('GBP', '£', 'British Pound'),
  Currency('JPY', '¥', 'Japanese Yen'),
  Currency('AUD', 'A\$', 'Australian Dollar'),
  Currency('CAD', 'C\$', 'Canadian Dollar'),
  Currency('INR', '₹', 'Indian Rupee'),
  Currency('CHF', 'CHF ', 'Swiss Franc'),
];

Currency currencyForCode(String code) => kCurrencies.firstWhere(
      (c) => c.code == code,
      orElse: () => kCurrencies.first,
    );

/// Active currency for the whole app. [formatCurrency] reads this when no
/// explicit symbol is passed; AppState keeps it in sync with the saved setting.
class AppCurrency {
  static String symbol = '\$';
}
