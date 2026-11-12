import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/notifications/models/notification_item.dart';
import 'features/notifications/screens/notifications_screen.dart';
import 'features/notifications/services/notification_service.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation sécurisée de Firebase avec options multi-plateformes (Web, Android, iOS)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }
  } catch (e) {
    debugPrint('Firebase initialisé en mode dégradé / local: $e');
  }

  runApp(
    const ProviderScope(
      child: AjraApp(),
    ),
  );
}

class AjraApp extends ConsumerStatefulWidget {
  const AjraApp({super.key});

  @override
  ConsumerState<AjraApp> createState() => _AjraAppState();
}

class _AjraAppState extends ConsumerState<AjraApp> with WidgetsBindingObserver {
  String? _activeUserId;
  bool _initialNotificationsLoaded = false;
  final Set<String> _seenNotificationIds = {};
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }

  void _resetTrackingForUser(String? uid) {
    if (_activeUserId != uid) {
      _activeUserId = uid;
      _initialNotificationsLoaded = false;
      _seenNotificationIds.clear();
      if (uid != null && uid.isNotEmpty) {
        NotificationService.initializeForUser(uid);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    _resetTrackingForUser(user?.uid);

    // Écoute globale unique des nouvelles notifications (messages 1-à-1, groupes, annonces)
    // En arrière-plan / écran éteint sur Android, FCM affiche déjà la notification unique automatiquement.
    ref.listen<AsyncValue<List<NotificationItem>>>(userNotificationsProvider, (previous, next) {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null || !next.hasValue || next.value == null) return;

      final notifs = next.value!;
      if (!_initialNotificationsLoaded) {
        for (final n in notifs) {
          _seenNotificationIds.add(n.id);
        }
        _initialNotificationsLoaded = true;
        return;
      }

      for (final n in notifs) {
        if (!_seenNotificationIds.contains(n.id)) {
          _seenNotificationIds.add(n.id);
          if (!n.isReadByUser(currentUser.uid) && n.senderUserId != currentUser.uid) {
            if (kIsWeb || _lifecycleState == AppLifecycleState.resumed) {
              NotificationService.showSystemNotification(
                title: n.title,
                body: n.body,
                id: n.id.hashCode,
                notificationId: n.id,
              );
            }
          }
        }
      }
    });

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
      ],
      locale: const Locale('fr', 'FR'),
    );
  }
}
