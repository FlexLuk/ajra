import 'package:flutter_test/flutter_test.dart';
import 'package:ajra/core/utils/money.dart';
import 'package:ajra/features/loans/models/member_loan.dart';

void main() {
  group('MemberLoan Model Tests', () {
    test('Calculates remaining amount correctly', () {
      final loan = MemberLoan(
        id: 'loan-test-1',
        borrowerUserId: 'user-1',
        borrowerName: 'Jean Luc',
        amount: Money.fromRupees(5000),
        amountRepaid: Money.fromRupees(2000),
        purpose: 'Frais médicaux',
        requestedAt: DateTime.now().subtract(const Duration(days: 10)),
        dueDate: DateTime.now().add(const Duration(days: 30)),
        status: LoanStatus.approved,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        updatedAt: DateTime.now().subtract(const Duration(days: 10)),
      );

      expect(loan.remainingAmount, equals(Money.fromRupees(3000)));
      expect(loan.repaymentProgress, closeTo(0.4, 0.001));
      expect(loan.isOverdueCalculated, isFalse);
    });

    test('Fully repaid loan has 0 remaining amount and 100% progress', () {
      final loan = MemberLoan(
        id: 'loan-test-2',
        borrowerUserId: 'user-2',
        borrowerName: 'Aina',
        amount: Money.fromRupees(3000),
        amountRepaid: Money.fromRupees(3000),
        purpose: 'Transport',
        requestedAt: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 2, 1),
        status: LoanStatus.repaid,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 2, 1),
      );

      expect(loan.remainingAmount, equals(const Money.zero()));
      expect(loan.repaymentProgress, equals(1.0));
      expect(loan.isOverdueCalculated, isFalse);
    });

    test('Identifies overdue loan correctly when dueDate is past and balance remains', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 10));
      final overdueLoan = MemberLoan(
        id: 'loan-test-3',
        borrowerUserId: 'user-3',
        borrowerName: 'Hery',
        amount: Money.fromRupees(2500),
        amountRepaid: Money.fromRupees(500),
        purpose: 'Loyer',
        requestedAt: pastDate.subtract(const Duration(days: 30)),
        dueDate: pastDate,
        status: LoanStatus.approved,
        createdAt: pastDate.subtract(const Duration(days: 30)),
        updatedAt: pastDate,
      );

      expect(overdueLoan.remainingAmount, equals(Money.fromRupees(2000)));
      expect(overdueLoan.isOverdueCalculated, isTrue);
    });

    test('Serializes to and from JSON correctly', () {
      final loan = MemberLoan(
        id: 'loan-json-1',
        borrowerUserId: 'u123',
        borrowerName: 'Soa',
        borrowerPhone: '+230 5123 4567',
        amount: Money.fromRupees(4000),
        amountRepaid: Money.fromRupees(1000),
        purpose: 'Caution',
        requestedAt: DateTime(2026, 3, 1),
        dueDate: DateTime(2026, 5, 1),
        status: LoanStatus.approved,
        notes: '2 versements prévus',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      final json = loan.toJson();
      expect(json['amountCents'], equals(400000));
      expect(json['amountRepaidCents'], equals(100000));
      expect(json['status'], equals('approved'));

      final restored = MemberLoan.fromJson(json, 'loan-json-1');
      expect(restored.borrowerName, equals('Soa'));
      expect(restored.amount, equals(Money.fromRupees(4000)));
      expect(restored.amountRepaid, equals(Money.fromRupees(1000)));
      expect(restored.remainingAmount, equals(Money.fromRupees(3000)));
    });
  });
}
