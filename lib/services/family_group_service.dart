import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:n3rd_game/models/family_group.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/utils/input_sanitizer.dart';

/// Service to manage Family & Friends groups
/// Handles group creation, member invitations, and subscription management
class FamilyGroupService extends ChangeNotifier {
  static const int maxMembers = 4; // Maximum members per group
  static const int maxInvitesPerDay = 10; // Rate limit for invitations

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FamilyGroup? _currentGroup;
  StreamSubscription<DocumentSnapshot>? _groupSubscription;
  bool _isInitialized = false;
  final Map<String, int> _dailyInviteCounts = {}; // Track invites per day per user

  FamilyGroup? get currentGroup => _currentGroup;
  bool get isInitialized => _isInitialized;
  String? get currentUserId => _auth.currentUser?.uid;

  /// Check if user is in a family group
  bool get isInGroup => _currentGroup != null;

  /// Check if user is the owner of current group
  bool get isOwner {
    if (_currentGroup == null || currentUserId == null) return false;
    return _currentGroup!.isOwner(currentUserId!);
  }

  /// Initialize service and load user's group
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final userId = currentUserId;
      if (userId == null) {
        _isInitialized = true;
        return;
      }

      // Load user's family group
      await _loadUserGroup(userId);
      _isInitialized = true;
      notifyListeners();
      LoggerService.info('FamilyGroupService initialized');
    } catch (e) {
      LoggerService.error('Error initializing FamilyGroupService', error: e);
      _isInitialized = false;
    }
  }

  /// Load user's family group from Firestore
  /// CRITICAL: Includes comprehensive error handling for network issues
  Future<void> _loadUserGroup(String userId) async {
    try {
      // Check if user is a member of any group
      final groupsQuery = await _firestore
          .collection('family_groups')
          .where('members', arrayContains: userId)
          .limit(1)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw NetworkException(
                'Request timed out. Please check your connection.',
              );
            },
          );

      if (groupsQuery.docs.isNotEmpty) {
        final doc = groupsQuery.docs.first;
        _currentGroup = FamilyGroup.fromFirestore(doc);
        _setupGroupListener(doc.id);
        notifyListeners();
        LoggerService.debug('Loaded family group: ${doc.id}');
      } else {
        _currentGroup = null;
        notifyListeners();
      }
    } on NetworkException catch (e) {
      // Re-throw network exceptions for caller to handle
      LoggerService.error('Network error loading user group', error: e);
      _currentGroup = null;
      notifyListeners();
      rethrow;
    } catch (e) {
      // Handle other errors gracefully
      LoggerService.error('Error loading user group', error: e);
      _currentGroup = null;
      notifyListeners();
      // Don't rethrow - allow service to continue with null group
    }
  }

  /// Setup real-time listener for group changes
  void _setupGroupListener(String groupId) {
    _groupSubscription?.cancel();
    _groupSubscription = _firestore
        .collection('family_groups')
        .doc(groupId)
        .snapshots()
        .listen(
      (doc) {
        if (doc.exists) {
          _currentGroup = FamilyGroup.fromFirestore(doc);
          notifyListeners();
        } else {
          _currentGroup = null;
          _groupSubscription?.cancel();
          notifyListeners();
        }
      },
      onError: (e) {
        LoggerService.error('Error in group listener', error: e);
      },
    );
  }

  /// Create a new family group (owner only)
  /// Returns the group ID
  Future<String> createFamilyGroup() async {
    final userId = currentUserId;
    if (userId == null) {
      throw AuthenticationException('User must be authenticated to create a group');
    }

    // Check if user is already in a group
    if (_currentGroup != null) {
      throw ValidationException('User is already in a family group');
    }

    try {
      final user = _auth.currentUser;
      if (user?.email == null) {
        throw ValidationException('User email is required');
      }

      // Create group with owner as first member
      final groupData = {
        'ownerId': userId,
        'subscriptionTier': 'family_friends',
        'maxMembers': maxMembers,
        'createdAt': FieldValue.serverTimestamp(),
        'subscriptionExpiresAt': null, // Will be set when subscription is purchased
        'members': [
          {
            'userId': userId,
            'email': user!.email!,
            'joinedAt': FieldValue.serverTimestamp(),
            'role': 'owner',
          }
        ],
        'pendingInvites': [],
      };

      final docRef = await _firestore
          .collection('family_groups')
          .add(groupData)
          .timeout(const Duration(seconds: 10));

      // Also create membership record for user
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('family_memberships')
          .doc(docRef.id)
          .set({
        'groupId': docRef.id,
        'role': 'owner',
        'joinedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // Reload group
      await _loadUserGroup(userId);

      LoggerService.info('Created family group: ${docRef.id}');
      
      return docRef.id;
    } catch (e) {
      LoggerService.error('Error creating family group', error: e);
      if (e is TimeoutException) {
        throw NetworkException('Request timed out. Please check your connection.');
      }
      rethrow;
    }
  }

  /// Invite a member by email
  Future<void> inviteMember(String email) async {
    final userId = currentUserId;
    if (userId == null) {
      throw AuthenticationException('User must be authenticated');
    }

    if (_currentGroup == null) {
      throw ValidationException('User is not in a family group');
    }

    if (!isOwner) {
      throw ValidationException('Only the group owner can invite members');
    }

    // Validate email format
    final sanitizedEmail = InputSanitizer.sanitizeEmail(email);
    if (sanitizedEmail == null) {
      throw ValidationException('Invalid email format');
    }

    // Check if group is full
    if (_currentGroup!.isFull) {
      throw ValidationException(
        'Family & Friends group is full ($maxMembers members)',
      );
    }

    // Check if email is already a member
    if (_currentGroup!.members.any((m) => m.email.toLowerCase() == sanitizedEmail.toLowerCase())) {
      throw ValidationException('User is already a member of this group');
    }

    // Check if email is already invited
    if (_currentGroup!.getPendingInvite(sanitizedEmail) != null) {
      throw ValidationException('Invitation already sent to this email');
    }

    // Rate limiting: Check daily invite count
    final today = DateTime.now().toIso8601String().split('T')[0];
    final inviteCount = _dailyInviteCounts[today] ?? 0;
    if (inviteCount >= maxInvitesPerDay) {
      throw ValidationException(
        'Daily invitation limit reached ($maxInvitesPerDay invites per day)',
      );
    }

    try {
      final groupRef = _firestore.collection('family_groups').doc(_currentGroup!.id);
      
      // Add pending invite
      await groupRef.update({
        'pendingInvites': FieldValue.arrayUnion([
          {
            'email': sanitizedEmail,
            'invitedAt': FieldValue.serverTimestamp(),
            'invitedBy': userId,
          }
        ]),
      }).timeout(const Duration(seconds: 10));

      // Update daily invite count
      _dailyInviteCounts[today] = inviteCount + 1;

      // Reload group
      await _loadUserGroup(userId);

      LoggerService.info('Invited member: $sanitizedEmail');
    } catch (e) {
      LoggerService.error('Error inviting member', error: e);
      if (e is TimeoutException) {
        throw NetworkException('Request timed out. Please check your connection.');
      }
      rethrow;
    }
  }

  /// Accept an invitation (called when user clicks invitation link)
  Future<void> acceptInvitation(String groupId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw AuthenticationException('User must be authenticated to accept invitation');
    }

    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw ValidationException('User email is required');
    }

    final userEmail = user.email!; // Safe to use ! after null check

    try {
      final groupRef = _firestore.collection('family_groups').doc(groupId);
      final groupDoc = await groupRef.get().timeout(const Duration(seconds: 10));

      if (!groupDoc.exists) {
        throw ValidationException('Family group not found');
      }

      final group = FamilyGroup.fromFirestore(groupDoc);

      // Check if group is full
      if (group.isFull) {
        throw ValidationException('Family group is full');
      }

      // Check if user is already a member
      if (group.isMember(userId)) {
        throw ValidationException('User is already a member of this group');
      }

      // Find and remove pending invite
      final invite = group.getPendingInvite(userEmail);
      if (invite == null) {
        throw ValidationException('No pending invitation found for this email');
      }

      // Use transaction to ensure atomicity
      await _firestore.runTransaction((transaction) async {
        final freshDoc = await transaction.get(groupRef);
        if (!freshDoc.exists) {
          throw ValidationException('Family group no longer exists');
        }

        final freshGroup = FamilyGroup.fromFirestore(freshDoc);
        if (freshGroup.isFull) {
          throw ValidationException('Family group is full');
        }

        // Remove invite and add member atomically
        transaction.update(groupRef, {
          'pendingInvites': FieldValue.arrayRemove([
            {
              'email': invite.email,
              'invitedAt': Timestamp.fromDate(invite.invitedAt),
              'invitedBy': invite.invitedBy,
            }
          ]),
          'members': FieldValue.arrayUnion([
            {
              'userId': userId,
              'email': userEmail,
              'joinedAt': FieldValue.serverTimestamp(),
              'role': 'member',
            }
          ]),
        });
      }).timeout(const Duration(seconds: 15));

      // Create membership record
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('family_memberships')
          .doc(groupId)
          .set({
        'groupId': groupId,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // Reload group
      await _loadUserGroup(userId);

      LoggerService.info('Accepted invitation to group: $groupId');
    } catch (e) {
      LoggerService.error('Error accepting invitation', error: e);
      if (e is TimeoutException) {
        throw NetworkException('Request timed out. Please check your connection.');
      }
      rethrow;
    }
  }

  /// Remove a member from the group (owner only)
  Future<void> removeMember(String memberUserId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw AuthenticationException('User must be authenticated');
    }

    if (_currentGroup == null) {
      throw ValidationException('User is not in a family group');
    }

    if (!isOwner) {
      throw ValidationException('Only the group owner can remove members');
    }

    if (memberUserId == userId) {
      throw ValidationException('Owner cannot remove themselves. Cancel subscription instead.');
    }

    final member = _currentGroup!.getMember(memberUserId);
    if (member == null) {
      throw ValidationException('Member not found in group');
    }

    try {
      final groupRef = _firestore.collection('family_groups').doc(_currentGroup!.id);

      // Remove member from group
      await groupRef.update({
        'members': FieldValue.arrayRemove([
          {
            'userId': member.userId,
            'email': member.email,
            'joinedAt': Timestamp.fromDate(member.joinedAt),
            'role': member.role,
          }
        ]),
      }).timeout(const Duration(seconds: 10));

      // Update membership record
      await _firestore
          .collection('users')
          .doc(memberUserId)
          .collection('family_memberships')
          .doc(_currentGroup!.id)
          .update({
        'status': 'removed',
        'removedAt': FieldValue.serverTimestamp(),
      });

      // Reload group
      await _loadUserGroup(userId);

      LoggerService.info('Removed member: $memberUserId');
    } catch (e) {
      LoggerService.error('Error removing member', error: e);
      if (e is TimeoutException) {
        throw NetworkException('Request timed out. Please check your connection.');
      }
      rethrow;
    }
  }

  /// Leave the group (member only, owner must cancel subscription)
  Future<void> leaveGroup() async {
    final userId = currentUserId;
    if (userId == null) {
      throw AuthenticationException('User must be authenticated');
    }

    if (_currentGroup == null) {
      throw ValidationException('User is not in a family group');
    }

    if (isOwner) {
      throw ValidationException(
        'Owner cannot leave group. Cancel subscription to disband the group.',
      );
    }

    final member = _currentGroup!.getMember(userId);
    if (member == null) {
      throw ValidationException('User is not a member of this group');
    }

    try {
      final groupRef = _firestore.collection('family_groups').doc(_currentGroup!.id);

      // Remove member from group
      await groupRef.update({
        'members': FieldValue.arrayRemove([
          {
            'userId': member.userId,
            'email': member.email,
            'joinedAt': Timestamp.fromDate(member.joinedAt),
            'role': member.role,
          }
        ]),
      }).timeout(const Duration(seconds: 10));

      // Update membership record
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('family_memberships')
          .doc(_currentGroup!.id)
          .update({
        'status': 'left',
        'leftAt': FieldValue.serverTimestamp(),
      });

      // Clear current group
      _currentGroup = null;
      _groupSubscription?.cancel();
      notifyListeners();

      LoggerService.info('Left family group');
    } catch (e) {
      LoggerService.error('Error leaving group', error: e);
      if (e is TimeoutException) {
        throw NetworkException('Request timed out. Please check your connection.');
      }
      rethrow;
    }
  }

  /// Check if user has family premium access
  /// This checks both direct membership and subscription status
  Future<bool> hasFamilyPremiumAccess(String userId) async {
    if (_currentGroup == null) {
      return false;
    }

    // Check if user is a member
    if (!_currentGroup!.isMember(userId)) {
      return false;
    }

    // Check if subscription is active
    return _currentGroup!.isSubscriptionActive;
  }

  /// Update subscription expiration date (called by RevenueCat webhook)
  Future<void> updateSubscriptionExpiration(
    String groupId,
    DateTime? expirationDate,
  ) async {
    try {
      await _firestore
          .collection('family_groups')
          .doc(groupId)
          .update({
        'subscriptionExpiresAt': expirationDate != null
            ? Timestamp.fromDate(expirationDate)
            : null,
      }).timeout(const Duration(seconds: 10));

      // Reload group if it's the current group
      if (_currentGroup?.id == groupId) {
        await _loadUserGroup(currentUserId!);
      }

      LoggerService.info('Updated subscription expiration for group: $groupId');
    } catch (e) {
      LoggerService.error('Error updating subscription expiration', error: e);
      rethrow;
    }
  }

  @override
  void dispose() {
    _groupSubscription?.cancel();
    super.dispose();
  }
}

