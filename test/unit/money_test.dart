import 'package:flutter_test/flutter_test.dart';
import 'package:ajra/core/utils/money.dart';

void main() {
  group('Money Class Tests', () {
    test('Stores and retrieves exact cents correctly', () {
      final money = Money.fromCents(125050);
      expect(money.cents, 125050);
      expect(money.inRupees, 1250.50);
      expect(money.currency, 'MUR');
    });

    test('Converts from rupees without floating point loss', () {
      final money = Money.fromRupees(150.75);
      expect(money.cents, 15075);
      expect(money.inRupees, 150.75);
    });

    test('Addition, subtraction and operations', () {
      final m1 = Money.fromRupees(100.50);
      final m2 = Money.fromRupees(50.25);

      final sum = m1 + m2;
      expect(sum.cents, 15075);
      expect(sum.inRupees, 150.75);

      final diff = m1 - m2;
      expect(diff.cents, 5025);
      expect(diff.inRupees, 50.25);

      final mult = m2 * 2;
      expect(mult.cents, 10050);

      final div = m1 / 2;
      expect(div.cents, 5025);
    });

    test('Comparisons work correctly', () {
      final low = Money.fromRupees(10);
      final high = Money.fromRupees(20);
      final equalLow = Money.fromRupees(10);

      expect(low < high, isTrue);
      expect(high > low, isTrue);
      expect(low == equalLow, isTrue);
      expect(low <= equalLow, isTrue);
    });

    test('Formats correctly according to French locale and Rs. symbol', () {
      final money = Money.fromRupees(1500.0);
      final formatted = money.toFormattedString();
      // Should contain 1 500,00 and Rs.
      expect(formatted.contains('1'), isTrue);
      expect(formatted.contains('500,00'), isTrue);
      expect(formatted.contains('Rs.'), isTrue);
    });

    test('JSON serialization & deserialization', () {
      final original = Money.fromRupees(350.25);
      final json = original.toJson();
      final restored = Money.fromJson(json);

      expect(restored.cents, original.cents);
      expect(restored.currency, original.currency);
    });
  });
}
