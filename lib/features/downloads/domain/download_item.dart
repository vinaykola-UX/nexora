/// Categories for academic downloads in Nexora AI
enum DownloadCategory {
  all,
  notes,
  syllabus,
  questionPaper,
  results,
  other;

  String get label {
    switch (this) {
      case DownloadCategory.all:
        return 'All';
      case DownloadCategory.notes:
        return 'Notes & Units';
      case DownloadCategory.syllabus:
        return 'Syllabus';
      case DownloadCategory.questionPaper:
        return 'Question Papers';
      case DownloadCategory.results:
        return 'Results';
      case DownloadCategory.other:
        return 'Other';
    }
  }
}

/// Represents an offline downloaded academic file or document
class DownloadItem {
  final String id;
  final String title;
  final String fileName;
  final String filePath;
  final int fileSizeBytes;
  final DateTime downloadedAt;
  final String subject;
  final int? unit;
  final DownloadCategory category;
  final String? downloadUrl;

  const DownloadItem({
    required this.id,
    required this.title,
    required this.fileName,
    required this.filePath,
    required this.fileSizeBytes,
    required this.downloadedAt,
    required this.subject,
    this.unit,
    this.category = DownloadCategory.notes,
    this.downloadUrl,
  });

  /// Formatted human-readable file size (e.g. "1.2 MB", "450 KB")
  String get formattedSize {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    } else if (fileSizeBytes < 1024 * 1024) {
      final kb = (fileSizeBytes / 1024).toStringAsFixed(1);
      return '$kb KB';
    } else if (fileSizeBytes < 1024 * 1024 * 1024) {
      final mb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
      return '$mb MB';
    } else {
      final gb = (fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2);
      return '$gb GB';
    }
  }

  /// Formatted date string (e.g. "18 Sep 2026")
  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[downloadedAt.month - 1];
    return '${downloadedAt.day} $month ${downloadedAt.year}';
  }

  /// File extension in lowercase (e.g. ".pdf")
  String get extension {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex != -1) {
      return fileName.substring(dotIndex).toLowerCase();
    }
    return '';
  }

  bool get isPdf => extension == '.pdf';
  bool get isText => extension == '.txt' || extension == '.md';
  bool get isDoc => extension == '.doc' || extension == '.docx';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'fileName': fileName,
      'filePath': filePath,
      'fileSizeBytes': fileSizeBytes,
      'downloadedAt': downloadedAt.toIso8601String(),
      'subject': subject,
      'unit': unit,
      'category': category.name,
      'downloadUrl': downloadUrl,
    };
  }

  factory DownloadItem.fromJson(Map<String, dynamic> map) {
    return DownloadItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      filePath: map['filePath'] as String? ?? '',
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt() ?? 0,
      downloadedAt: map['downloadedAt'] != null
          ? DateTime.tryParse(map['downloadedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      subject: map['subject'] as String? ?? '',
      unit: (map['unit'] as num?)?.toInt(),
      category: DownloadCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => DownloadCategory.notes,
      ),
      downloadUrl: map['downloadUrl'] as String?,
    );
  }

  DownloadItem copyWith({
    String? id,
    String? title,
    String? fileName,
    String? filePath,
    int? fileSizeBytes,
    DateTime? downloadedAt,
    String? subject,
    int? unit,
    DownloadCategory? category,
    String? downloadUrl,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      subject: subject ?? this.subject,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      downloadUrl: downloadUrl ?? this.downloadUrl,
    );
  }
}
