enum ExtractStatus { pending, running, success, failed, cancelled }

class ExtractTask {
  ExtractTask({
    required this.id,
    required this.sourcePath,
    required this.outputPath,
    this.selectedEntries = const [],
    this.status = ExtractStatus.pending,
    this.progress = 0.0,
    this.message = '',
    this.logs = const [],
  });

  final String id;
  final String sourcePath;
  final String outputPath;
  final List<String> selectedEntries;
  ExtractStatus status;
  double progress;
  String message;
  List<String> logs;

  ExtractTask copyWith({
    ExtractStatus? status,
    double? progress,
    String? message,
    List<String>? logs,
  }) {
    return ExtractTask(
      id: id,
      sourcePath: sourcePath,
      outputPath: outputPath,
      selectedEntries: selectedEntries,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      logs: logs ?? this.logs,
    );
  }
}
