// Basic smoke test for the RG AModule app.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:saralpooja/core/router/app_router.dart';
import 'package:saralpooja/main.dart';

void main() {
  testWidgets('App smoke test – splash renders', (WidgetTester tester) async {
    final testRouter = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );
    addTearDown(testRouter.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWithValue(testRouter),
        ],
        child: const SaralPoojaApp(),
      ),
    );
    // Allow the first frame to render.
    await tester.pumpAndSettle();
    // The app should render without throwing.
    expect(find.byType(SaralPoojaApp), findsOneWidget);
  });
}
