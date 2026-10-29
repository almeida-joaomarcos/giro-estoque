import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/product_stock.dart';
import '../../domain/models/stock_movement.dart';
import '../../state/inventory_controller.dart';

Future<bool?> showMovementDialog(
  BuildContext context, {
  ProductStock? product,
  MovementType initialType = MovementType.entrada,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _MovementDialog(product: product, initialType: initialType),
  );
}

class _MovementDialog extends StatefulWidget {
  const _MovementDialog({this.product, required this.initialType});

  final ProductStock? product;
  final MovementType initialType;

  @override
  State<_MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<_MovementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _cost = TextEditingController();
  final _note = TextEditingController();
  final _reason = TextEditingController();

  late MovementType _type = widget.initialType;
  late ProductStock? _product = widget.product;
  int? _locationId;
  int? _targetLocationId;
  bool _saving = false;

  bool get _isAdjust => _type == MovementType.ajuste;
  bool get _isTransfer => _type == MovementType.transferenciaSaida;

  @override
  void initState() {
    super.initState();
    final controller = context.read<InventoryController>();
    _product = widget.product ??
        (controller.allProducts.isNotEmpty
            ? controller.allProducts.first
            : null);
    _locationId = controller.defaultLocation.id;
    if (controller.locations.length > 1) {
      _targetLocationId = controller.locations
          .firstWhere(
            (location) => location.id != _locationId,
            orElse: () => controller.locations.last,
          )
          .id;
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    _cost.dispose();
    _note.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_product == null) {
      _snack('Escolha o produto.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final quantity = parseNumber(_quantity.text) ?? 0;
    final controller = context.read<InventoryController>();
    final product = _product!.product;

    setState(() => _saving = true);
    try {
      if (_isAdjust) {
        await controller.adjustStock(
          product: product,
          counted: quantity,
          locationId: _locationId ?? controller.defaultLocation.id ?? 0,
          note: _note.text,
        );
      } else if (_isTransfer) {
        final target = _targetLocationId;
        if (target == null) {
          setState(() => _saving = false);
          _snack('Escolha o local de destino.');
          return;
        }
        await controller.registerTransfer(
          product: product,
          quantity: quantity,
          fromLocationId: _locationId ?? controller.defaultLocation.id ?? 0,
          toLocationId: target,
          note: _note.text,
        );
      } else {
        await controller.registerMovement(
          product: product,
          type: _type,
          quantity: quantity,
          locationId: _locationId ?? controller.defaultLocation.id ?? 0,
          unitCost: parseNumber(_cost.text) ?? product.costPrice,
          reason: _reason.text,
          note: _note.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(_messageOf(error));
    }
  }

  String _messageOf(Object error) {
    final text = error.toString();
    if (error is ArgumentError) {
      return text.replaceFirst('Invalid argument(s): ', '');
    }
    if (error is StateError) return text.replaceFirst('Bad state: ', '');
    return text;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InventoryController>();
    final products = controller.allProducts;
    final locations = controller.locations;
    final canTransfer = locations.length > 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Movimentar estoque',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                      tooltip: 'Fechar',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final type in [
                      ...MovementType.manual,
                      MovementType.transferenciaSaida,
                    ])
                      ChoiceChip(
                        label: Text(
                          type == MovementType.transferenciaSaida
                              ? 'Transferência'
                              : type.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: _type == type,
                        onSelected: (selected) {
                          if (!selected) return;
                          if (type == MovementType.transferenciaSaida &&
                              !canTransfer) {
                            _snack(
                              'Crie um segundo local nos Ajustes para '
                              'transferir estoque.',
                            );
                            return;
                          }
                          setState(() => _type = type);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _product?.product.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Produto'),
                  items: [
                    for (final item in products)
                      DropdownMenuItem(
                        value: item.product.id,
                        child: Text(
                          '${item.product.name} · '
                          '${formatQuantityWithUnit(item.balance, item.product.unit)}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                  onChanged: (id) {
                    if (id == null) return;
                    setState(() {
                      _product = products.firstWhere(
                        (item) => item.product.id == id,
                      );
                    });
                  },
                ),
                if (_product != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Saldo atual: '
                    '${formatQuantityWithUnit(_product!.balance, _product!.product.unit)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantity,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText:
                              _isAdjust ? 'Quantidade contada' : 'Quantidade',
                          suffixText: _product?.product.unit,
                        ),
                        validator: (value) {
                          final number = parseNumber(value);
                          if (number == null) return 'Informe a quantidade';
                          if (number < 0) return 'Valor inválido';
                          if (!_isAdjust && number == 0) {
                            return 'Deve ser maior que zero';
                          }
                          return null;
                        },
                      ),
                    ),
                    if (!_isAdjust && !_isTransfer) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _cost,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Custo unitário',
                            prefixText: r'R$ ',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_isTransfer) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _locationId,
                          decoration: const InputDecoration(labelText: 'De'),
                          items: [
                            for (final location in locations)
                              DropdownMenuItem(
                                value: location.id,
                                child: Text(location.name),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _locationId = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _targetLocationId,
                          decoration: const InputDecoration(labelText: 'Para'),
                          items: [
                            for (final location in locations)
                              DropdownMenuItem(
                                value: location.id,
                                child: Text(location.name),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _targetLocationId = value),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                if (!_isAdjust)
                  TextFormField(
                    controller: _reason,
                    decoration: InputDecoration(
                      labelText: 'Motivo',
                      hintText: _isTransfer
                          ? 'Ex.: abastecimento da loja'
                          : 'Ex.: compra de fornecedor',
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Observação (opcional)',
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving || products.isEmpty ? null : _save,
                      child: Text(_saving ? 'Registrando...' : 'Registrar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
