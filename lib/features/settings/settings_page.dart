import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_picker_helper.dart';
import '../../domain/models/business_config.dart';
import '../../domain/models/segment.dart';
import '../../state/inventory_controller.dart';
import '../widgets/common.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InventoryController>();
    final config = controller.config;
    final segment = controller.segment;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const PageHeader(
          title: 'Ajustes',
          subtitle: 'Negócio, locais e dados do aplicativo',
        ),
        const SizedBox(height: 20),
        if (config != null)
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(
                  icon: iconForSegment(segment),
                  title: 'Negócio',
                  action: TextButton.icon(
                    onPressed: _working
                        ? null
                        : () => _editBusiness(context, controller),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Editar'),
                  ),
                ),
                const SizedBox(height: 14),
                _InfoRow(label: 'Nome', value: config.businessName),
                _InfoRow(label: 'Segmento', value: segment.label),
                _InfoRow(
                  label: 'Controle de lote',
                  value: config.tracksBatch ? 'Ativado' : 'Desativado',
                ),
                _InfoRow(
                  label: 'Controle de validade',
                  value: config.tracksExpiry ? 'Ativado' : 'Desativado',
                ),
                _InfoRow(
                  label: 'Múltiplos locais',
                  value: config.multiLocation ? 'Ativado' : 'Desativado',
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                icon: Icons.place_outlined,
                title: 'Locais de estoque',
                action: TextButton.icon(
                  onPressed: _working ? null : () => _addLocation(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Novo local'),
                ),
              ),
              const SizedBox(height: 6),
              for (final location in controller.locations)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    location.isDefault
                        ? Icons.star_outline
                        : Icons.warehouse_outlined,
                    size: 20,
                    color: location.isDefault
                        ? AppColors.warning
                        : AppColors.muted,
                  ),
                  title: Text(location.name),
                  subtitle: location.isDefault
                      ? const Text(
                          'Local padrão',
                          style: TextStyle(fontSize: 11.5),
                        )
                      : null,
                  trailing: controller.locations.length <= 1
                      ? null
                      : IconButton(
                          tooltip: 'Remover local',
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: _working
                              ? null
                              : () => _removeLocation(context, location.id!),
                        ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.folder_outlined,
                title: 'Dados e backup',
              ),
              const SizedBox(height: 6),
              const Text(
                'Os dados ficam no SQLite deste dispositivo. Faça backup antes '
                'de trocar de computador ou celular.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _working ? null : () => _exportCsv(context),
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text('Exportar CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _working ? null : () => _importCsv(context),
                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                    label: const Text('Importar CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _working ? null : () => _backup(context),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Fazer backup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _working ? null : () => _restore(context),
                    icon: const Icon(Icons.restore_outlined, size: 18),
                    label: const Text('Restaurar backup'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.line),
              const SizedBox(height: 12),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
                onPressed: _working ? null : () => _reset(context),
                icon: const Icon(Icons.delete_forever_outlined, size: 18),
                label: const Text('Apagar todos os dados'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.info_outline,
                title: 'Sobre o Giro',
              ),
              const SizedBox(height: 10),
              const Text(
                'Giro 0.1.0 · controle de estoque offline para pequenos negócios. '
                'Feito em Flutter para Windows e Android.',
                style: TextStyle(
                    color: AppColors.muted, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 10),
              SelectableText(
                AppDatabase.instance.path,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editBusiness(
    BuildContext context,
    InventoryController controller,
  ) async {
    final config = controller.config;
    if (config == null) return;

    final result = await showDialog<_BusinessResult>(
      context: context,
      builder: (_) => _BusinessDialog(config: config),
    );
    if (result == null) return;

    setState(() => _working = true);
    try {
      await controller.updateConfig(
        config.copyWith(
          businessName: result.name,
          segment: result.segment,
          tracksBatch: result.segment.tracksBatch,
          tracksExpiry: result.segment.tracksExpiry,
          multiLocation: result.segment.multiLocation,
        ),
      );
      _toast('Configuração atualizada.');
    } catch (error) {
      _toast('Erro ao salvar: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _addLocation(BuildContext context) async {
    final controller = context.read<InventoryController>();
    final name = await _promptText(
      context,
      title: 'Novo local',
      label: 'Nome do local',
      hint: 'Ex.: Depósito, Loja 2, Caminhão',
    );
    if (name == null || name.trim().isEmpty) return;

    setState(() => _working = true);
    try {
      await controller.addLocation(name);
      _toast('Local criado.');
    } catch (error) {
      _toast('Erro ao criar local: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _removeLocation(BuildContext context, int id) async {
    setState(() => _working = true);
    try {
      await context.read<InventoryController>().removeLocation(id);
      _toast('Local removido.');
    } catch (error) {
      _toast('Erro ao remover: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    setState(() => _working = true);
    try {
      final path = await context.read<InventoryController>().exportCsv();
      await Clipboard.setData(ClipboardData(text: path));
      _toast('CSV salvo e caminho copiado: $path');
    } catch (error) {
      _toast('Erro ao exportar: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _importCsv(BuildContext context) async {
    final controller = context.read<InventoryController>();
    final path = await pickFile(extensions: ['csv']);
    if (path == null) return;

    setState(() => _working = true);
    try {
      final count = await controller.importCsv(path);
      _toast('$count produtos importados.');
    } catch (error) {
      _toast('Erro ao importar: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _backup(BuildContext context) async {
    setState(() => _working = true);
    try {
      final path = await context.read<InventoryController>().backupDatabase();
      await Clipboard.setData(ClipboardData(text: path));
      _toast('Backup criado: $path');
    } catch (error) {
      _toast('Erro no backup: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restore(BuildContext context) async {
    final path = await pickFile(extensions: ['db', 'sqlite']);
    if (path == null) return;
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurar backup'),
        content: const Text(
          'Os dados atuais serão substituídos pelo backup escolhido. '
          'Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() => _working = true);
    try {
      await context.read<InventoryController>().restoreDatabase(path);
      _toast('Backup restaurado.');
    } catch (error) {
      _toast('Erro ao restaurar: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _reset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apagar todos os dados'),
        content: const Text(
          'Isso remove produtos, movimentações e a configuração do negócio. '
          'Exporte um CSV ou faça backup antes. Não é possível desfazer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Apagar tudo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() => _working = true);
    try {
      await context.read<InventoryController>().resetAll();
      if (!mounted) return;
      _toast('Dados apagados.');
    } catch (error) {
      _toast('Erro ao apagar: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _BusinessResult {
  const _BusinessResult(this.name, this.segment);

  final String name;
  final Segment segment;
}

class _BusinessDialog extends StatefulWidget {
  const _BusinessDialog({required this.config});

  final BusinessConfig config;

  @override
  State<_BusinessDialog> createState() => _BusinessDialogState();
}

class _BusinessDialogState extends State<_BusinessDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.config.businessName);
  late Segment _segment = widget.config.segment;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar negócio'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome do negócio'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Informe o nome.'
                  : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<Segment>(
              initialValue: _segment,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Segmento'),
              items: [
                for (final segment in Segment.values)
                  DropdownMenuItem(
                    value: segment,
                    child: Text(
                      segment.label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _segment = value);
              },
            ),
            const SizedBox(height: 10),
            Text(
              'Trocar o segmento ajusta o controle de lote, validade e locais. '
              'Produtos e movimentações existentes não são alterados.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.muted.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              _BusinessResult(_name.text.trim(), _segment),
            );
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

Future<String?> _promptText(
  BuildContext context, {
  required String title,
  required String label,
  String? hint,
}) async {
  final controller = TextEditingController();

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label, hintText: hint),
        onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: const Text('Criar'),
        ),
      ],
    ),
  );

  // Descarta o controller só depois da animação de fechamento do diálogo.
  Future<void>.delayed(
    const Duration(milliseconds: 400),
    controller.dispose,
  );

  return result;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    this.action,
  });

  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.ink,
          ),
        ),
        const Spacer(),
        if (action != null) action!,
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
