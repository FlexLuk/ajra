import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ajra/core/services/app_update_service.dart';
import 'package:ajra/features/auth/providers/auth_provider.dart';
import 'package:ajra/main.dart';
import 'mocks/mock_auth_repository.dart';

void main() {
  testWidgets('AjraApp smoke test, splash screen and login options rendering', (WidgetTester tester) async {
    final mockAuth = MockAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuth),
        ],
        child: const AjraApp(),
      ),
    );

    // Initial frame on /splash
    await tester.pump();

    // Verify AJRA branding title or text appears
    expect(find.text('AJRA'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Advance clock past the splash screen timer (1200ms)
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    // Verify both Google sign-in and Login/Password sign-in are displayed on LoginScreen
    expect(find.text('Se connecter avec Google'), findsOneWidget);
    expect(find.text('Se connecter avec identifiant'), findsOneWidget);
  });

  testWidgets('Responsive layout verification across small phone, tablet, landscape and font scaling', (WidgetTester tester) async {
    final sizes = [
      const Size(320, 568), // Small phone
      const Size(360, 780), // Standard Android phone
      const Size(412, 915), // Large Android phone
      const Size(800, 1280), // Tablet
      const Size(780, 360), // Landscape
    ];

    for (final size in sizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      final mockAuth = MockAuthRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuth),
          ],
          child: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(1.15),
            ),
            child: const AjraApp(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      expect(find.text('Se connecter avec Google'), findsOneWidget);
      expect(find.text('Se connecter avec identifiant'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  test('AppUpdateService version comparison and MockAuth password lifecycle', () async {
    expect(AppUpdateService.isVersionNewer('1.4.9', '1.4.8'), isTrue);
    expect(AppUpdateService.isVersionNewer('1.5.0', '1.4.8'), isTrue);
    expect(AppUpdateService.isVersionNewer('1.4.8', '1.4.8'), isFalse);
    expect(AppUpdateService.isVersionNewer('1.4.7', '1.4.8'), isFalse);

    final mockAuth = MockAuthRepository();
    // Unregistered login should fail (only Google account creation is accepted)
    expect(
      () => mockAuth.signInWithEmailAndPassword(
        email: 'inconnu@ajra.org',
        password: 'password123',
      ),
      throwsException,
    );

    // Sign in with Google creates the account
    final googleUser = await mockAuth.signInWithGoogle();
    expect(googleUser, isNotNull);
    expect(googleUser!.hasPassword, isFalse);

    // Create password in profile
    await mockAuth.createOrUpdatePassword(newPassword: 'secret123');
    expect(mockAuth.currentUser!.hasPassword, isTrue);

    // Sign in with email and password now succeeds for the Google-created account
    final loggedIn = await mockAuth.signInWithEmailAndPassword(
      email: 'membre.test@ajra.org',
      password: 'secret123',
    );
    expect(loggedIn, isNotNull);
    expect(loggedIn!.hasPassword, isTrue);
  });
}
