import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:saralpooja/main.dart';

void main() {
  testWidgets('Saral Pooja app renders', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SaralPoojaApp()));
    await tester.pump();

    expect(find.byType(SaralPoojaApp), findsOneWidget);
  });
}
