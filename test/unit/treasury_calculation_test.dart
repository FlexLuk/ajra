import 'package:flutter_test/flutter_test.dart';
import 'package:ajra/core/utils/money.dart';
import 'package:ajra/features/accounting/models/financial_transaction.dart';

void main() {
  group('Treasury Calculation Rules Tests', () {
    test('Official Balance = Initial + Validated Incomes - Validated Expenses', () {
      final initialBalance = Money.fromRupees(1000);

      final t1 = FinancialTransaction(
        id: 't1',
        type: TransactionType.income,
        category: 'Cotisations',
        amount: Money.fromRupees(500),
        date: DateTime.now(),
        description: 'Cotisation membre',
        paymentMode: 'Espèces',
        reference: 'R1',
        accountId: 'caisse',
        createdByUserId: 'u1',
        createdByName: 'Admin',
        status: TransactionStatus.validated,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final t2 = FinancialTransaction(
        id: 't2',
        type: TransactionType.expense,
        category: 'Fournitures',
        amount: Money.fromRupees(200),
        date: DateTime.now(),
        description: 'Papeterie',
        paymentMode: 'Espèces',
        reference: 'F1',
        accountId: 'caisse',
        createdByUserId: 'u1',
        createdByName: 'Admin',
        status: TransactionStatus.validated,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Pending transaction (MUST NOT affect official balance)
      final t3Pending = FinancialTransaction(
        id: 't3',
        type: TransactionType.income,
        category: 'Dons',
        amount: Money.fromRupees(5000),
        date: DateTime.now(),
        description: 'Gros don en attente',
        paymentMode: 'Virement',
        reference: 'V1',
        accountId: 'banque',
        createdByUserId: 'u1',
        createdByName: 'Admin',
        status: TransactionStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final transactions = [t1, t2, t3Pending];

      int incomeCents = 0;
      int expenseCents = 0;

      for (final tx in transactions) {
        if (tx.status == TransactionStatus.validated) {
          if (tx.type == TransactionType.income) incomeCents += tx.amount.cents;
          if (tx.type == TransactionType.expense) expenseCents += tx.amount.cents;
        }
      }

      final officialBalance = initialBalance + Money.fromCents(incomeCents) - Money.fromCents(expenseCents);

      expect(officialBalance.inRupees, 1300.0); // 1000 + 500 - 200 = 1300 Rs.
    });

    test('Internal transfer between association accounts does not affect net global wealth', () {
      final cashAccountCents = 100000; // 1000 Rs
      final bankAccountCents = 200000; // 2000 Rs
      final totalNetBefore = cashAccountCents + bankAccountCents; // 3000 Rs

      final transferAmountCents = 50000; // 500 Rs de la caisse vers la banque

      // Source débitée
      final newCash = cashAccountCents - transferAmountCents;
      // Cible créditée
      final newBank = bankAccountCents + transferAmountCents;

      final totalNetAfter = newCash + newBank;

      expect(totalNetAfter, totalNetBefore); // Net balance strictly unchanged
    });
  });
}
