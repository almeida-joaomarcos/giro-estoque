import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/product_stock.dart';
import '../../domain/models/stock_movement.dart';
import '../../state/inventory_controller.dart';
import '../movements/movement_dialog.dart';
import '../products/product_form_dialog.dart';
import '../widgets/common.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InventoryController>();
    final summary = controller.summary;
    final business = controller.config?.businessName ?? 'Meu negócio';

    if (controller.allProducts.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          PageHeader(
            title: 'Painel',
            subtitle: '$business · ${formatDate(DateTime.now())}',
          ),
          const SizedBox(height: 24),
          EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Seu estoque está vazio',
            message:
                'Cadastre o primeiro produto ou importe uma planilha em CSV '
                'para começar a acompanhar entradas, saídas e saldo.',
            action: FilledButton.icon(
              onPressed: () => _newProduct(context),
              icon: const Icon(Icons.add),
              label: const Text('Cadastrar produto'),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        PageHeader(
          title: 'Painel',
          subtitle: '$business · ${formatDate(DateTime.now())}',
          actions: [
            OutlinedButton.icon(
              onPressed: () => showMovementDialog(context),
              icon: const Icon(Icons.swap_vert),
              label: const Text('Movimentar'),
            ),
            FilledButton.icon(
              onPressed: () => _newProduct(context),
              icon: const Icon(Icons.add),
              label: const Text('Novo produto'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _StatGrid(
          tiles: [
            StatTile(
              label: 'Valor em estoque',
              value: formatMoney(summary.totalValue),
              icon: Icons.payments_outlined,
              caption: '${summary.totalProducts} produtos cadastrados',
            ),
            StatTile(
              label: 'Abaixo do mínimo',
              value: '${summary.lowStockCount + summary.outOfStockCount}',
              icon: Icons.warning_amber_rounded,
              color: AppColors.warning,
              caption: '${summary.outOfStockCount} sem estoque',
            ),
            StatTile(
              label: 'Movimentos hoje',
              value: '${summary.movementsToday}',
              icon: Icons.swap_vert,
              color: const Color(0xFF2A6F97),
              caption: '${summary.movementsWeek} nos últimos 7 dias',
            ),
            StatTile(
              label: 'Unidades em estoque',
              value: formatQuantity(summary.totalUnits),
              icon: Icons.inventory_outlined,
              color: const Color(0xFF5A5F9E),
              caption: 'Somando todos os produtos',
            ),
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final critical = _CriticalCard(items: controller.criticalProducts);
            final recent = _RecentCard(movements: controller.recentMovements);

            if (constraints.maxWidth >= 980) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: critical),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: recent),
                ],
              );
            }

            return Column(
              children: [
                critical,
                const SizedBox(height: 16),
                recent,
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _newProduct(BuildContext context) async {
    final created = await showProductDialog(context);
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produto cadastrado.')),
      );
    }
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100 ? 4 : (width >= 600 ? 2 : 1);
        const spacing = 12.0;
        final tileWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: tileWidth, child: tile),
          ],
        );
      },
    );
  }
}

class _CriticalCard extends StatelessWidget {
  const _CriticalCard({required this.items});

  final List<ProductStock> items;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(6).toList();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              const Text(
                'Estoque crítico',
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
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Nenhum produto abaixo do estoque mínimo. Bom trabalho!',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            )
          else
            for (final item in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.product.category ?? 'Sem categoria'} · '
                            'mínimo ${formatQuantity(item.product.minStock)} '
                            '${item.product.unit}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    StatusPill(
                      label:
                          '${formatQuantity(item.balance)} ${item.product.unit}',
                      color: item.isOutOfStock
                          ? AppColors.danger
                          : AppColors.warning,
                      icon:
                          item.isOutOfStock ? Icons.block : Icons.trending_down,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.movements});

  final List<StockMovement> movements;

  @override
  Widget build(BuildContext context) {
    final visible = movements.take(6).toList();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.history, size: 18, color: AppColors.muted),
              SizedBox(width: 8),
              Text(
                'Últimas movimentações',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Nenhuma movimentação registrada ainda.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            )
          else
            for (final movement in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: colorForMovement(movement.type)
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        iconForMovement(movement.type),
                        size: 15,
                        color: colorForMovement(movement.type),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            movement.productName ?? 'Produto',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            '${movement.type.label} · '
                            '${formatRelative(movement.createdAt)}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${movement.signedQuantity > 0 ? '+' : '−'}'
                      '${formatQuantity(movement.signedQuantity.abs())}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: movement.signedQuantity > 0
                            ? AppColors.success
                            : AppColors.danger,
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
