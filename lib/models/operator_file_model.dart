class OperatorFileModel {
  final int id;
  final String filename;
  final String mimeType;
  final int fileSize;
  final String uploadedBy; // "operator" | "admin"
  final String description;
  final DateTime createdAt;

  const OperatorFileModel({
    required this.id,
    required this.filename,
    required this.mimeType,
    required this.fileSize,
    required this.uploadedBy,
    required this.description,
    required this.createdAt,
  });

  bool get isFromAdmin => uploadedBy == 'admin';

  String get fileSizeLabel {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory OperatorFileModel.fromJson(Map<String, dynamic> json) =>
      OperatorFileModel(
        id: json['id'] as int,
        filename: json['filename'] as String,
        mimeType: (json['mime_type'] as String?) ?? '',
        fileSize: (json['file_size'] as int?) ?? 0,
        uploadedBy: (json['uploaded_by'] as String?) ?? 'operator',
        description: (json['description'] as String?) ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
