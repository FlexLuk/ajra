import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ajra/features/auth/providers/auth_provider.dart';
import 'package:ajra/main.dart';
import 'mocks/mock_auth_repository.dart';

void main() {
  testWidgets('AjraApp smoke test and splash screen rendering', (WidgetTester tester) async {
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
  });
}
