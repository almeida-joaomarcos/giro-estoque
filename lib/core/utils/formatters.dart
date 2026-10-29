import 'package:intl/intl.dart';

final NumberFormat _money = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: r'R$',
  decimalDigits: 2,
);

final NumberFormat _quantity = NumberFormat('#,##0.###', 'pt_BR');

String formatMoney(double value) => _money.format(value);

String formatQuantity(double value) {
  final formatted = _quantity.format(value);
  return formatted;
}

String formatQuantityWithUnit(double value, String unit) {
  return '${_quantity.format(value)} $unit';
}

String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String formatDateTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${formatDate(date)} $hour:$minute';
}

String formatRelative(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inMinutes < 1) return 'agora';
  if (difference.inMinutes < 60) return 'há ${difference.inMinutes} min';
  if (difference.inHours < 24) return 'há ${difference.inHours} h';
  if (difference.inDays == 1) return 'ontem';
  if (difference.inDays < 7) return 'há ${difference.inDays} dias';
  return formatDate(date);
}

String formatPercent(double value) {
  return '${(value * 100).round()}%';
}

/// Converte texto digitado em português ("12,5") em double.
double? parseDecimal(String? value) {
  if (value == null) return null;
  final clean = value.trim().replaceAll('.', '').replaceAll(',', '.');
  if (clean.isEmpty) return null;
  return double.tryParse(clean);
}

/// Converte o que o usuário digitou em número, aceitando vírgula ou ponto.
///
/// Diferente de [parseDecimal], aqui os pontos são tratados como separador
/// decimal quando não há vírgula (ex.: "12.5").
double? parseNumber(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.contains(',')) {
    return double.tryParse(trimmed.replaceAll('.', '').replaceAll(',', '.'));
  }
  return double.tryParse(trimmed);
}
