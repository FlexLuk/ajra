import 'package:flutter_test/flutter_test.dart';
import 'package:ajra/core/routing/ajra_back_navigation.dart';

void main() {
  group('AjraNavigationHistory Tests', () {
    setUp(() {
      // Nettoyer l'historique en simulant un retour sur le login
      AjraNavigationHistory.recordLocation('/login');
    });

    test('Identifies root home routes correctly based on auth status', () {
      // Non connecté
      expect(
        AjraNavigationHistory.isRootHomeRoute(
          '/login',
          isLoggedIn: false,
          isValidatedAndActive: false,
        ),
        isTrue,
      );
      expect(
        AjraNavigationHistory.isRootHomeRoute(
          '/dashboard',
          isLoggedIn: false,
          isValidatedAndActive: false,
        ),
        isFalse,
      );

      // Connecté et validé / actif
      expect(
        AjraNavigationHistory.isRootHomeRoute(
          '/dashboard',
          isLoggedIn: true,
          isValidatedAndActive: true,
        ),
        isTrue,
      );
      expect(
        AjraNavigationHistory.isRootHomeRoute(
          '/members',
          isLoggedIn: true,
          isValidatedAndActive: true,
        ),
        isFalse,
      );

      // Connecté non validé (en cours de révision)
      expect(
        AjraNavigationHistory.isRootHomeRoute(
          '/membership-status',
          isLoggedIn: true,
          isValidatedAndActive: false,
        ),
        isTrue,
      );
      expect(
        AjraNavigationHistory.isRootHomeRoute(
          '/dashboard',
          isLoggedIn: true,
          isValidatedAndActive: false,
        ),
        isFalse,
      );
    });

    test('Provides correct default home route', () {
      expect(
        AjraNavigationHistory.defaultHomeRoute(
          isLoggedIn: false,
          isValidatedAndActive: false,
        ),
        equals('/login'),
      );

      expect(
        AjraNavigationHistory.defaultHomeRoute(
          isLoggedIn: true,
          isValidatedAndActive: true,
        ),
        equals('/dashboard'),
      );

      expect(
        AjraNavigationHistory.defaultHomeRoute(
          isLoggedIn: true,
          isValidatedAndActive: false,
        ),
        equals('/membership-status'),
      );
    });

    test('Records locations and handles tab loops', () {
      AjraNavigationHistory.recordLocation('/dashboard');
      AjraNavigationHistory.recordLocation('/members');
      AjraNavigationHistory.recordLocation('/dues');

      // Doit pouvoir revenir en arrière depuis /dues
      expect(
        AjraNavigationHistory.canGoBackFrom(
          '/dues',
          isLoggedIn: true,
          isValidatedAndActive: true,
        ),
        isTrue,
      );

      // Tab loop A -> B -> A (/members -> /dues -> /members)
      AjraNavigationHistory.recordLocation('/members');
      // La boucle doit avoir dépilé /dues
      expect(
        AjraNavigationHistory.canGoBackFrom(
          '/members',
          isLoggedIn: true,
          isValidatedAndActive: true,
        ),
        isTrue,
      );
    });

    test('Prevents accidental app exit from sub-screens', () {
      // Même avec historique vide, canGoBackFrom sur un sous-écran est vrai car il ramène au Dashboard
      AjraNavigationHistory.recordLocation('/login');
      expect(
        AjraNavigationHistory.canGoBackFrom(
          '/profile',
          isLoggedIn: true,
          isValidatedAndActive: true,
        ),
        isTrue,
      );

      expect(
        AjraNavigationHistory.canGoBackFrom(
          '/about',
          isLoggedIn: true,
          isValidatedAndActive: true,
        ),
        isTrue,
      );

      expect(
        AjraNavigationHistory.canGoBackFrom(
          '/events',
          isLoggedIn: true,
          isValidatedAndActive: true,
        ),
        isTrue,
      );
    });

    test('Root screen requires double-tap and canGoBackFrom is false when at root', () {
      // Sur le root avec historique vide, canGoBackFrom est faux -> signal pour double-tap exit
      AjraNavigationHistory.recordLocation('/login');
      AjraNavigationHistory.recordLocation('/dashboard');

      expect(
        AjraNavigationHistory.canGoBackFrom(
          '/dashboard',
          isLoggedIn: true,
          isValidatedAndActive: true,
        ),
        isFalse,
      );

      // Pour utilisateur non validé sur son écran d'accueil
      AjraNavigationHistory.recordLocation('/membership-status');
      expect(
        AjraNavigationHistory.canGoBackFrom(
          '/membership-status',
          isLoggedIn: true,
          isValidatedAndActive: false,
        ),
        isFalse,
      );
    });
  });
}
