import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/constants.dart';
import '../models/pak_entry.dart';

/// UE4/UE5 PAK 文件解析器
class PakParser {
  PakParser(this.pakPath);

  final String pakPath;

  int _version = 0;
  int _indexOffset = 0;
  int _indexSize = 0;
  bool _encryptedIndex = false;

  /// 读取 PAK 文件索引
  Future<List<PakEntry>> readIndex() async {
    final file = File(pakPath);
    if (!file.existsSync()) {
      throw FileSystemException('PAK 文件不存在', pakPath);
    }

    final raf = await file.open(mode: FileMode.read);
    try {
      final fileSize = await raf.length();

      // 读取文件头
      await raf.setPosition(0);
      final headerBytes = await raf.read(64);
      if (headerBytes.length < 12) {
        throw FormatException('PAK 文件过短');
      }

      final header = ByteData.sublistView(headerBytes);
      final magic = header.getUint32(0, Endian.little);
      if (magic != Aion2Constants.pakMagic) {
        throw FormatException(
          '无效的 PAK 魔数: 0x${magic.toRadixString(16)} (期望 0x${Aion2Constants.pakMagic.toRadixString(16)})',
        );
      }

      _version = header.getInt32(4, Endian.little);
      _indexOffset = header.getInt64(8, Endian.little);
      _indexSize = header.getInt64(16, Endian.little);

      if (_version >= 6) {
        _encryptedIndex = headerBytes.length > 28 && headerBytes[28] != 0;
      }

      // 部分 PAK 索引在文件末尾
      if (_indexOffset <= 0 || _indexOffset >= fileSize) {
        // 尝试从末尾读取
        if (fileSize > 44) {
          await raf.setPosition(fileSize - 44);
          final tailBytes = await raf.read(44);
          final tail = ByteData.sublistView(tailBytes);
          final tailMagic = tail.getUint32(0, Endian.little);
          if (tailMagic == Aion2Constants.pakMagic) {
            _indexOffset = tail.getInt64(8, Endian.little);
            _indexSize = tail.getInt64(16, Endian.little);
            _version = tail.getInt32(4, Endian.little);
          }
        }
      }

      if (_indexOffset <= 0 || _indexSize <= 0) {
        throw FormatException('无法定位 PAK 索引 (version=$_version)');
      }

      if (_encryptedIndex) {
        throw UnsupportedError('PAK 索引已加密，请在设置中配置 AES 密钥后使用 retoc/repak 解包');
      }

      await raf.setPosition(_indexOffset);
      final indexData = await raf.read(_indexSize);
      return _parseIndex(indexData);
    } finally {
      await raf.close();
    }
  }

  List<PakEntry> _parseIndex(Uint8List data) {
    final entries = <PakEntry>[];
    final reader = _ByteReader(data);

    // 索引以 mount point 字符串开头
    final mountPoint = reader.readFString();
    if (mountPoint.isEmpty && _version >= 1) {
      // 某些版本 mount point 可能为空
    }

    final entryCount = reader.readInt32();
    for (var i = 0; i < entryCount; i++) {
      try {
        final entry = _readEntry(reader);
        if (entry != null) entries.add(entry);
      } catch (_) {
        break;
      }
    }

    return entries;
  }

  PakEntry? _readEntry(_ByteReader reader) {
    final filename = reader.readFString();
    if (filename.isEmpty) return null;

    final offset = reader.readInt64();
    final compressedSize = reader.readInt64();
    final uncompressedSize = reader.readInt64();

    int compressionMethod = 0;
    var isEncrypted = false;

    if (_version <= 4) {
      reader.readInt32(); // timestamp
      compressionMethod = reader.readInt32();
    } else {
      compressionMethod = reader.readInt32();
      if (_version >= 5) {
        reader.readInt64(); // compressed hash
        isEncrypted = reader.readUint8() != 0;
        if (_version >= 7) {
          reader.readInt32(); // compression block size
          reader.readInt32(); // compression block count - simplified skip
        }
      }
    }

    return PakEntry(
      filename: filename,
      offset: offset,
      compressedSize: compressedSize,
      uncompressedSize: uncompressedSize,
      compressionMethod: compressionMethod,
      isEncrypted: isEncrypted,
    );
  }

  /// 提取单个文件（仅支持未压缩、未加密条目）
  Future<void> extractEntry(PakEntry entry, String outputDir) async {
    if (entry.isEncrypted) {
      throw UnsupportedError('加密条目需要使用外部工具解包: ${entry.filename}');
    }
    if (entry.isCompressed) {
      throw UnsupportedError('压缩条目需要使用 repak/retoc 解包: ${entry.filename}');
    }

    final outPath = '$outputDir/${entry.filename.replaceAll('/', Platform.pathSeparator)}';
    final outFile = File(outPath);
    await outFile.parent.create(recursive: true);

    final raf = await File(pakPath).open(mode: FileMode.read);
    try {
      await raf.setPosition(entry.offset);
      final data = await raf.read(entry.compressedSize);
      await outFile.writeAsBytes(data);
    } finally {
      await raf.close();
    }
  }

  /// 获取 PAK 基本信息
  Future<Map<String, dynamic>> getInfo() async {
    final file = File(pakPath);
    final raf = await file.open(mode: FileMode.read);
    try {
      final headerBytes = await raf.read(64);
      final header = ByteData.sublistView(headerBytes);
      return {
        'magic': '0x${header.getUint32(0, Endian.little).toRadixString(16)}',
        'version': header.getInt32(4, Endian.little),
        'indexOffset': header.getInt64(8, Endian.little),
        'indexSize': header.getInt64(16, Endian.little),
        'fileSize': await raf.length(),
        'encryptedIndex': _encryptedIndex,
      };
    } finally {
      await raf.close();
    }
  }
}

class _ByteReader {
  _ByteReader(this._data);

  final Uint8List _data;
  int _pos = 0;

  int readInt32() {
    final v = ByteData.sublistView(_data, _pos, _pos + 4).getInt32(0, Endian.little);
    _pos += 4;
    return v;
  }

  int readInt64() {
    final v = ByteData.sublistView(_data, _pos, _pos + 8).getInt64(0, Endian.little);
    _pos += 8;
    return v;
  }

  int readUint8() {
    final v = _data[_pos];
    _pos += 1;
    return v;
  }

  String readFString() {
    if (_pos + 4 > _data.length) return '';
    final length = readInt32();
    if (length == 0) return '';
    if (length < 0) {
      // UTF-16
      final charCount = -length;
      final byteCount = (charCount - 1) * 2;
      if (_pos + byteCount > _data.length) return '';
      final chars = ByteData.sublistView(_data, _pos, _pos + byteCount);
      _pos += byteCount + 2; // null terminator
      final codeUnits = <int>[];
      for (var i = 0; i < byteCount; i += 2) {
        codeUnits.add(chars.getUint16(i, Endian.little));
      }
      return String.fromCharCodes(codeUnits);
    }
    if (_pos + length > _data.length) return '';
    final str = utf8.decode(_data.sublist(_pos, _pos + length - 1));
    _pos += length;
    return str;
  }
}
