import 'package:flutter_test/flutter_test.dart';
import 'package:ajra/core/utils/money.dart';
import 'package:ajra/features/dues/models/monthly_due.dart';

void main() {
  group('MonthlyDue Model Tests', () {
    test('Calculates remaining amount correctly with partial payments', () {
      final due = MonthlyDue(
        id: 'user_1_2026_03',
        userId: 'user_1',
        memberNumber: 'AJRA-2026-001',
        memberName: 'Jean',
        periodYear: 2026,
        periodMonth: 3,
        periodLabel: 'Mars 2026',
        amount: Money.fromRupees(150),
        amountPaid: Money.fromRupees(50),
        status: DueStatus.partiallyPaid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(due.remainingAmount.inRupees, 100.0);
      expect(due.status.isPartiallyPaid, isTrue);
    });

    test('Paid due has 0 remaining amount', () {
      final paidDue = MonthlyDue(
        id: 'user_1_2026_01',
        userId: 'user_1',
        memberNumber: 'AJRA-2026-001',
        memberName: 'Jean',
        periodYear: 2026,
        periodMonth: 1,
        periodLabel: 'Janvier 2026',
        amount: Money.fromRupees(150),
        amountPaid: Money.fromRupees(150),
        status: DueStatus.paid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(paidDue.remainingAmount.isZero, isTrue);
      expect(paidDue.status.isPaid, isTrue);
    });
  });
}
