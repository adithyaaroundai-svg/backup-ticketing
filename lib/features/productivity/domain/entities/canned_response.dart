class CannedResponse {
  final String id;
  final String title;
  final String content;
  final String? category;

  CannedResponse({
    required this.id,
    required this.title,
    required this.content,
    this.category,
  });

  factory CannedResponse.fromJson(Map<String, dynamic> json) {
    return CannedResponse(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      category: json['category'] as String?,
    );
  }
}
