class Friend {
  final String userId;
  final String? displayName;
  final String? email;
  final DateTime? addedAt;
  final bool isOnline;

  Friend({
    required this.userId,
    this.displayName,
    this.email,
    this.addedAt,
    this.isOnline = false,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'displayName': displayName,
    'email': email,
    'addedAt': addedAt?.toIso8601String(),
    'isOnline': isOnline,
  };

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
    userId: json['userId'] as String,
    displayName: json['displayName'] as String?,
    email: json['email'] as String?,
    addedAt: json['addedAt'] != null
        ? DateTime.parse(json['addedAt'] as String)
        : null,
    isOnline: json['isOnline'] as bool? ?? false,
  );
}

class FriendRequest {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String? fromDisplayName;
  final String? fromEmail;
  final DateTime createdAt;
  final FriendRequestStatus status;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    this.fromDisplayName,
    this.fromEmail,
    required this.createdAt,
    this.status = FriendRequestStatus.pending,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromUserId': fromUserId,
    'toUserId': toUserId,
    'fromDisplayName': fromDisplayName,
    'fromEmail': fromEmail,
    'createdAt': createdAt.toIso8601String(),
    'status': status.toString().split('.').last,
  };

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
    id: json['id'] as String,
    fromUserId: json['fromUserId'] as String,
    toUserId: json['toUserId'] as String,
    fromDisplayName: json['fromDisplayName'] as String?,
    fromEmail: json['fromEmail'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    status: FriendRequestStatus.values.firstWhere(
      (e) => e.toString().split('.').last == json['status'],
      orElse: () => FriendRequestStatus.pending,
    ),
  );
}

enum FriendRequestStatus { pending, accepted, rejected }
