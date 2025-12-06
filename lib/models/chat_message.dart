import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String userId;
  final String userName;
  final String message;
  final DateTime timestamp;
  final String? roomId;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.userName,
    required this.message,
    required this.timestamp,
    this.roomId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'roomId': roomId,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    userId: json['userId'] as String,
    userName: json['userName'] as String,
    message: json['message'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    roomId: json['roomId'] as String?,
  );

  factory ChatMessage.fromFirestore(Map<String, dynamic> data, String id) {
    return ChatMessage(
      id: id,
      userId: data['userId'] as String,
      userName: data['userName'] as String,
      message: data['message'] as String,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      roomId: data['roomId'] as String?,
    );
  }
}
