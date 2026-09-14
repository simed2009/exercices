class ScannedDocument {
  ScannedDocument({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.pagePaths,
    Map<String, String>? pageText,
  }) : pageText = pageText ?? const {};

  factory ScannedDocument.fromJson(Map<String, dynamic> json) {
    return ScannedDocument(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      pagePaths: List<String>.from(json['pagePaths'] as List),
      pageText: Map<String, String>.from(
        json['pageText'] as Map? ?? const {},
      ),
    );
  }

  final String id;
  final String title;
  final DateTime createdAt;
  final List<String> pagePaths;

  /// نص مستخرَج بالـ OCR لكل صفحة، مفتاحه مسار ملف الصفحة الحالي.
  /// صفحة بلا مفتاح تعني أن OCR لم يُشغَّل عليها بعد (أو تغيّر مسارها بعد فلتر جديد).
  final Map<String, String> pageText;

  String? get thumbnailPath => pagePaths.isEmpty ? null : pagePaths.first;

  /// كل النصوص المستخرجة من صفحات هذا المستند، مجمّعة لأغراض البحث.
  String get searchableText => pageText.values.join('\n');

  ScannedDocument copyWith({
    String? title,
    List<String>? pagePaths,
    Map<String, String>? pageText,
  }) {
    return ScannedDocument(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      pagePaths: pagePaths ?? this.pagePaths,
      pageText: pageText ?? this.pageText,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'pagePaths': pagePaths,
      'pageText': pageText,
    };
  }
}
