import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/stock_movement.dart';
import '../../state/inventory_controller.dart';
import '../widgets/common.dart';
import 'movement_dialog.dart';

class MovementsPage extends StatefulWidget {
  const MovementsPage({super.key});

  @override
  State<MovementsPage> createState() => _MovementsPageState();
}

class _MovementsPageState extends State<MovementsPage> {
  String _filter = 'todas';

  static const Map<String, String> _filters = {
    'todas': 'Todas',
    'entrada': 'Entradas',
    'saida': 'Saídas',
    'perda': 'Perdas',
    'ajuste': 'Ajustes',
    'transferencia': 'Transferências',
  };

  bool _matches(StockMovement movement) {
    switch (_filter) {
      case 'entrada':
        return movement.type.isInbound && movement.type != MovementType.ajuste;
      case 'saida':
        return movement.type == MovementType.saida;
      case 'perda':
        return movement.type == MovementType.perda;
      case 'ajuste':
        return movement.type == MovementType.ajuste;
      case 'transferencia':
        return movement.type == MovementType.transferenciaEntrada ||
            movement.type == MovementType.transferenciaSaida;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InventoryController>();
    final movements =
        controller.recentMovements.where(_matches).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        PageHeader(
          title: 'Movimentos',
          subtitle:
              '${controller.summary.movementsWeek} registros nos últimos 7 dias',
          actions: [
            FilledButton.icon(
              onPressed: () => showMovementDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Registrar'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in _filters.entries)
              FilterChip(
                label: Text(entry.value),
                selected: _filter == entry.key,
                onSelected: (_) => setState(() => _filter = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (movements.isEmpty)
          EmptyState(
            icon: Icons.swap_vert,
            title: 'Nenhuma movimentação',
            message: _filter == 'todas'
                ? 'Registre entradas, saídas, perdas e ajustes para acompanhar '
                    'o histórico do seu estoque.'
                : 'Não há registros desse tipo no período.',
            action: _filter == 'todas'
                ? FilledButton.icon(
                    onPressed: () => showMovementDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Registrar movimentação'),
                  )
                : null,
          )
        else
          _MovementList(movements: movements),
      ],
    );
  }
}

class _MovementList extends StatelessWidget {
  const _MovementList({required this.movements});

  final List<StockMovement> movements;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    String? currentDay;

    for (final movement in movements) {
      final day = formatDate(movement.createdAt);
      if (day != currentDay) {
        currentDay = day;
        children.add(
          Padding(
            padding: EdgeInsets.only(
              top: children.isEmpty ? 0 : 18,
              bottom: 8,
              left: 4,
            ),
            child: Text(
              _dayLabel(movement.createdAt),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: AppColors.muted,
              ),
            ),
          ),
        );
      }
      children.add(_MovementTile(movement: movement));
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final difference = today.difference(target).inDays;

    if (difference == 0) return 'HOJE · ${formatDate(date)}';
    if (difference == 1) return 'ONTEM · ${formatDate(date)}';
    return formatDate(date);
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement});

  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    final color = colorForMovement(movement.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(iconForMovement(movement.type), size: 18, color: color),
            ),
            const SizedBox(width: 12),
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
                      fontSize: 13.5,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      movement.type.label,
                      movement.locationName ?? 'Principal',
                      if ((movement.reason ?? '').isNotEmpty) movement.reason!,
                      formatDateTime(movement.createdAt).substring(11),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${movement.signedQuantity > 0 ? '+' : '−'}'
                  '${formatQuantity(movement.signedQuantity.abs())}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: movement.signedQuantity > 0
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
                if (movement.totalCost > 0)
                  Text(
                    formatMoney(movement.totalCost),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10.5,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
