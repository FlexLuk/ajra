import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/membership/providers/membership_provider.dart';
import '../theme/app_colors.dart';

/// Gestionnaire centralisé de l'historique de navigation et du bouton Retour (UI & Android).
/// - Empêche l'application de se fermer brusquement lors d'un retour sur une page.
/// - Restaure la page précédente réelle dans l'historique.
/// - Exige un double appui ("double tap") sur Retour depuis l'écran d'accueil pour quitter l'application.
class AjraNavigationHistory {
  static final List<String> _history = <String>[];
  static bool _isNavigatingBack = false;
  static DateTime? _lastExitPressTime;

  static const List<String> _allowedUnvalidatedRoutes = <String>[
    '/membership-status',
    '/membership-apply',
    '/membership-fee',
    '/about',
    '/profile',
  ];

  /// Enregistre la route courante dans la pile d'historique
  static void recordLocation(String location) {
    if (location.isEmpty || location == '/splash') return;

    if (location == '/login') {
      _history
        ..clear()
        ..add('/login');
      _isNavigatingBack = false;
      return;
    }

    if (_isNavigatingBack) {
      _isNavigatingBack = false;
      if (_history.isEmpty || _history.last != location) {
        _history.add(location);
      }
      return;
    }

    if (_history.isNotEmpty && _history.last == location) {
      return;
    }

    // Éviter les boucles A -> B -> A lors des changements d'onglets
    if (_history.length >= 2 && _history[_history.length - 2] == location) {
      _history.removeLast();
      return;
    }

    _history.add(location);
    if (_history.length > 30) {
      _history.removeAt(0);
    }
  }

  static String defaultHomeRoute({
    required bool isLoggedIn,
    required bool isValidatedAndActive,
  }) {
    if (!isLoggedIn) return '/login';
    return isValidatedAndActive ? '/dashboard' : '/membership-status';
  }

  static bool isRootHomeRoute(
    String location, {
    required bool isLoggedIn,
    required bool isValidatedAndActive,
  }) {
    if (!isLoggedIn) return location == '/login';
    if (isValidatedAndActive) return location == '/dashboard';
    return location == '/membership-status';
  }

  static bool _isRouteAllowed(
    String route, {
    required bool isLoggedIn,
    required bool isValidatedAndActive,
  }) {
    if (route.isEmpty || route == '/splash') return false;
    if (!isLoggedIn) {
      return route == '/login' || route == '/about';
    }
    if (route == '/login') return false;
    if (!isValidatedAndActive) {
      return _allowedUnvalidatedRoutes.contains(route);
    }
    return true;
  }

  /// Indique s'il existe une page précédente vers laquelle revenir
  static bool canGoBackFrom(
    String currentLocation, {
    required bool isLoggedIn,
    required bool isValidatedAndActive,
  }) {
    for (int i = _history.length - 1; i >= 0; i--) {
      final candidate = _history[i];
      if (candidate != currentLocation &&
          _isRouteAllowed(
            candidate,
            isLoggedIn: isLoggedIn,
            isValidatedAndActive: isValidatedAndActive,
          )) {
        return true;
      }
    }
    return !isRootHomeRoute(
      currentLocation,
      isLoggedIn: isLoggedIn,
      isValidatedAndActive: isValidatedAndActive,
    );
  }

  /// Exécute l'action Retour (flèche AppBar ou bouton système Android)
  static Future<void> handleBack(
    BuildContext context,
    WidgetRef ref, {
    String? currentLocationOverride,
    String? fallbackRoute,
  }) async {
    // 1. Si une boîte de dialogue, feuille modale ou page poussée via Navigator.push est ouverte, la fermer d'abord
    final nav = Navigator.maybeOf(context);
    if (nav != null && nav.canPop()) {
      nav.pop();
      return;
    }

    final user = ref.read(currentUserProvider);
    final isLoggedIn = user != null;
    final isValidatedAndActive = ref.read(isMemberValidatedAndActiveProvider);

    String currentLocation = currentLocationOverride ?? '';
    if (currentLocation.isEmpty) {
      try {
        currentLocation = GoRouterState.of(context).matchedLocation;
      } catch (_) {
        currentLocation = _history.isNotEmpty ? _history.last : '/dashboard';
      }
    }

    // Nettoyer la position actuelle en sommet de pile
    while (_history.isNotEmpty && _history.last == currentLocation) {
      _history.removeLast();
    }

    // 2. Chercher la dernière page valide visitée dans l'historique
    while (_history.isNotEmpty) {
      final previous = _history.removeLast();
      if (previous != currentLocation &&
          _isRouteAllowed(
            previous,
            isLoggedIn: isLoggedIn,
            isValidatedAndActive: isValidatedAndActive,
          )) {
        _isNavigatingBack = true;
        context.go(previous);
        return;
      }
    }

    // 3. Si un fallbackRoute explicite est fourni et autorisé
    if (fallbackRoute != null &&
        fallbackRoute != currentLocation &&
        _isRouteAllowed(
          fallbackRoute,
          isLoggedIn: isLoggedIn,
          isValidatedAndActive: isValidatedAndActive,
        )) {
      _isNavigatingBack = true;
      context.go(fallbackRoute);
      return;
    }

    // 4. Si l'historique est vide mais qu'on n'est pas sur l'écran d'accueil principal, ramener à l'accueil
    final homeRoute = defaultHomeRoute(
      isLoggedIn: isLoggedIn,
      isValidatedAndActive: isValidatedAndActive,
    );
    if (currentLocation != homeRoute) {
      _isNavigatingBack = true;
      context.go(homeRoute);
      return;
    }

    // 5. On est déjà sur l'écran d'accueil principal : double-tap pour quitter l'application
    final now = DateTime.now();
    if (_lastExitPressTime == null ||
        now.difference(_lastExitPressTime!) > const Duration(seconds: 2)) {
      _lastExitPressTime = now;
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.primaryDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: const Row(
              children: [
                Icon(Icons.touch_app_outlined, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Appuyez une deuxième fois sur Retour pour quitter l\'application.',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    // Deuxième appui dans les 2 secondes : fermeture propre de l'application sur Android
    await SystemNavigator.pop();
  }
}

/// Enveloppe chaque route GoRouter pour intercepter le bouton Retour système Android
/// et enregistrer automatiquement l'historique de navigation.
class AjraRouteBackScope extends ConsumerStatefulWidget {
  final String location;
  final Widget child;

  const AjraRouteBackScope({
    super.key,
    required this.location,
    required this.child,
  });

  @override
  ConsumerState<AjraRouteBackScope> createState() => _AjraRouteBackScopeState();
}

class _AjraRouteBackScopeState extends ConsumerState<AjraRouteBackScope> {
  @override
  void initState() {
    super.initState();
    AjraNavigationHistory.recordLocation(widget.location);
  }

  @override
  void didUpdateWidget(covariant AjraRouteBackScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      AjraNavigationHistory.recordLocation(widget.location);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        AjraNavigationHistory.handleBack(
          context,
          ref,
          currentLocationOverride: widget.location,
        );
      },
      child: widget.child,
    );
  }
}

/// Bouton de retour unifié à placer dans l'AppBar des écrans secondaires
class AjraBackButton extends ConsumerWidget {
  final String? fallbackRoute;
  final VoidCallback? onCustomBack;

  const AjraBackButton({
    super.key,
    this.fallbackRoute,
    this.onCustomBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Retour',
      onPressed: () {
        if (onCustomBack != null) {
          onCustomBack!();
          return;
        }
        AjraNavigationHistory.handleBack(
          context,
          ref,
          fallbackRoute: fallbackRoute,
        );
      },
    );
  }
}
