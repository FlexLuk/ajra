import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../models/app_user.dart';

abstract class BaseAuthRepository {
  Stream<AppUser?> get userStream;
  AppUser? get currentUser;
  bool get isPasswordProviderLinked;
  Future<AppUser?> signInWithGoogle();
  Future<AppUser?> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
  Future<void> createOrUpdatePassword({
    required String newPassword,
    String? currentPassword,
  });
  Future<void> sendPasswordResetEmail(String email);
  Future<AppUser?> signInAsDemoUser({UserRole role = UserRole.admin});
  Future<void> signOut();
  Future<void> reloadUser();
  Future<void> deleteAccount();
  Future<void> deleteUserAccountAndDataByAdmin({
    required String targetUserId,
    required String targetEmail,
    required String adminUserId,
    required String adminName,
  });
}

class FirebaseAuthRepository implements BaseAuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  final _userController = StreamController<AppUser?>.broadcast();
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  AppUser? _currentUser;

  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn() {
    _init();
  }

  void _init() {
    try {
      _authSubscription = _auth.authStateChanges().listen((firebaseUser) {
        if (firebaseUser == null) {
          _userDocSubscription?.cancel();
          _currentUser = null;
          _userController.add(null);
        } else {
          _listenToUserDoc(firebaseUser.uid, firebaseUser);
        }
      }, onError: (e) {
        _userController.add(null);
      });
    } catch (e) {
      // Tolérance en cas de projet non connecté / hors-ligne
    }
  }

  void _listenToUserDoc(String uid, User firebaseUser) {
    _userDocSubscription?.cancel();
    _userDocSubscription = _firestore
        .collection(AppConstants.colUsers)
        .doc(uid)
        .snapshots()
        .listen((docSnapshot) async {
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = Map<String, dynamic>.from(docSnapshot.data()!);
        final isSuperAdmin = firebaseUser.email?.toLowerCase().trim() == 'heriniaina.luk@gmail.com';
        final hasPasswordInAuth = firebaseUser.providerData.any((p) => p.providerId == 'password');
        if (hasPasswordInAuth && data['hasPassword'] != true) {
          data['hasPassword'] = true;
        }
        if (isSuperAdmin && data['role'] != UserRole.admin.code) {
          data['role'] = UserRole.admin.code;
          _firestore.collection(AppConstants.colUsers).doc(uid).update({
            'role': UserRole.admin.code,
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }
        _currentUser = AppUser.fromJson(data, uid);
        _userController.add(_currentUser);
      } else {
        // RÈGLE STRICTE : Seule la création de compte via Google est acceptée sur le serveur
        final hasGoogleProvider = firebaseUser.providerData.any((p) => p.providerId == 'google.com');
        if (!hasGoogleProvider) {
          _currentUser = null;
          _userController.add(null);
          return;
        }

        // Le document n'existe pas encore: première connexion Google
        final isSuperAdmin = firebaseUser.email?.toLowerCase().trim() == 'heriniaina.luk@gmail.com';
        final newUser = AppUser(
          uid: uid,
          email: firebaseUser.email ?? '',
          displayName: firebaseUser.displayName ?? (isSuperAdmin ? 'Administrateur AJRA' : 'Membre AJRA'),
          photoUrl: firebaseUser.photoURL,
          role: isSuperAdmin ? UserRole.admin : UserRole.member,
          permissions: const [],
          isSuspended: false,
          hasPassword: firebaseUser.providerData.any((p) => p.providerId == 'password'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );

        await _firestore
            .collection(AppConstants.colUsers)
            .doc(uid)
            .set(newUser.toJson(), SetOptions(merge: true));

        _currentUser = newUser;
        _userController.add(_currentUser);
      }
    }, onError: (e) {
      _userController.add(null);
    });
  }

  @override
  Stream<AppUser?> get userStream async* {
    if (_currentUser != null) {
      yield _currentUser;
    }
    yield* _userController.stream;
  }

  @override
  AppUser? get currentUser => _currentUser;

  @override
  bool get isPasswordProviderLinked {
    if (_currentUser?.hasPassword == true) return true;
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      return user.providerData.any((p) => p.providerId == 'password');
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    try {
      UserCredential userCredential;
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null; // Utilisateur a annulé la sélection

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) return null;

      final docRef = _firestore.collection(AppConstants.colUsers).doc(firebaseUser.uid);
      final doc = await docRef.get();

      final isSuperAdmin = firebaseUser.email?.toLowerCase().trim() == 'heriniaina.luk@gmail.com';

      if (!doc.exists) {
        final newUser = AppUser(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          displayName: firebaseUser.displayName ?? (isSuperAdmin ? 'Administrateur AJRA' : 'Membre AJRA'),
          photoUrl: firebaseUser.photoURL,
          role: isSuperAdmin ? UserRole.admin : UserRole.member,
          permissions: const [],
          isSuspended: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );
        await docRef.set(newUser.toJson());
        _currentUser = newUser;
      } else {
        final currentRole = UserRole.fromCode(doc.data()?['role'] as String?);
        final shouldPromote = isSuperAdmin && currentRole != UserRole.admin;

        await docRef.update({
          'lastLoginAt': DateTime.now().toIso8601String(),
          if (firebaseUser.photoURL != null) 'photoUrl': firebaseUser.photoURL,
          if (shouldPromote) 'role': UserRole.admin.code,
        });

        final data = Map<String, dynamic>.from(doc.data()!);
        if (shouldPromote) data['role'] = UserRole.admin.code;
        _currentUser = AppUser.fromJson(data, firebaseUser.uid);
      }

      return _currentUser;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<AppUser?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw Exception('Veuillez renseigner votre identifiant (e-mail) et votre mot de passe.');
    }

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) return null;

      final docRef = _firestore.collection(AppConstants.colUsers).doc(firebaseUser.uid);
      final doc = await docRef.get();

      // RÈGLE MÉTIER STRICTE : Aucune création de compte par login/mot de passe.
      // Seuls les comptes déjà créés sur le serveur via Google sont acceptés.
      if (!doc.exists || doc.data() == null) {
        await signOut();
        throw Exception(
          'Ce compte n\'existe pas sur le serveur AJRA. Seule la connexion initiale avec Google est acceptée pour créer un profil.',
        );
      }

      final data = Map<String, dynamic>.from(doc.data()!);
      if (data['isSuspended'] == true) {
        await signOut();
        throw Exception('Votre compte a été suspendu. Veuillez contacter le bureau de l\'AJRA.');
      }

      final isSuperAdmin = firebaseUser.email?.toLowerCase().trim() == 'heriniaina.luk@gmail.com';
      final currentRole = UserRole.fromCode(data['role'] as String?);
      final shouldPromote = isSuperAdmin && currentRole != UserRole.admin;

      await docRef.update({
        'lastLoginAt': DateTime.now().toIso8601String(),
        'hasPassword': true,
        if (shouldPromote) 'role': UserRole.admin.code,
      });

      data['hasPassword'] = true;
      data['lastLoginAt'] = DateTime.now().toIso8601String();
      if (shouldPromote) data['role'] = UserRole.admin.code;

      _currentUser = AppUser.fromJson(data, firebaseUser.uid);
      _userController.add(_currentUser);
      return _currentUser;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception(
            'Aucun compte trouvé pour cet identifiant. Connectez-vous d\'abord avec Google puis créez votre mot de passe dans Mon Profil.',
          );
        case 'wrong-password':
        case 'invalid-credential':
          throw Exception(
            'Identifiant ou mot de passe incorrect. Si vous n\'avez pas encore défini de mot de passe, connectez-vous avec Google puis créez-le dans Mon Profil.',
          );
        case 'invalid-email':
          throw Exception('Le format de l\'adresse e-mail (identifiant) est invalide.');
        case 'user-disabled':
          throw Exception('Ce compte utilisateur a été désactivé.');
        case 'too-many-requests':
          throw Exception(
            'Trop de tentatives infructueuses. Veuillez patienter quelques minutes ou vous connecter avec Google.',
          );
        default:
          throw Exception('Erreur d\'authentification (${e.code}) : ${e.message ?? "Accès refusé"}');
      }
    }
  }

  Future<void> _reauthenticateWithGoogle(User user) async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      await user.reauthenticateWithPopup(googleProvider);
    } else {
      final GoogleSignInAccount? googleUser =
          await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Ré-authentification Google annulée.');
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    }
  }

  @override
  Future<void> createOrUpdatePassword({
    required String newPassword,
    String? currentPassword,
  }) async {
    if (newPassword.length < 6) {
      throw Exception('Le mot de passe doit contenir au moins 6 caractères.');
    }

    // Support du mode démo / test
    if (_currentUser?.uid == 'dev_demo_user' && _auth.currentUser == null) {
      _currentUser = _currentUser!.copyWith(
        hasPassword: true,
        passwordUpdatedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _userController.add(_currentUser);
      return;
    }

    final user = _auth.currentUser;
    if (user == null || user.email == null || user.email!.isEmpty) {
      throw Exception('Session utilisateur introuvable. Veuillez vous reconnecter avec Google.');
    }

    final email = user.email!.trim();
    final alreadyLinked = user.providerData.any((p) => p.providerId == 'password');

    Future<void> applyPasswordChange() async {
      if (currentPassword != null && currentPassword.isNotEmpty && alreadyLinked) {
        final cred = EmailAuthProvider.credential(email: email, password: currentPassword);
        await user.reauthenticateWithCredential(cred);
      }

      if (!alreadyLinked) {
        try {
          final cred = EmailAuthProvider.credential(email: email, password: newPassword);
          await user.linkWithCredential(cred);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'provider-already-linked' ||
              e.code == 'credential-already-in-use' ||
              e.code == 'email-already-in-use') {
            await user.updatePassword(newPassword);
          } else {
            rethrow;
          }
        }
      } else {
        await user.updatePassword(newPassword);
      }
    }

    try {
      await applyPasswordChange();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        try {
          await _reauthenticateWithGoogle(user);
          await applyPasswordChange();
        } catch (_) {
          // Fallback via Cloud Function serveur si la popup Google est bloquée
          try {
            final callable = FirebaseFunctions.instance.httpsCallable('setUserPassword');
            await callable.call({'newPassword': newPassword});
          } catch (fnErr) {
            throw Exception(
              'Pour votre sécurité, veuillez vous déconnecter puis vous reconnecter avec Google avant de définir votre mot de passe.',
            );
          }
        }
      } else if (e.code == 'weak-password') {
        throw Exception('Le mot de passe choisi est trop faible (minimum 6 caractères).');
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Le mot de passe actuel saisi est incorrect.');
      } else {
        // Fallback serveur si la méthode client échoue
        try {
          final callable = FirebaseFunctions.instance.httpsCallable('setUserPassword');
          await callable.call({'newPassword': newPassword});
        } catch (_) {
          throw Exception('Impossible d\'enregistrer le mot de passe : ${e.message ?? e.code}');
        }
      }
    }

    final now = DateTime.now();
    await _firestore.collection(AppConstants.colUsers).doc(user.uid).update({
      'hasPassword': true,
      'passwordUpdatedAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });

    try {
      await _firestore.collection(AppConstants.colAuditLogs).add({
        'userId': user.uid,
        'userName': _currentUser?.displayName ?? email,
        'userRole': _currentUser?.role.code ?? 'MEMBRE',
        'action': alreadyLinked ? 'user.password_updated' : 'user.password_created',
        'entityType': 'user',
        'entityId': user.uid,
        'details': {'email': email},
        'timestamp': now.toIso8601String(),
      });
    } catch (_) {}

    await reloadUser();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw Exception('Veuillez saisir votre adresse e-mail.');
    }
    await _auth.sendPasswordResetEmail(email: normalized);
  }

  @override
  Future<AppUser?> signInAsDemoUser({UserRole role = UserRole.admin}) async {
    final demoUser = AppUser(
      uid: 'dev_demo_user',
      email: 'demo.dev@ajra.org',
      displayName: role == UserRole.admin
          ? 'Administrateur (Mode Test)'
          : role == UserRole.bureau
              ? 'Membre du Bureau (Mode Test)'
              : 'Membre AJRA (Mode Test)',
      role: role,
      permissions: role == UserRole.bureau
          ? [
              AppPermissions.membershipReview,
              AppPermissions.membershipManage,
              AppPermissions.paymentVerify,
              AppPermissions.duesRecord,
              AppPermissions.financeTransactionCreate,
              AppPermissions.financeTransactionApprove,
              AppPermissions.financeReportView,
              AppPermissions.eventManage,
              AppPermissions.fundraisingManage,
              AppPermissions.postPublish,
            ]
          : const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
    _currentUser = demoUser;
    _userController.add(demoUser);
    return demoUser;
  }

  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await _auth.signOut();
    } catch (_) {}
    _currentUser = null;
    _userController.add(null);
  }

  @override
  Future<void> reloadUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      final doc = await _firestore.collection(AppConstants.colUsers).doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        _currentUser = AppUser.fromJson(doc.data()!, user.uid);
        _userController.add(_currentUser);
      }
    }
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Marquer le compte comme archivé / suspendu ou supprimer selon RGPD
      await _firestore.collection(AppConstants.colUsers).doc(user.uid).update({
        'isSuspended': true,
        'deletedAt': DateTime.now().toIso8601String(),
        'displayName': 'Compte supprimé',
      });
      await user.delete();
      await signOut();
    }
  }

  @override
  Future<void> deleteUserAccountAndDataByAdmin({
    required String targetUserId,
    required String targetEmail,
    required String adminUserId,
    required String adminName,
  }) async {
    // 1. Tenter d'exécuter la Cloud Function pour supprimer le compte Auth & données
    bool cloudFunctionSucceeded = false;
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('deleteUserAccountByAdmin');
      final result = await callable.call({'targetUid': targetUserId});
      if (result.data != null && result.data['success'] == true) {
        cloudFunctionSucceeded = true;
      }
    } catch (e) {
      debugPrint('Cloud Function deleteUserAccountByAdmin non disponible ou erreur: $e. Poursuite du nettoyage direct.');
    }

    // 2. Nettoyage exhaustif direct côté client dans Firestore
    final batch = _firestore.batch();
    int batchCount = 0;

    // Supprimer le document membre
    try {
      final memberRef = _firestore.collection(AppConstants.colMembers).doc(targetUserId);
      final memberDoc = await memberRef.get();
      if (memberDoc.exists) {
        batch.delete(memberRef);
        batchCount++;
      }
    } catch (_) {}

    // Supprimer le document utilisateur
    try {
      final userRef = _firestore.collection(AppConstants.colUsers).doc(targetUserId);
      batch.delete(userRef);
      batchCount++;
    } catch (_) {}

    // Supprimer le document membershipPayments (ID direct)
    try {
      final paymentRef = _firestore.collection('membershipPayments').doc(targetUserId);
      batch.delete(paymentRef);
      batchCount++;
    } catch (_) {}

    if (batchCount > 0) {
      try {
        await batch.commit();
      } catch (e) {
        debugPrint('Erreur batch delete user: $e');
      }
    }

    // Supprimer les collections secondaires liées à ce userId
    final secondaryCollections = [
      AppConstants.colDues,
      'membershipPayments',
      'eventParticipants',
      'fundraisingContributions',
      'notifications',
    ];

    for (final col in secondaryCollections) {
      try {
        final querySnap = await _firestore.collection(col).where('userId', isEqualTo: targetUserId).get();
        for (final doc in querySnap.docs) {
          await doc.reference.delete().catchError((_) {});
        }
      } catch (_) {}
    }

    // Notifications avec champ recipientUserId
    try {
      final notifsSnap = await _firestore.collection('notifications').where('recipientUserId', isEqualTo: targetUserId).get();
      for (final doc in notifsSnap.docs) {
        await doc.reference.delete().catchError((_) {});
      }
    } catch (_) {}

    // Prêts avec champ borrowerUserId
    try {
      final loansSnap = await _firestore.collection('memberLoans').where('borrowerUserId', isEqualTo: targetUserId).get();
      for (final doc in loansSnap.docs) {
        await doc.reference.delete().catchError((_) {});
      }
    } catch (_) {}

    // 3. Nettoyage Firebase Storage (avatars, justificatifs, passeports)
    try {
      final storage = FirebaseStorage.instance;
      for (final folder in ['avatars', 'proofs', 'passports']) {
        try {
          final listRes = await storage.ref('$folder/$targetUserId').listAll();
          for (final item in listRes.items) {
            await item.delete().catchError((_) {});
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Storage cleanup error: $e');
    }

    // 4. Inscription dans le journal d'Audit immuable
    try {
      await _firestore.collection(AppConstants.colAuditLogs).add({
        'userId': adminUserId,
        'userName': adminName,
        'userRole': 'ADMIN',
        'action': 'user.account_and_data_deleted',
        'entityType': 'user',
        'entityId': targetUserId,
        'details': {
          'targetUserId': targetUserId,
          'targetEmail': targetEmail,
          'cloudFunctionExecuted': cloudFunctionSucceeded,
        },
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  void dispose() {
    _authSubscription?.cancel();
    _userDocSubscription?.cancel();
    _userController.close();
  }
}
