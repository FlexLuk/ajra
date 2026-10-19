import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../models/app_user.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider = Provider<BaseAuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.userStream;
});

final currentUserProvider = Provider<AppUser?>((ref) {
  final authAsync = ref.watch(authStateProvider);
  return authAsync.value ?? ref.watch(authRepositoryProvider).currentUser;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

final userRoleProvider = Provider<UserRole>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.role ?? UserRole.member;
});

final hasPermissionProvider = Provider.family<bool, String>((ref, permission) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  return user.hasPermission(permission);
});
