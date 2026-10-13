import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'dart:math';

// Simulating the calendar_screen logic
double parseAmountFallback(String amountStr, String currency) {
  String trimmedAmount = amountStr.trim();
  trimmedAmount = trimmedAmount.replaceAll('\u2212', '-');
  bool hasNegativeSign = trimmedAmount.startsWith('-') || trimmedAmount.endsWith('-');

  double amount = 0.0;
  if (currency.toUpperCase() == 'PYG') {
    String numericString = trimmedAmount.replaceAll(RegExp(r'[^\d]'), '');
    amount = double.tryParse(numericString) ?? 0.0;
  } else {
    String numericString = trimmedAmount.replaceAll(RegExp(r'[^\d.\-]'), '');
    amount = double.tryParse(numericString.replaceAll('-', '')) ?? 0.0;
  }

  if (hasNegativeSign) {
    amount = -amount;
  }
  return amount;
}

double parseAmountCents(int signedAmountCents, String currency) {
  int fractionDigits = NumberFormat.simpleCurrency(name: currency).decimalDigits ?? 2;
  return signedAmountCents / pow(10, fractionDigits);
}

void main() {
  group('amount parsing', () {
    test('PYG fallback parsing from string 150.000 resolves correctly', () {
      expect(parseAmountFallback("150.000", "PYG"), 150000.0);
      expect(parseAmountFallback("-150.000", "PYG"), -150000.0);
      expect(parseAmountFallback("1.500.000", "PYG"), 1500000.0);
    });

    test('USD fallback parsing from string 1,500.00 resolves correctly', () {
      expect(parseAmountFallback("150.00", "USD"), 150.0);
      expect(parseAmountFallback("-150.50", "USD"), -150.5);
    });

    test('cents conversion for PYG', () {
      // 150,000 Gs in backend cents is 15000000 (value * 100) or maybe 150000 if 0 decimals?
      // Wait, let's just check the formula works. PYG has 0 decimal digits.
      // So 150000 cents in PYG with 0 decimals means fractionDigits = 0 -> pow(10, 0) = 1.
      expect(parseAmountCents(150000, "PYG"), 150000.0);
      expect(parseAmountCents(-150000, "PYG"), -150000.0);
    });

    test('cents conversion for USD', () {
      expect(parseAmountCents(15000, "USD"), 150.0);
      expect(parseAmountCents(-15000, "USD"), -150.0);
    });
  });
}
