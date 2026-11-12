import 'package:flutter_test/flutter_test.dart';
import 'package:ajra/core/utils/money.dart';
import 'package:ajra/features/events/models/event_transaction.dart';

void main() {
  group('Event Financial Calculation Tests', () {
    test('Calculates event total incomes, total expenses and net profit/loss accurately', () {
      final transactions = [
        EventTransaction(
          id: 'tx-1',
          eventId: 'event-flic',
          type: EventTransactionType.income,
          title: 'Cotisations 6 participants',
          amount: Money.fromRupees(3000),
          category: 'Cotisation Sortie',
          date: DateTime(2026, 4, 1),
          paymentMode: 'Juice MCB',
          recordedByUserId: 'u1',
          recordedByName: 'Trésorier',
          createdAt: DateTime(2026, 4, 1),
        ),
        EventTransaction(
          id: 'tx-2',
          eventId: 'event-flic',
          type: EventTransactionType.income,
          title: 'Don de soutien d\'un aîné',
          amount: Money.fromRupees(1500),
          category: 'Don & Sponsor',
          date: DateTime(2026, 4, 2),
          paymentMode: 'Espèces',
          recordedByUserId: 'u1',
          recordedByName: 'Trésorier',
          createdAt: DateTime(2026, 4, 2),
        ),
        EventTransaction(
          id: 'tx-3',
          eventId: 'event-flic',
          type: EventTransactionType.expense,
          title: 'Courses Supermarché Jumbo (viandes, barbecue)',
          amount: Money.fromRupees(2150),
          category: 'Nourriture & Courses',
          date: DateTime(2026, 4, 3),
          paymentMode: 'Espèces',
          recordedByUserId: 'u1',
          recordedByName: 'Logistique',
          receiptReference: 'Ticket #JMB-7721',
          createdAt: DateTime(2026, 4, 3),
        ),
        EventTransaction(
          id: 'tx-4',
          eventId: 'event-flic',
          type: EventTransactionType.expense,
          title: 'Boissons et eau',
          amount: Money.fromRupees(480),
          category: 'Boissons',
          date: DateTime(2026, 4, 3),
          paymentMode: 'Espèces',
          recordedByUserId: 'u1',
          recordedByName: 'Logistique',
          createdAt: DateTime(2026, 4, 3),
        ),
        EventTransaction(
          id: 'tx-5',
          eventId: 'event-flic',
          type: EventTransactionType.expense,
          title: 'Location Minibus 15 places',
          amount: Money.fromRupees(1500),
          category: 'Transport / Bus',
          date: DateTime(2026, 4, 2),
          paymentMode: 'Juice MCB',
          recordedByUserId: 'u1',
          recordedByName: 'Trésorier',
          createdAt: DateTime(2026, 4, 2),
        ),
      ];

      int incomeCents = 0;
      int expenseCents = 0;

      for (final tx in transactions) {
        if (tx.type == EventTransactionType.income) {
          incomeCents += tx.amount.cents;
        } else {
          expenseCents += tx.amount.cents;
        }
      }

      final totalIncome = Money.fromCents(incomeCents);
      final totalExpense = Money.fromCents(expenseCents);
      final netBalance = totalIncome - totalExpense;

      expect(totalIncome, equals(Money.fromRupees(4500)));
      expect(totalExpense, equals(Money.fromRupees(4130)));
      expect(netBalance, equals(Money.fromRupees(370)));
      expect(netBalance.isPositive, isTrue);
    });

    test('Serializes EventTransaction to/from JSON correctly', () {
      final tx = EventTransaction(
        id: 'tx-json-1',
        eventId: 'event-101',
        type: EventTransactionType.expense,
        title: 'Courses Super U Grand Baie',
        amount: Money.fromRupees(1850),
        category: 'Nourriture & Courses',
        date: DateTime(2026, 5, 10),
        paymentMode: 'Espèces',
        recordedByUserId: 'user-admin',
        recordedByName: 'Jean Luc',
        receiptReference: 'Ticket #SUPU-8829',
        notes: 'Achat de charbon et boissons',
        createdAt: DateTime(2026, 5, 10),
      );

      final json = tx.toJson();
      expect(json['eventId'], equals('event-101'));
      expect(json['type'], equals('expense'));
      expect(json['amountCents'], equals(185000));
      expect(json['receiptReference'], equals('Ticket #SUPU-8829'));

      final restored = EventTransaction.fromJson(json, 'tx-json-1');
      expect(restored.title, equals('Courses Super U Grand Baie'));
      expect(restored.type, equals(EventTransactionType.expense));
      expect(restored.amount, equals(Money.fromRupees(1850)));
      expect(restored.receiptReference, equals('Ticket #SUPU-8829'));
    });
  });
}
