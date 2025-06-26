class CurrencyConstants {
  static const Map<String, String> currencies = {
    'USD': '\$', // US Dollar
    'EUR': '€', // Euro
    'GBP': '£', // British Pound
    'INR': '₹', // Indian Rupee
    'NPR': 'रू', // Nepali Rupee
    'JPY': '¥', // Japanese Yen
    'CNY': '¥', // Chinese Yuan
    'AUD': 'A\$', // Australian Dollar
    'CAD': 'C\$', // Canadian Dollar
    'CHF': 'CHF', // Swiss Franc
    'HKD': 'HK\$', // Hong Kong Dollar
    'NZD': 'NZ\$', // New Zealand Dollar
    'SGD': 'S\$', // Singapore Dollar
    'AED': 'د.إ', // UAE Dirham
    'SAR': '﷼', // Saudi Riyal
    'KRW': '₩', // South Korean Won
    'RUB': '₽', // Russian Ruble
    'BRL': 'R\$', // Brazilian Real
    'MXN': 'Mex\$', // Mexican Peso
    'ZAR': 'R', // South African Rand
    'THB': '฿', // Thai Baht
  };

  // Get currency symbol from code
  static String getSymbol(String code) {
    return currencies[code] ?? code;
  }

  // Get formatted currency with both code and symbol
  static String getFormattedCurrency(String code) {
    final symbol = getSymbol(code);
    return '$code ($symbol)';
  }
}
