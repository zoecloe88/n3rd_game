class DirectMessage {
  final String id;
  final String conversationId;
  final String fromUserId;
  final String toUserId;
  final String? fromDisplayName;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  DirectMessage({
    required this.id,
    required this.conversationId,
    required this.fromUserId,
    required this.toUserId,
    this.fromDisplayName,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'fromUserId': fromUserId,
    'toUserId': toUserId,
    'fromDisplayName': fromDisplayName,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
  };

  factory DirectMessage.fromJson(Map<String, dynamic> json) => DirectMessage(
    id: json['id'] as String,
    conversationId: json['conversationId'] as String,
    fromUserId: json['fromUserId'] as String,
    toUserId: json['toUserId'] as String,
    fromDisplayName: json['fromDisplayName'] as String?,
    message: json['message'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    isRead: json['isRead'] as bool? ?? false,
  );
}

class Conversation {
  final String id;
  final String userId1;
  final String userId2;
  final String? user1DisplayName;
  final String? user2DisplayName;
  final DirectMessage? lastMessage;
  final int unreadCount;
  final DateTime? lastActivity;

  Conversation({
    required this.id,
    required this.userId1,
    required this.userId2,
    this.user1DisplayName,
    this.user2DisplayName,
    this.lastMessage,
    this.unreadCount = 0,
    this.lastActivity,
  });

  String getOtherUserId(String currentUserId) {
    return currentUserId == userId1 ? userId2 : userId1;
  }

  String? getOtherDisplayName(String currentUserId) {
    return currentUserId == userId1 ? user2DisplayName : user1DisplayName;
  }
}
