import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nivvo/core/utils/greeting.dart';
import 'package:nivvo/shared/services/core_providers.dart';
import 'package:nivvo/shared/widgets/welcome_overlay.dart';
import 'package:nivvo/theme/app_theme.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  Widget host({required String name, required VoidCallback onDone}) => ProviderScope(
    overrides: [userProfileProvider.overrideWithValue((name: name, email: 'x@nivvo.app'))],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: WelcomeOverlay(onDone: onDone)),
    ),
  );

  testWidgets('mostra a saudação com o primeiro nome e termina sozinha', (tester) async {
    var done = false;
    await tester.pumpWidget(host(name: 'Daniel Dantas', onDone: () => done = true));
    await tester.pump(); // inicia a animação
    await tester.pump(const Duration(milliseconds: 1300)); // meio da animação

    expect(find.text('${Greeting.forTime(DateTime.now())},'), findsOneWidget);
    expect(find.text('Daniel!'), findsOneWidget);
    expect(done, isFalse);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(done, isTrue);
  });

  testWidgets('sem nome no cadastro mostra só a saudação', (tester) async {
    await tester.pumpWidget(host(name: '', onDone: () {}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('${Greeting.forTime(DateTime.now())}!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('toque pula a animação', (tester) async {
    var done = false;
    await tester.pumpWidget(host(name: 'Ana', onDone: () => done = true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byType(WelcomeOverlay));
    await tester.pump(); // a animação de saída começa a contar neste quadro
    await tester.pump(const Duration(milliseconds: 400));
    expect(done, isTrue);
  });
}
