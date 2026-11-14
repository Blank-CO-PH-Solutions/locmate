class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'] as String,
        senderId: map['sender_id'] as String,
        text: map['body'] as String? ?? '',
        timestamp: DateTime.parse(map['created_at'] as String).toLocal(),
      );
}
