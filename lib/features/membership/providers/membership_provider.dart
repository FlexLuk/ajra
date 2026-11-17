import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/member_profile.dart';
import '../repositories/membership_repository.dart';

final membershipRepositoryProvider = Provider<BaseMembershipRepository>((ref) {
  return FirestoreMembershipRepository();
});

final currentMemberProfileProvider = StreamProvider<MemberProfile?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  return ref.watch(membershipRepositoryProvider).watchMemberProfile(user.uid);
});

class MemberSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  @override
  set state(String value) => super.state = value;
}
final memberSearchQueryProvider =
    NotifierProvider<MemberSearchQueryNotifier, String>(MemberSearchQueryNotifier.new);

class MemberStatusFilterNotifier extends Notifier<MembershipStatus?> {
  @override
  MembershipStatus? build() => null;
  @override
  set state(MembershipStatus? value) => super.state = value;
}
final memberStatusFilterProvider =
    NotifierProvider<MemberStatusFilterNotifier, MembershipStatus?>(MemberStatusFilterNotifier.new);

class MemberPermitFilterNotifier extends Notifier<PermitType?> {
  @override
  PermitType? build() => null;
  @override
  set state(PermitType? value) => super.state = value;
}
final memberPermitFilterProvider =
    NotifierProvider<MemberPermitFilterNotifier, PermitType?>(MemberPermitFilterNotifier.new);

final allMembersProvider = StreamProvider<List<MemberProfile>>((ref) {
  final repo = ref.watch(membershipRepositoryProvider);
  final searchQuery = ref.watch(memberSearchQueryProvider);
  final statusFilter = ref.watch(memberStatusFilterProvider);
  final permitFilter = ref.watch(memberPermitFilterProvider);

  return repo.watchAllMembers(
    searchQuery: searchQuery,
    statusFilter: statusFilter,
    permitFilter: permitFilter,
  );
});

final expiringPassportsProvider = FutureProvider<List<MemberProfile>>((ref) async {
  final repo = ref.watch(membershipRepositoryProvider);
  return repo.getExpiringPassports();
});

/// Détermine si l'utilisateur connecté est un membre pleinement validé et actif (ou admin/bureau)
final isMemberValidatedAndActiveProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  if (user.isAdmin || user.role == UserRole.bureau) return true;
  final memberAsync = ref.watch(currentMemberProfileProvider);
  final member = memberAsync.value;
  return member != null && member.status == MembershipStatus.active;
});
