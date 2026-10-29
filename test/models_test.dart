import 'package:flutter_test/flutter_test.dart';
import 'package:giro_estoque/domain/models/business_config.dart';
import 'package:giro_estoque/domain/models/product.dart';
import 'package:giro_estoque/domain/models/segment.dart';
import 'package:giro_estoque/domain/models/stock_movement.dart';

void main() {
  group('MovementType', () {
    test('entrada e saída têm sinais opostos', () {
      expect(MovementType.entrada.signedQuantity(5), 5);
      expect(MovementType.saida.signedQuantity(5), -5);
      expect(MovementType.perda.signedQuantity(3), -3);
    });

    test('ajuste respeita o sinal informado', () {
      expect(MovementType.ajuste.signedQuantity(-2), -2);
      expect(MovementType.ajuste.signedQuantity(4), 4);
    });

    test('transferência afeta origem e destino', () {
      expect(MovementType.transferenciaSaida.signedQuantity(8), -8);
      expect(MovementType.transferenciaEntrada.signedQuantity(8), 8);
    });

    test('converte o valor salvo no banco', () {
      expect(
        MovementType.fromDb('transferencia_saida'),
        MovementType.transferenciaSaida,
      );
      expect(MovementType.fromDb('desconhecido'), MovementType.entrada);
    });
  });

  group('Segment', () {
    test('cada segmento tem unidades e categorias configuradas', () {
      for (final segment in Segment.values) {
        expect(segment.units, isNotEmpty);
        expect(segment.categories, isNotEmpty);
        expect(segment.defaultUnit, isNotEmpty);
      }
    });

    test('mercado controla validade e não usa múltiplos locais', () {
      expect(Segment.mercado.tracksExpiry, isTrue);
      expect(Segment.mercado.multiLocation, isFalse);
    });

    test('logística usa múltiplos locais e lote, sem validade', () {
      expect(Segment.logistica.multiLocation, isTrue);
      expect(Segment.logistica.tracksBatch, isTrue);
      expect(Segment.logistica.tracksExpiry, isFalse);
    });

    test('nome desconhecido cai no mercado', () {
      expect(Segment.fromName('inexistente'), Segment.mercado);
    });
  });

  group('BusinessConfig', () {
    test('ida e volta pelo mapa preserva os campos', () {
      final config = BusinessConfig(
        businessName: 'Mercado Bom Preço',
        segment: Segment.bebidas,
        tracksBatch: true,
        tracksExpiry: true,
        multiLocation: true,
        createdAt: DateTime(2026, 5, 1),
      );

      final restored = BusinessConfig.fromMap(config.toMap());

      expect(restored.businessName, 'Mercado Bom Preço');
      expect(restored.segment, Segment.bebidas);
      expect(restored.tracksBatch, isTrue);
      expect(restored.multiLocation, isTrue);
      expect(restored.isConfigured, isTrue);
    });

    test('configuração vazia não é considerada pronta', () {
      final config = BusinessConfig(
        businessName: '   ',
        segment: Segment.mercado,
        tracksBatch: false,
        tracksExpiry: true,
        multiLocation: false,
      );
      expect(config.isConfigured, isFalse);
    });
  });

  group('Product', () {
    test('ida e volta pelo mapa preserva os campos', () {
      final product = Product(
        name: 'Arroz 5 kg',
        sku: 'ARR-5',
        barcode: '7891000000001',
        category: 'Mercearia',
        unit: 'pct',
        costPrice: 22.9,
        salePrice: 29.9,
        minStock: 8,
      );

      final restored = Product.fromMap(product.toMap());

      expect(restored.name, 'Arroz 5 kg');
      expect(restored.barcode, '7891000000001');
      expect(restored.costPrice, 22.9);
      expect(restored.unit, 'pct');
      expect(restored.active, isTrue);
    });

    test('campos de texto vazios viram nulo', () {
      final product = Product(name: 'Teste', sku: '   ', barcode: '');
      final map = product.toMap();
      expect(map['sku'], isNull);
      expect(map['barcode'], isNull);
    });
  });
}
