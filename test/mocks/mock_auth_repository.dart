import 'dart:async';
import 'package:ajra/core/security/roles_and_permissions.dart';
import 'package:ajra/features/auth/models/app_user.dart';
import 'package:ajra/features/auth/repositories/auth_repository.dart';

class MockAuthRepository implements BaseAuthRepository {
  AppUser? _user;
  final _controller = StreamController<AppUser?>.broadcast();

  MockAuthRepository({AppUser? initialUser}) : _user = initialUser;

  @override
  AppUser? get currentUser => _user;

  @override
  bool get isPasswordProviderLinked => _user?.hasPassword ?? false;

  @override
  Stream<AppUser?> get userStream => _controller.stream;

  @override
  Future<AppUser?> signInWithGoogle() async {
    _user = AppUser(
      uid: 'mock-user-1',
      email: 'membre.test@ajra.org',
      displayName: 'Jean Luc Test',
      role: UserRole.admin,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _controller.add(_user);
    return _user;
  }

  @override
  Future<AppUser?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (_user == null || _user!.email.toLowerCase() != email.trim().toLowerCase()) {
      throw Exception('Ce compte n\'existe pas sur le serveur AJRA.');
    }
    _user = _user!.copyWith(
      hasPassword: true,
      lastLoginAt: DateTime.now(),
    );
    _controller.add(_user);
    return _user;
  }

  @override
  Future<void> createOrUpdatePassword({
    required String newPassword,
    String? currentPassword,
  }) async {
    if (newPassword.length < 6) {
      throw Exception('Le mot de passe doit contenir au moins 6 caractères.');
    }
    if (_user != null) {
      _user = _user!.copyWith(
        hasPassword: true,
        passwordUpdatedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _controller.add(_user);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<AppUser?> signInAsDemoUser({UserRole role = UserRole.admin}) async {
    _user = AppUser(
      uid: 'mock-demo-user',
      email: 'demo@ajra.org',
      displayName: 'Admin Test AJRA',
      role: role,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _controller.add(_user);
    return _user;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<void> reloadUser() async {}

  @override
  Future<void> deleteAccount() async {
    await signOut();
  }

  @override
  Future<void> deleteUserAccountAndDataByAdmin({
    required String targetUserId,
    required String targetEmail,
    required String adminUserId,
    required String adminName,
  }) async {
    // Mock implementation for unit tests
  }
}
