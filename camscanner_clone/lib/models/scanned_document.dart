class ScannedDocument {
  ScannedDocument({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.pagePaths,
  });

  factory ScannedDocument.fromJson(Map<String, dynamic> json) {
    return ScannedDocument(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      pagePaths: List<String>.from(json['pagePaths'] as List),
    );
  }

  final String id;
  final String title;
  final DateTime createdAt;
  final List<String> pagePaths;

  String? get thumbnailPath => pagePaths.isEmpty ? null : pagePaths.first;

  ScannedDocument copyWith({String? title, List<String>? pagePaths}) {
    return ScannedDocument(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      pagePaths: pagePaths ?? this.pagePaths,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'pagePaths': pagePaths,
    };
  }
}
