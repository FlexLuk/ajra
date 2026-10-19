import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

/// Représentation monétaire immuable et exacte en Roupie Mauricienne (MUR).
/// Stockée en sous-unités (centimes entiers) pour bannir toute imprécision liée aux nombres flottants.
class Money implements Comparable<Money> {
  final int cents;
  final String currency;

  const Money({
    required this.cents,
    this.currency = AppConstants.currencyCode,
  });

  const Money.zero([String currency = AppConstants.currencyCode])
      : this(cents: 0, currency: currency);

  factory Money.fromRupees(num rupees, [String currency = AppConstants.currencyCode]) {
    final int roundedCents = (rupees * 100).round();
    return Money(cents: roundedCents, currency: currency);
  }

  factory Money.fromCents(int cents, [String currency = AppConstants.currencyCode]) {
    return Money(cents: cents, currency: currency);
  }

  factory Money.fromJson(Map<String, dynamic> json) {
    return Money(
      cents: (json['cents'] as num?)?.toInt() ?? 0,
      currency: (json['currency'] as String?) ?? AppConstants.currencyCode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cents': cents,
      'currency': currency,
      'formatted': toFormattedString(),
      'amount': inRupees,
    };
  }

  double get inRupees => cents / 100.0;

  bool get isZero => cents == 0;
  bool get isPositive => cents > 0;
  bool get isNegative => cents < 0;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(cents: cents + other.cents, currency: currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(cents: cents - other.cents, currency: currency);
  }

  Money operator *(num factor) {
    return Money(cents: (cents * factor).round(), currency: currency);
  }

  Money operator /(num divisor) {
    if (divisor == 0) {
      throw ArgumentError('Diviseur impossible par zéro');
    }
    return Money(cents: (cents / divisor).round(), currency: currency);
  }

  Money operator -() {
    return Money(cents: -cents, currency: currency);
  }

  bool operator <(Money other) {
    _assertSameCurrency(other);
    return cents < other.cents;
  }

  bool operator <=(Money other) {
    _assertSameCurrency(other);
    return cents <= other.cents;
  }

  bool operator >(Money other) {
    _assertSameCurrency(other);
    return cents > other.cents;
  }

  bool operator >=(Money other) {
    _assertSameCurrency(other);
    return cents >= other.cents;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Money && other.cents == cents && other.currency == currency;
  }

  @override
  int get hashCode => Object.hash(cents, currency);

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return cents.compareTo(other.cents);
  }

  void _assertSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError(
        'Devise incompatible: impossible d\'opérer entre $currency et ${other.currency}',
      );
    }
  }

  /// Format français lisible: ex: "1 250,50 Rs."
  String toFormattedString({bool includeSymbol = true}) {
    final NumberFormat formatter = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: includeSymbol ? AppConstants.currencySymbol : '',
      customPattern: includeSymbol ? '#,##0.00 \u00a4' : '#,##0.00',
    );
    return formatter.format(inRupees).trim();
  }

  /// Format compact pour les graphiques ou badges: ex: "1.2k Rs."
  String toCompactString() {
    if (cents.abs() >= 100000000) {
      final double millions = inRupees / 1000000;
      return '${millions.toStringAsFixed(1)}M ${AppConstants.currencySymbol}';
    } else if (cents.abs() >= 100000) {
      final double thousands = inRupees / 1000;
      return '${thousands.toStringAsFixed(1)}k ${AppConstants.currencySymbol}';
    }
    return toFormattedString();
  }

  @override
  String toString() => toFormattedString();
}
