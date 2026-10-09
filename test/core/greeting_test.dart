import 'package:flutter_test/flutter_test.dart';
import 'package:nivvo/core/utils/greeting.dart';

void main() {
  DateTime at(int hour, [int minute = 0]) => DateTime(2026, 10, 9, hour, minute);

  test('saudação conforme o horário do aparelho', () {
    expect(Greeting.forTime(at(5)), 'Bom dia');
    expect(Greeting.forTime(at(11, 59)), 'Bom dia');
    expect(Greeting.forTime(at(12)), 'Boa tarde');
    expect(Greeting.forTime(at(17, 59)), 'Boa tarde');
    expect(Greeting.forTime(at(18)), 'Boa noite');
    expect(Greeting.forTime(at(0, 30)), 'Boa noite');
    expect(Greeting.forTime(at(4, 59)), 'Boa noite');
  });

  test('usa o primeiro nome do cadastro', () {
    expect(Greeting.message(at(9), 'Daniel Dantas'), 'Bom dia, Daniel!');
    expect(Greeting.message(at(14), '  maria  '), 'Boa tarde, maria!');
    expect(Greeting.message(at(20), ''), 'Boa noite!');
  });
}
