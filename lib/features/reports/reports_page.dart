import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/inventory_repository.dart';
import '../../domain/models/product_stock.dart';
import '../../state/inventory_controller.dart';
import '../widgets/common.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InventoryController>();
    final summary = controller.summary;
    final categories = controller.categories;

    final byValue = controller.allProducts
        .where((item) => item.stockValue > 0)
        .toList()
      ..sort((a, b) => b.stockValue.compareTo(a.stockValue));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const PageHeader(
          title: 'Relatórios',
          subtitle: 'Visão de valor, categorias e itens em alerta',
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 1000 ? 3 : (width >= 600 ? 2 : 1);
            const spacing = 12.0;
            final tileWidth = (width - spacing * (columns - 1)) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: tileWidth,
                  child: StatTile(
                    label: 'Valor total',
                    value: formatMoney(summary.totalValue),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: StatTile(
                    label: 'Categorias ativas',
                    value: '${categories.length}',
                    icon: Icons.category_outlined,
                    color: const Color(0xFF5A5F9E),
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: StatTile(
                    label: 'Itens em alerta',
                    value: '${summary.lowStockCount + summary.outOfStockCount}',
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.warning,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final categoryCard = _CategoryCard(categories: categories);
            final topCard = _TopProductsCard(items: byValue);

            if (constraints.maxWidth >= 980) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: categoryCard),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: topCard),
                ],
              );
            }

            return Column(
              children: [
                categoryCard,
                const SizedBox(height: 16),
                topCard,
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _CriticalReport(items: controller.criticalProducts),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.categories});

  final List<CategoryStock> categories;

  @override
  Widget build(BuildContext context) {
    final total = categories.fold<double>(0, (sum, item) => sum + item.value);
    var maxValue = 0.0;
    for (final item in categories) {
      if (item.value > maxValue) maxValue = item.value;
    }
    if (maxValue <= 0) maxValue = 1;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Valor por categoria',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Baseado no custo unitário dos produtos em estoque.',
            style: TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
          const SizedBox(height: 16),
          if (categories.isEmpty)
            const Text(
              'Sem dados suficientes.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            )
          else
            for (final item in categories)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          formatMoney(item.value),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 44,
                          child: Text(
                            total == 0
                                ? '—'
                                : formatPercent(item.value / total),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: item.value <= 0
                            ? 0
                            : math.min(1, item.value / maxValue),
                        minHeight: 7,
                        backgroundColor: AppColors.bg,
                        color: AppColors.seed,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.items} produtos · '
                      '${formatQuantity(item.quantity)} unidades',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.items});

  final List<ProductStock> items;

  @override
  Widget build(BuildContext context) {
    final top = items.take(6).toList();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Maior valor em estoque',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 14),
          if (top.isEmpty)
            const Text(
              'Sem dados suficientes.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            )
          else
            for (var index = 0; index < top.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        top[index].product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatMoney(top[index].stockValue),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _CriticalReport extends StatelessWidget {
  const _CriticalReport({required this.items});

  final List<ProductStock> items;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Produtos abaixo do mínimo',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              StatusPill(
                label: '${items.length}',
                color: items.isEmpty ? AppColors.success : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Text(
              'Nenhum produto precisa de reposição agora.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in items)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Saldo ${formatQuantity(item.balance)} '
                          '${item.product.unit} · '
                          'mínimo ${formatQuantity(item.product.minStock)}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
