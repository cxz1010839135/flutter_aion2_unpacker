class PakEntry {
  const PakEntry({
    required this.filename,
    required this.offset,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.compressionMethod,
    required this.isEncrypted,
  });

  final String filename;
  final int offset;
  final int compressedSize;
  final int uncompressedSize;
  final int compressionMethod;
  final bool isEncrypted;

  bool get isCompressed => compressionMethod != 0;

  String get sizeFormatted {
    final size = uncompressedSize > 0 ? uncompressedSize : compressedSize;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
