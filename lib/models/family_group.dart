import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a Family & Friends group
class FamilyGroup {
  final String id;
  final String ownerId;
  final String subscriptionTier;
  final int maxMembers;
  final DateTime createdAt;
  final DateTime? subscriptionExpiresAt;
  final List<FamilyMember> members;
  final List<PendingInvite> pendingInvites;

  FamilyGroup({
    required this.id,
    required this.ownerId,
    required this.subscriptionTier,
    required this.maxMembers,
    required this.createdAt,
    this.subscriptionExpiresAt,
    required this.members,
    required this.pendingInvites,
  });

  /// Check if group has reached max members
  bool get isFull => members.length >= maxMembers;

  /// Check if subscription is active
  bool get isSubscriptionActive {
    if (subscriptionExpiresAt == null) return false;
    return subscriptionExpiresAt!.isAfter(DateTime.now());
  }

  /// Get member by user ID
  FamilyMember? getMember(String userId) {
    try {
      return members.firstWhere((m) => m.userId == userId);
    } catch (e) {
      return null;
    }
  }

  /// Check if user is a member
  bool isMember(String userId) {
    return getMember(userId) != null;
  }

  /// Check if user is the owner
  bool isOwner(String userId) {
    return ownerId == userId;
  }

  /// Get pending invite by email
  PendingInvite? getPendingInvite(String email) {
    try {
      return pendingInvites
          .firstWhere((i) => i.email.toLowerCase() == email.toLowerCase());
    } catch (e) {
      return null;
    }
  }

  /// Create from Firestore document
  factory FamilyGroup.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FamilyGroup(
      id: doc.id,
      ownerId: data['ownerId'] as String,
      subscriptionTier: data['subscriptionTier'] as String? ?? 'family_friends',
      maxMembers: data['maxMembers'] as int? ?? 4,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      subscriptionExpiresAt:
          (data['subscriptionExpiresAt'] as Timestamp?)?.toDate(),
      members: (data['members'] as List<dynamic>?)
              ?.map((m) => FamilyMember.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      pendingInvites: (data['pendingInvites'] as List<dynamic>?)
              ?.map((i) => PendingInvite.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'subscriptionTier': subscriptionTier,
      'maxMembers': maxMembers,
      'createdAt': Timestamp.fromDate(createdAt),
      'subscriptionExpiresAt': subscriptionExpiresAt != null
          ? Timestamp.fromDate(subscriptionExpiresAt!)
          : null,
      'members': members.map((m) => m.toMap()).toList(),
      'pendingInvites': pendingInvites.map((i) => i.toMap()).toList(),
    };
  }
}

/// Model representing a family group member
class FamilyMember {
  final String userId;
  final String email;
  final DateTime joinedAt;
  final String role; // 'owner' or 'member'

  FamilyMember({
    required this.userId,
    required this.email,
    required this.joinedAt,
    required this.role,
  });

  bool get isOwner => role == 'owner';

  factory FamilyMember.fromMap(Map<String, dynamic> map) {
    return FamilyMember(
      userId: map['userId'] as String,
      email: map['email'] as String,
      joinedAt: (map['joinedAt'] as Timestamp).toDate(),
      role: map['role'] as String? ?? 'member',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'role': role,
    };
  }
}

/// Model representing a pending invitation
class PendingInvite {
  final String email;
  final DateTime invitedAt;
  final String invitedBy; // userId of inviter

  PendingInvite({
    required this.email,
    required this.invitedAt,
    required this.invitedBy,
  });

  factory PendingInvite.fromMap(Map<String, dynamic> map) {
    return PendingInvite(
      email: map['email'] as String,
      invitedAt: (map['invitedAt'] as Timestamp).toDate(),
      invitedBy: map['invitedBy'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'invitedAt': Timestamp.fromDate(invitedAt),
      'invitedBy': invitedBy,
    };
  }
}
