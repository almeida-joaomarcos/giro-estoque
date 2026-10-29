import 'package:flutter_test/flutter_test.dart';
import 'package:giro_estoque/core/utils/formatters.dart';

void main() {
  group('parseNumber', () {
    test('aceita vírgula como separador decimal', () {
      expect(parseNumber('12,5'), 12.5);
      expect(parseNumber('0,25'), 0.25);
      expect(parseNumber('1.234,56'), 1234.56);
    });

    test('aceita ponto como separador decimal', () {
      expect(parseNumber('12.5'), 12.5);
      expect(parseNumber('10'), 10);
    });

    test('retorna null para texto vazio ou inválido', () {
      expect(parseNumber(''), isNull);
      expect(parseNumber('   '), isNull);
      expect(parseNumber('abc'), isNull);
      expect(parseNumber(null), isNull);
    });
  });

  group('formatadores', () {
    test('formata dinheiro em real', () {
      final formatted = formatMoney(1234.5);
      expect(formatted, contains('1.234,50'));
      expect(formatted, contains(r'R$'));
    });

    test('formata quantidade sem zeros desnecessários', () {
      expect(formatQuantity(12), '12');
      expect(formatQuantity(12.5), '12,5');
    });

    test('formata data no padrão brasileiro', () {
      expect(formatDate(DateTime(2026, 10, 29)), '29/10/2026');
    });

    test('formata data e hora', () {
      expect(
        formatDateTime(DateTime(2026, 1, 5, 8, 7)),
        '05/01/2026 08:07',
      );
    });
  });
}
