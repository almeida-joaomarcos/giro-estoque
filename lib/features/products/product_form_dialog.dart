import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/product.dart';
import '../../domain/models/segment.dart';
import '../../state/inventory_controller.dart';

Future<bool?> showProductDialog(BuildContext context, {Product? product}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ProductDialog(product: product),
  );
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({this.product});

  final Product? product;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _barcode;
  late final TextEditingController _category;
  late final TextEditingController _cost;
  late final TextEditingController _sale;
  late final TextEditingController _minStock;

  late String _unit;
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _sku = TextEditingController(text: product?.sku ?? '');
    _barcode = TextEditingController(text: product?.barcode ?? '');
    _category = TextEditingController(text: product?.category ?? '');
    _cost = TextEditingController(
      text: product == null ? '' : product.costPrice.toStringAsFixed(2),
    );
    _sale = TextEditingController(
      text: product == null ? '' : product.salePrice.toStringAsFixed(2),
    );
    _minStock = TextEditingController(
      text: product == null ? '' : product.minStock.toStringAsFixed(0),
    );

    final segment = context.read<InventoryController>().segment;
    _unit = product?.unit ?? segment.defaultUnit;
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _barcode.dispose();
    _category.dispose();
    _cost.dispose();
    _sale.dispose();
    _minStock.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final controller = context.read<InventoryController>();

    final product = Product(
      id: widget.product?.id,
      name: _name.text.trim(),
      sku: _sku.text,
      barcode: _barcode.text,
      category: _category.text,
      unit: _unit,
      costPrice: parseNumber(_cost.text) ?? 0,
      salePrice: parseNumber(_sale.text) ?? 0,
      minStock: parseNumber(_minStock.text) ?? 0,
      createdAt: widget.product?.createdAt,
      active: widget.product?.active ?? true,
    );

    try {
      if (_isEditing) {
        await controller.updateProduct(product);
      } else {
        await controller.createProduct(product);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InventoryController>();
    final segment = controller.segment;
    final units = <String>{...segment.units, ...Units.all}.toList();
    final categories = controller.categoriesInUse;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
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
                    Text(
                      _isEditing ? 'Editar produto' : 'Novo produto',
                      style: const TextStyle(
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
                const SizedBox(height: 8),
                TextFormField(
                  controller: _name,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nome do produto *',
                    hintText: 'Ex.: Arroz branco 5 kg',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return 'Informe o nome do produto.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _sku,
                        decoration: const InputDecoration(
                          labelText: 'SKU / código interno',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _barcode,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Código de barras',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _category,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          hintText: 'Ex.: Mercearia',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            units.contains(_unit) ? _unit : units.first,
                        decoration: const InputDecoration(labelText: 'Unidade'),
                        items: [
                          for (final unit in units)
                            DropdownMenuItem(
                              value: unit,
                              child: Text(
                                '${Units.labels[unit] ?? unit} ($unit)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _unit = value);
                        },
                      ),
                    ),
                  ],
                ),
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final category in categories.take(6))
                        ActionChip(
                          label: Text(
                            category,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          onPressed: () =>
                              setState(() => _category.text = category),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        controller: _cost,
                        label: 'Custo (R\$)',
                        allowEmpty: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NumberField(
                        controller: _sale,
                        label: 'Preço de venda',
                        allowEmpty: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NumberField(
                        controller: _minStock,
                        label: 'Estoque mínimo',
                        allowEmpty: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'O saldo é calculado pelas movimentações — não é digitado '
                  'no cadastro.',
                  style: TextStyle(
                    color: AppColors.muted.withValues(alpha: 0.95),
                    fontSize: 11.5,
                  ),
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      for (final item in controller.allProducts) {
                        if (item.product.id == widget.product!.id) {
                          return Text(
                            'Saldo atual: '
                            '${formatQuantityWithUnit(item.balance, _unit)}',
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
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
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Salvando...' : 'Salvar produto'),
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

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    this.allowEmpty = false,
  });

  final TextEditingController controller;
  final String label;
  final bool allowEmpty;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return allowEmpty ? null : 'Obrigatório';
        }
        final number = parseNumber(value);
        if (number == null) return 'Número inválido';
        if (number < 0) return 'Use valor positivo';
        return null;
      },
    );
  }
}
