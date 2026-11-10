/// Shared currency -> symbol map, used by CurrencyFilter and any currency
/// picker so the mapping lives in exactly one place.
String currencySymbol(String currency) {
  switch (currency.toUpperCase()) {
    case 'USD':
      return '\$';
    case 'TWD':
      return 'NT\$';
    case 'BTC':
      return '₿';
    case 'ETH':
      return 'Ξ';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'JPY':
      return '¥';
    case 'CNY':
      return '¥';
    default:
      return '';
  }
}
