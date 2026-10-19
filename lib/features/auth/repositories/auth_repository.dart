import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../models/app_user.dart';

abstract class BaseAuthRepository {
  Stream<AppUser?> get userStream;
  AppUser? get currentUser;
  Future<AppUser?> signInWithGoogle();
  Future<void> signOut();
  Future<void> reloadUser();
  Future<void> deleteAccount();
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
        final data = docSnapshot.data()!;
        _currentUser = AppUser.fromJson(data, uid);
        _userController.add(_currentUser);
      } else {
        // Le document n'existe pas encore: première connexion
        final newUser = AppUser(
          uid: uid,
          email: firebaseUser.email ?? '',
          displayName: firebaseUser.displayName ?? 'Membre AJRA',
          photoUrl: firebaseUser.photoURL,
          role: UserRole.member,
          permissions: const [],
          isSuspended: false,
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
  Stream<AppUser?> get userStream => _userController.stream;

  @override
  AppUser? get currentUser => _currentUser;

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

      if (!doc.exists) {
        final newUser = AppUser(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          displayName: firebaseUser.displayName ?? 'Membre AJRA',
          photoUrl: firebaseUser.photoURL,
          role: UserRole.member,
          permissions: const [],
          isSuspended: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );
        await docRef.set(newUser.toJson());
        _currentUser = newUser;
      } else {
        await docRef.update({
          'lastLoginAt': DateTime.now().toIso8601String(),
          if (firebaseUser.photoURL != null) 'photoUrl': firebaseUser.photoURL,
        });
        _currentUser = AppUser.fromJson(doc.data()!, firebaseUser.uid);
      }

      return _currentUser;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
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

  void dispose() {
    _authSubscription?.cancel();
    _userDocSubscription?.cancel();
    _userController.close();
  }
}
