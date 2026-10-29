/// Segmentos atendidos pelo Giro.
///
/// O núcleo do sistema é o mesmo para todos: produtos, movimentações e saldo.
/// O segmento só define o que já vem configurado no primeiro uso.
enum Segment {
  mercado(
    'Mercado',
    'Mercearias, minimercados e conveniências',
    units: ['un', 'kg', 'g', 'L', 'ml', 'cx', 'pct'],
    categories: [
      'Bebidas',
      'Mercearia',
      'Limpeza',
      'Higiene',
      'Frios e laticínios',
      'Hortifruti',
      'Congelados',
    ],
    tracksBatch: false,
    tracksExpiry: true,
    multiLocation: false,
  ),
  padaria(
    'Padaria',
    'Padarias, confeitarias e produção diária',
    units: ['un', 'kg', 'g', 'pct', 'dz'],
    categories: [
      'Pães',
      'Confeitaria',
      'Salgados',
      'Ingredientes',
      'Embalagens',
      'Bebidas',
    ],
    tracksBatch: true,
    tracksExpiry: true,
    multiLocation: false,
  ),
  bebidas(
    'Bebidas',
    'Distribuidoras, adegas e depósitos',
    units: ['un', 'cx', 'fardo', 'L', 'ml', 'garrafa'],
    categories: [
      'Cervejas',
      'Vinhos',
      'Destilados',
      'Não alcoólicos',
      'Energéticos',
      'Descartáveis',
    ],
    tracksBatch: true,
    tracksExpiry: true,
    multiLocation: true,
  ),
  logistica(
    'Logística',
    'Depósitos, centros de distribuição e transportadoras',
    units: ['un', 'cx', 'pct', 'palete', 'kg'],
    categories: [
      'Recebimento',
      'Expedição',
      'Avarias',
      'Devolução',
      'Insumos',
    ],
    tracksBatch: true,
    tracksExpiry: false,
    multiLocation: true,
  );

  const Segment(
    this.label,
    this.description, {
    required this.units,
    required this.categories,
    required this.tracksBatch,
    required this.tracksExpiry,
    required this.multiLocation,
  });

  final String label;
  final String description;
  final List<String> units;
  final List<String> categories;
  final bool tracksBatch;
  final bool tracksExpiry;
  final bool multiLocation;

  /// Unidade padrão sugerida para novos produtos do segmento.
  String get defaultUnit => units.first;

  static Segment fromName(String value) {
    for (final segment in Segment.values) {
      if (segment.name == value) return segment;
    }
    return Segment.mercado;
  }
}

/// Unidades de medida aceitas no cadastro.
class Units {
  const Units._();

  static const List<String> all = [
    'un',
    'kg',
    'g',
    'L',
    'ml',
    'cx',
    'pct',
    'dz',
    'fardo',
    'garrafa',
    'palete',
  ];

  static const Map<String, String> labels = {
    'un': 'Unidade',
    'kg': 'Quilograma',
    'g': 'Grama',
    'L': 'Litro',
    'ml': 'Mililitro',
    'cx': 'Caixa',
    'pct': 'Pacote',
    'dz': 'Dúzia',
    'fardo': 'Fardo',
    'garrafa': 'Garrafa',
    'palete': 'Palete',
  };
}
