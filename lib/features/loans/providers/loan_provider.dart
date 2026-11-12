import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/money.dart';
import '../models/member_loan.dart';
import '../repositories/loan_repository.dart';

final loanRepoProvider = Provider<BaseLoanRepository>((ref) {
  return FirestoreLoanRepository();
});

final loansStreamProvider = StreamProvider<List<MemberLoan>>((ref) {
  return ref.watch(loanRepoProvider).watchLoans();
});

class LoanStats {
  final Money totalLoaned;
  final Money totalRepaid;
  final Money totalOutstanding;
  final int activeLoansCount;
  final int overdueLoansCount;

  const LoanStats({
    required this.totalLoaned,
    required this.totalRepaid,
    required this.totalOutstanding,
    required this.activeLoansCount,
    required this.overdueLoansCount,
  });
}

final loanStatsProvider = Provider<LoanStats>((ref) {
  final loansAsync = ref.watch(loansStreamProvider);
  final loans = loansAsync.value ?? [];

  int loanedCents = 0;
  int repaidCents = 0;
  int outstandingCents = 0;
  int activeCount = 0;
  int overdueCount = 0;

  for (final l in loans) {
    if (l.status != LoanStatus.rejected) {
      loanedCents += l.amount.cents;
      repaidCents += l.amountRepaid.cents;

      if (l.status == LoanStatus.approved || l.status == LoanStatus.overdue) {
        outstandingCents += l.remainingAmount.cents;
        activeCount++;
      }

      if (l.isOverdueCalculated) {
        overdueCount++;
      }
    }
  }

  return LoanStats(
    totalLoaned: Money.fromCents(loanedCents),
    totalRepaid: Money.fromCents(repaidCents),
    totalOutstanding: Money.fromCents(outstandingCents),
    activeLoansCount: activeCount,
    overdueLoansCount: overdueCount,
  );
});
