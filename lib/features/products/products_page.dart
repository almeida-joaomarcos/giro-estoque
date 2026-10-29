import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/product_stock.dart';
import '../../domain/models/stock_movement.dart';
import '../../state/inventory_controller.dart';
import '../movements/movement_dialog.dart';
import '../widgets/common.dart';
import 'product_form_dialog.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _search = TextEditingController();
  String? _category;
  bool _onlyCritical = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InventoryController>();

    var items = controller.products;
    if (_category != null) {
      items = items
          .where((item) => (item.product.category ?? '') == _category)
          .toList();
    }
    if (_onlyCritical) {
      items = items.where((item) => item.isCritical).toList();
    }

    final summary = controller.summary;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        PageHeader(
          title: 'Produtos',
          subtitle: '${summary.totalProducts} cadastrados · '
              '${summary.lowStockCount + summary.outOfStockCount} em alerta',
          actions: [
            FilledButton.icon(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Novo produto'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _search,
          decoration: InputDecoration(
            hintText: 'Buscar por nome, código de barras, SKU ou categoria',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar busca',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _search.clear();
                      controller.setSearch('');
                      setState(() {});
                    },
                  ),
          ),
          onChanged: (value) {
            controller.setSearch(value);
            setState(() {});
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              label: const Text('Todos'),
              selected: _category == null,
              onSelected: (_) => setState(() => _category = null),
            ),
            FilterChip(
              label: const Text('Só críticos'),
              selected: _onlyCritical,
              onSelected: (value) => setState(() => _onlyCritical = value),
              avatar: _onlyCritical
                  ? null
                  : const Icon(Icons.warning_amber_rounded, size: 16),
            ),
            for (final category in controller.categoriesInUse.take(6))
              FilterChip(
                label: Text(category),
                selected: _category == category,
                onSelected: (selected) =>
                    setState(() => _category = selected ? category : null),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (items.isEmpty)
          EmptyState(
            icon: Icons.search_off,
            title: 'Nenhum produto encontrado',
            message: _search.text.isEmpty
                ? 'Cadastre o primeiro produto para começar.'
                : 'Tente outro termo de busca ou remova os filtros.',
            action: _search.text.isEmpty
                ? FilledButton.icon(
                    onPressed: () => _openForm(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Cadastrar produto'),
                  )
                : null,
          )
        else
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0)
                    const Divider(height: 1, color: AppColors.line),
                  _ProductRow(
                    item: items[index],
                    onEdit: () => _openForm(context, item: items[index]),
                    onHistory: () => _openHistory(context, items[index]),
                    onMovement: () => showMovementDialog(
                      context,
                      product: items[index],
                      initialType: MovementType.entrada,
                    ),
                    onDelete: () => _confirmDelete(context, items[index]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _openForm(BuildContext context, {ProductStock? item}) async {
    final saved = await showProductDialog(context, product: item?.product);
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              item == null ? 'Produto cadastrado.' : 'Produto atualizado.'),
        ),
      );
    }
  }

  Future<void> _openHistory(BuildContext context, ProductStock item) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ProductHistoryDialog(item: item),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ProductStock item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir produto'),
        content: Text(
          'Excluir "${item.product.name}"? As movimentações desse produto '
          'também serão apagadas. Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<InventoryController>().deleteProduct(item.product.id!);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produto excluído.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível excluir: $error')),
      );
    }
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.item,
    required this.onEdit,
    required this.onHistory,
    required this.onMovement,
    required this.onDelete,
  });

  final ProductStock item;
  final VoidCallback onEdit;
  final VoidCallback onHistory;
  final VoidCallback onMovement;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final statusColor = item.isOutOfStock
        ? AppColors.danger
        : item.isLowStock
            ? AppColors.warning
            : AppColors.success;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Em telas estreitas escondemos o selo de status para não estourar.
        final compact = constraints.maxWidth < 430;

        return InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    item.isOutOfStock
                        ? Icons.block
                        : item.isLowStock
                            ? Icons.trending_down
                            : Icons.inventory_2_outlined,
                    size: 19,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
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
                          product.category ?? 'Sem categoria',
                          if ((product.barcode ?? '').isNotEmpty)
                            'EAN ${product.barcode}',
                          if ((product.sku ?? '').isNotEmpty)
                            'SKU ${product.sku}',
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
                const SizedBox(width: 8),
                if (item.isCritical && !compact)
                  StatusPill(
                    label: item.isOutOfStock ? 'Sem estoque' : 'Estoque baixo',
                    color: statusColor,
                  ),
                const SizedBox(width: 12),
                SizedBox(
                  width: compact ? 60 : 96,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatQuantity(item.balance),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        product.unit,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Ações',
                  onSelected: (value) {
                    switch (value) {
                      case 'movement':
                        onMovement();
                        break;
                      case 'edit':
                        onEdit();
                        break;
                      case 'history':
                        onHistory();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'movement',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.swap_vert, size: 18),
                        title: Text('Movimentar'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined, size: 18),
                        title: Text('Editar'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'history',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.history, size: 18),
                        title: Text('Histórico'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        title: Text(
                          'Excluir',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProductHistoryDialog extends StatefulWidget {
  const _ProductHistoryDialog({required this.item});

  final ProductStock item;

  @override
  State<_ProductHistoryDialog> createState() => _ProductHistoryDialogState();
}

class _ProductHistoryDialogState extends State<_ProductHistoryDialog> {
  late Future<List<StockMovement>> _future;

  @override
  void initState() {
    super.initState();
    _future = context
        .read<InventoryController>()
        .movementsForProduct(widget.item.product.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Fechar',
                  ),
                ],
              ),
              Text(
                'Saldo atual: '
                '${formatQuantityWithUnit(widget.item.balance, widget.item.product.unit)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 380,
                child: FutureBuilder<List<StockMovement>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Erro ao carregar: ${snapshot.error}'),
                      );
                    }
                    final movements = snapshot.data ?? const [];
                    if (movements.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nenhuma movimentação registrada.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: movements.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.line),
                      itemBuilder: (context, index) {
                        final movement = movements[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            iconForMovement(movement.type),
                            size: 18,
                            color: colorForMovement(movement.type),
                          ),
                          title: Text(movement.type.label),
                          subtitle: Text(
                            '${formatDateTime(movement.createdAt)}'
                            '${(movement.reason ?? '').isEmpty ? '' : ' · ${movement.reason}'}',
                          ),
                          trailing: Text(
                            '${movement.signedQuantity > 0 ? '+' : '−'}'
                            '${formatQuantity(movement.signedQuantity.abs())}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: movement.signedQuantity > 0
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
