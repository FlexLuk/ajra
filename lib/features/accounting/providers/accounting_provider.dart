import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/financial_account.dart';
import '../models/financial_transaction.dart';
import '../repositories/accounting_repository.dart';

final accountingRepoProvider = Provider<BaseAccountingRepository>((ref) {
  return FirestoreAccountingRepository();
});

final accountsStreamProvider = StreamProvider<List<FinancialAccount>>((ref) {
  return ref.watch(accountingRepoProvider).watchAccounts();
});

final recentTransactionsProvider = StreamProvider<List<FinancialTransaction>>((ref) {
  return ref.watch(accountingRepoProvider).watchTransactions();
});
