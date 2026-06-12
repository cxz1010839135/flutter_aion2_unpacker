class AesKeyCandidate {
  const AesKeyCandidate({
    required this.key,
    required this.source,
    this.verified = false,
    this.label,
  });

  final String key;
  final String source;
  final bool verified;
  final String? label;

  String get displayName {
    if (label == 'verified') return '$_shortKey (已验证)';
    if (label != null && label!.isNotEmpty) return label!;
    return _shortKey;
  }

  String get _shortKey {
    if (key.length <= 18) return key;
    return '${key.substring(0, 10)}...${key.substring(key.length - 8)}';
  }

  factory AesKeyCandidate.fromJson(Map<String, dynamic> json) {
    return AesKeyCandidate(
      key: json['key'] as String,
      source: json['source'] as String? ?? '未知来源',
      verified: json['verified'] as bool? ?? false,
      label: json['label'] as String?,
    );
  }
}
