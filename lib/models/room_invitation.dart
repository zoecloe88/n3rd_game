import 'package:cloud_firestore/cloud_firestore.dart';

class RoomInvitation { // 'pending', 'accepted', 'cancelled', 'expired'

  RoomInvitation({
    required this.id,
    required this.roomId,
    required this.inviterUserId,
    required this.friendUserId,
    required this.roomCode,
    required this.createdAt,
    this.status = 'pending',
  });

  factory RoomInvitation.fromJson(Map<String, dynamic> json) => RoomInvitation(
        id: json['id'] as String,
        roomId: json['roomId'] as String,
        inviterUserId: json['inviterUserId'] as String,
        friendUserId: json['friendUserId'] as String,
        roomCode: json['roomCode'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        status: json['status'] as String? ?? 'pending',
      );

  factory RoomInvitation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoomInvitation.fromJson({...data, 'id': doc.id});
  }
  final String id;
  final String roomId;
  final String inviterUserId;
  final String friendUserId;
  final String roomCode;
  final DateTime createdAt;
  final String status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomId': roomId,
        'inviterUserId': inviterUserId,
        'friendUserId': friendUserId,
        'roomCode': roomCode,
        'createdAt': createdAt.toIso8601String(),
        'status': status,
      };

  RoomInvitation copyWith({
    String? id,
    String? roomId,
    String? inviterUserId,
    String? friendUserId,
    String? roomCode,
    DateTime? createdAt,
    String? status,
  }) {
    return RoomInvitation(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      inviterUserId: inviterUserId ?? this.inviterUserId,
      friendUserId: friendUserId ?? this.friendUserId,
      roomCode: roomCode ?? this.roomCode,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}













