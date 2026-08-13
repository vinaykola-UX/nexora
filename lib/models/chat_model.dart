/// Chat message model
class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final DateTime timestamp;
  final MessageType messageType;
  final bool isEdited;
  final DateTime? editedAt;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.timestamp,
    this.messageType = MessageType.text,
    this.isEdited = false,
    this.editedAt,
  });

  /// Copy with method for immutability
  ChatMessage copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? content,
    DateTime? timestamp,
    MessageType? messageType,
    bool? isEdited,
    DateTime? editedAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      messageType: messageType ?? this.messageType,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
    );
  }

  @override
  String toString() => 'ChatMessage(id: $id, senderId: $senderId, content: $content)';
}

/// Message type enumeration
enum MessageType {
  text,
  image,
  file,
  error,
  system;

  bool get isUser => this == MessageType.text || this == MessageType.image;
  bool get isAi => this == MessageType.text || this == MessageType.image;
}

/// Chat session model
class Chat {
  final String id;
  final String userId;
  final String title;
  final String? topic;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isPinned;
  final int messageCount;

  Chat({
    required this.id,
    required this.userId,
    required this.title,
    this.topic,
    required this.createdAt,
    this.updatedAt,
    this.isPinned = false,
    this.messageCount = 0,
  });

  /// Copy with method for immutability
  Chat copyWith({
    String? id,
    String? userId,
    String? title,
    String? topic,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    int? messageCount,
  }) {
    return Chat(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      topic: topic ?? this.topic,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      messageCount: messageCount ?? this.messageCount,
    );
  }

  @override
  String toString() => 'Chat(id: $id, userId: $userId, title: $title)';
}
