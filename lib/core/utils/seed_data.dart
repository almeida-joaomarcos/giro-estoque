import '../../domain/models/segment.dart';

/// Produto de exemplo criado no onboarding, quando o usuário aceita
/// "incluir dados de exemplo". Serve para o app não abrir vazio.
class SeedProduct {
  const SeedProduct({
    required this.name,
    required this.category,
    required this.unit,
    required this.cost,
    required this.sale,
    required this.minStock,
    required this.initial,
    this.weeklyOut = 0,
  });

  final String name;
  final String category;
  final String unit;
  final double cost;
  final double sale;
  final double minStock;
  final double initial;
  final double weeklyOut;
}

List<SeedProduct> seedProductsFor(Segment segment) {
  switch (segment) {
    case Segment.mercado:
      return const [
        SeedProduct(
          name: 'Arroz branco 5 kg',
          category: 'Mercearia',
          unit: 'pct',
          cost: 22.90,
          sale: 29.90,
          minStock: 8,
          initial: 40,
          weeklyOut: 24,
        ),
        SeedProduct(
          name: 'Feijão carioca 1 kg',
          category: 'Mercearia',
          unit: 'pct',
          cost: 6.40,
          sale: 8.99,
          minStock: 12,
          initial: 50,
          weeklyOut: 31,
        ),
        SeedProduct(
          name: 'Óleo de soja 900 ml',
          category: 'Mercearia',
          unit: 'un',
          cost: 5.20,
          sale: 7.49,
          minStock: 10,
          initial: 30,
          weeklyOut: 18,
        ),
        SeedProduct(
          name: 'Leite integral 1 L',
          category: 'Frios e laticínios',
          unit: 'un',
          cost: 4.10,
          sale: 5.79,
          minStock: 24,
          initial: 60,
          weeklyOut: 44,
        ),
        SeedProduct(
          name: 'Café torrado 500 g',
          category: 'Mercearia',
          unit: 'pct',
          cost: 14.80,
          sale: 19.90,
          minStock: 6,
          initial: 18,
          weeklyOut: 9,
        ),
        SeedProduct(
          name: 'Detergente 500 ml',
          category: 'Limpeza',
          unit: 'un',
          cost: 1.85,
          sale: 2.99,
          minStock: 20,
          initial: 48,
          weeklyOut: 26,
        ),
        SeedProduct(
          name: 'Refrigerante cola 2 L',
          category: 'Bebidas',
          unit: 'un',
          cost: 6.90,
          sale: 9.49,
          minStock: 12,
          initial: 36,
          weeklyOut: 21,
        ),
        SeedProduct(
          name: 'Papel higiênico 12 rolos',
          category: 'Higiene',
          unit: 'pct',
          cost: 16.50,
          sale: 22.90,
          minStock: 5,
          initial: 12,
          weeklyOut: 8,
        ),
      ];
    case Segment.padaria:
      return const [
        SeedProduct(
          name: 'Pão francês',
          category: 'Pães',
          unit: 'kg',
          cost: 8.50,
          sale: 16.90,
          minStock: 5,
          initial: 18,
          weeklyOut: 12,
        ),
        SeedProduct(
          name: 'Farinha de trigo 1 kg',
          category: 'Ingredientes',
          unit: 'pct',
          cost: 4.20,
          sale: 0,
          minStock: 10,
          initial: 30,
          weeklyOut: 18,
        ),
        SeedProduct(
          name: 'Açúcar refinado 1 kg',
          category: 'Ingredientes',
          unit: 'pct',
          cost: 3.90,
          sale: 0,
          minStock: 8,
          initial: 24,
          weeklyOut: 14,
        ),
        SeedProduct(
          name: 'Leite condensado 395 g',
          category: 'Ingredientes',
          unit: 'un',
          cost: 5.30,
          sale: 0,
          minStock: 12,
          initial: 36,
          weeklyOut: 22,
        ),
        SeedProduct(
          name: 'Coxinha congelada',
          category: 'Salgados',
          unit: 'un',
          cost: 2.10,
          sale: 6.50,
          minStock: 50,
          initial: 120,
          weeklyOut: 80,
        ),
        SeedProduct(
          name: 'Caixa para bolo',
          category: 'Embalagens',
          unit: 'un',
          cost: 1.20,
          sale: 0,
          minStock: 30,
          initial: 60,
          weeklyOut: 25,
        ),
      ];
    case Segment.bebidas:
      return const [
        SeedProduct(
          name: 'Cerveja lata 350 ml',
          category: 'Cervejas',
          unit: 'cx',
          cost: 42.00,
          sale: 59.90,
          minStock: 10,
          initial: 40,
          weeklyOut: 26,
        ),
        SeedProduct(
          name: 'Refrigerante 2 L',
          category: 'Não alcoólicos',
          unit: 'un',
          cost: 6.90,
          sale: 9.49,
          minStock: 24,
          initial: 60,
          weeklyOut: 38,
        ),
        SeedProduct(
          name: 'Água mineral 500 ml',
          category: 'Não alcoólicos',
          unit: 'fardo',
          cost: 12.00,
          sale: 18.00,
          minStock: 8,
          initial: 24,
          weeklyOut: 15,
        ),
        SeedProduct(
          name: 'Vinho tinto seco 750 ml',
          category: 'Vinhos',
          unit: 'un',
          cost: 28.00,
          sale: 44.90,
          minStock: 6,
          initial: 18,
          weeklyOut: 5,
        ),
        SeedProduct(
          name: 'Copo descartável 300 ml',
          category: 'Descartáveis',
          unit: 'pct',
          cost: 4.50,
          sale: 7.90,
          minStock: 10,
          initial: 20,
          weeklyOut: 13,
        ),
      ];
    case Segment.logistica:
      return const [
        SeedProduct(
          name: 'Caixa de papelão P',
          category: 'Insumos',
          unit: 'un',
          cost: 1.80,
          sale: 0,
          minStock: 100,
          initial: 400,
          weeklyOut: 260,
        ),
        SeedProduct(
          name: 'Caixa de papelão G',
          category: 'Insumos',
          unit: 'un',
          cost: 3.20,
          sale: 0,
          minStock: 80,
          initial: 300,
          weeklyOut: 210,
        ),
        SeedProduct(
          name: 'Filme stretch',
          category: 'Insumos',
          unit: 'un',
          cost: 24.00,
          sale: 0,
          minStock: 6,
          initial: 20,
          weeklyOut: 8,
        ),
        SeedProduct(
          name: 'Palete PBR',
          category: 'Insumos',
          unit: 'palete',
          cost: 48.00,
          sale: 0,
          minStock: 10,
          initial: 30,
          weeklyOut: 18,
        ),
      ];
  }
}
