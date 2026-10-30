import 'package:file_picker/file_picker.dart';

/// Abre o seletor de arquivos e devolve o caminho escolhido.
Future<String?> pickFile({required List<String> extensions}) async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
  );

  if (files.isEmpty) return null;
  return files.first.path;
}
