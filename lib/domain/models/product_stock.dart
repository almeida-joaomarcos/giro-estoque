import 'product.dart';

/// Produto + saldo calculado pelas movimentações.
class ProductStock {
  const ProductStock({required this.product, required this.balance});

  final Product product;
  final double balance;

  bool get isOutOfStock => balance <= 0;

  bool get isLowStock => product.minStock > 0 && balance <= product.minStock;

  bool get isCritical => isOutOfStock || isLowStock;

  double get stockValue => balance * product.costPrice;

  String get statusLabel {
    if (isOutOfStock) return 'Sem estoque';
    if (isLowStock) return 'Estoque baixo';
    return 'Ok';
  }
}

/// Números do painel.
class StockSummary {
  const StockSummary({
    this.totalProducts = 0,
    this.totalUnits = 0,
    this.totalValue = 0,
    this.lowStockCount = 0,
    this.outOfStockCount = 0,
    this.movementsToday = 0,
    this.movementsWeek = 0,
  });

  final int totalProducts;
  final double totalUnits;
  final double totalValue;
  final int lowStockCount;
  final int outOfStockCount;
  final int movementsToday;
  final int movementsWeek;

  static const StockSummary empty = StockSummary();
}
