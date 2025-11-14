/// Represents a conversation/chat thread
class Conversation {
  final int? id;
  final String title;
  final DateTime createdAt;
  final DateTime lastModified;

  Conversation({
    this.id,
    required this.title,
    required this.createdAt,
    required this.lastModified,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.millisecondsSinceEpoch,
      'last_modified': lastModified.millisecondsSinceEpoch,
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as int?,
      title: map['title'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      lastModified: DateTime.fromMillisecondsSinceEpoch(map['last_modified'] as int),
    );
  }

  Conversation copyWith({
    int? id,
    String? title,
    DateTime? createdAt,
    DateTime? lastModified,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}
