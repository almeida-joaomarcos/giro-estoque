import 'package:file_picker/file_picker.dart';

/// Abre o seletor de arquivos e devolve o caminho escolhido.
Future<String?> pickFile({required List<String> extensions}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
    withData: false,
  );

  if (result == null || result.files.isEmpty) return null;
  return result.files.first.path;
}
