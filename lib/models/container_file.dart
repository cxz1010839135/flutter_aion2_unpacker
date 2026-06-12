import 'dart:io';

enum ContainerType { pak, utoc, ucas, unknown }

class ContainerFile {
  const ContainerFile({
    required this.path,
    required this.name,
    required this.type,
    required this.size,
    this.relativePath = '',
  });

  final String path;
  final String name;
  final ContainerType type;
  final int size;
  final String relativePath;

  String get sizeFormatted => formatSize(size);

  static String formatSize(int bytes) => _formatSize(bytes);

  static ContainerType typeFromExtension(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    return switch (ext) {
      'pak' => ContainerType.pak,
      'utoc' => ContainerType.utoc,
      'ucas' => ContainerType.ucas,
      _ => ContainerType.unknown,
    };
  }

  static ContainerFile fromFile(File file, {String relativePath = ''}) {
    final name = file.path.split(Platform.pathSeparator).last;
    return ContainerFile(
      path: file.path,
      name: name,
      type: typeFromExtension(name),
      size: file.lengthSync(),
      relativePath: relativePath,
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
