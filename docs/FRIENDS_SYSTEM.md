# Friends System Architecture

## Overview

The Friends System provides comprehensive friend management functionality including friend requests, friend suggestions, invitations, blocking, reporting, and friend score comparisons. The system follows a clean architecture pattern with separation of concerns, repository pattern for data access, and comprehensive error handling.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    UI Layer                                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         FriendsMoreScreen                            │  │
│  │  - Renders UI components                              │  │
│  │  - Handles user interactions                          │  │
│  │  - Displays friend scores                             │  │
│  └──────────────────┬───────────────────────────────────┘  │
│                     │                                        │
│  ┌──────────────────▼───────────────────────────────────┐  │
│  │      FriendsMoreViewModel                             │  │
│  │  - Manages UI state                                   │  │
│  │  - Debounces operations                               │  │
│  │  - Handles error states                              │  │
│  └──────────┬──────────────────────┬─────────────────────┘  │
└────────────┼──────────────────────┼─────────────────────────┘
             │                      │
┌────────────▼──────────────────────▼─────────────────────────┐
│              Business Logic Layer                           │
│  ┌──────────────────────┐  ┌────────────────────────────┐  │
│  │   FriendsService    │  │   FriendScoreService       │  │
│  │  - Friend operations │  │  - Score fetching          │  │
│  │  - Rate limiting    │  │  - Score comparison        │  │
│  │  - Caching          │  │  - Caching                 │  │
│  └──────────┬──────────┘  └──────────┬─────────────────┘  │
│             │                        │                       │
│  ┌──────────▼──────────┐  ┌──────────▼─────────────────┐   │
│  │ FriendsRetryQueue  │  │  StatsRepository            │   │
│  │  - Failed ops      │  │  - Score data access        │   │
│  │  - Exponential     │  └──────────┬─────────────────┘   │
│  │    backoff         │             │                      │
│  └───────────────────┘  ┌──────────▼─────────────────┐   │
│                          │ FirestoreStatsRepository   │   │
│  ┌──────────────────────┐└────────────────────────────┘   │
│  │ FriendsValidator     │                                 │
│  │  - Input validation  │                                 │
│  │  - Sanitization      │                                 │
│  └──────────────────────┘                                 │
└────────────┬──────────────────────────────────────────────┘
             │
┌────────────▼───────────────────────────────────────────────┐
│              Data Access Layer                              │
│  ┌──────────────────────┐  ┌────────────────────────────┐ │
│  │ FriendsRepository    │  │  StatsRepository            │ │
│  │  (Interface)         │  │  (Interface)                │ │
│  └──────────┬───────────┘  └──────────┬─────────────────┘ │
│             │                         │                      │
│  ┌──────────▼──────────┐  ┌──────────▼─────────────────┐  │
│  │FirestoreFriendsRepo │  │FirestoreStatsRepository    │  │
│  │  - Cloud storage    │  │  - Cloud score queries      │  │
│  │  - Timeout handling│  │  - Batch operations           │  │
│  └─────────────────────┘  └────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────┐                                   │
│  │LocalFriendsRepository│                                   │
│  │  - Offline caching   │                                   │
│  │  - SharedPreferences │                                   │
│  └──────────────────────┘                                   │
└─────────────────────────────────────────────────────────────┘
```

## Components

### UI Layer

#### FriendsMoreScreen
The main UI component for the Friends "More" section.

**Responsibilities:**
- Render friend management UI (add friend, suggestions, invite, block, report)
- Display friend scores with rankings
- Show loading states and error messages
- Handle user interactions and delegate to ViewModel

**Key Features:**
- Friend score display section with rankings
- Action buttons for friend management
- QR code sharing for friend invitations
- Loading indicators for all operations
- Error boundaries with user-friendly messages

#### FriendsMoreViewModel
Manages UI-specific state and business logic coordination.

**Responsibilities:**
- Manage loading and error states
- Coordinate between FriendsService and FriendScoreService
- Debounce search operations
- Cache friend scores
- Provide reactive state updates

**Key Features:**
- Debounced search (500ms delay)
- Friend score caching (5 minutes expiry)
- Centralized error handling
- Loading state management

### Business Logic Layer

#### FriendsService
Core service for friend management operations.

**Responsibilities:**
- Send, accept, reject, and cancel friend requests
- Add and remove friends
- Search for users
- Get friend suggestions
- Block/unblock users
- Report users
- Send invitations

**Key Features:**
- Real-time friend list updates via Firestore streams
- Pagination support for large friend lists
- Comprehensive error handling
- Stream subscriptions for live updates

**Note:** The service currently uses direct Firestore access. The repository pattern infrastructure has been created and is ready for integration when the service is refactored.

#### FriendScoreService
Service for fetching and comparing friend scores.

**Responsibilities:**
- Fetch friend scores from user_stats collection
- Compare user scores with friends
- Display top friends by score
- Cache friend scores with expiry

**Key Features:**
- Score caching (5 minutes expiry)
- Rank calculation with tie handling
- Current user score comparison
- Top N friends retrieval

#### FriendsValidator
Utility service for validating friend-related data.

**Responsibilities:**
- Validate email addresses
- Validate phone numbers
- Validate user IDs
- Validate report reasons
- Validate display names
- Validate search queries

**Key Features:**
- Uses InputSanitizer for sanitization
- Comprehensive validation rules
- Clear error messages
- Different user validation

#### FriendsRetryQueue
Persistent queue for failed friend operations.

**Responsibilities:**
- Queue failed friend requests
- Queue failed invitations
- Queue failed reports
- Retry with exponential backoff

**Key Features:**
- Persists to SharedPreferences
- Exponential backoff (max 5 minutes)
- Max 3 retries per operation
- Max 7 days retention

### Data Access Layer

#### FriendsRepository (Interface)
Abstract interface for friend data operations.

**Methods:**
- `searchUsers(String query)`
- `sendFriendRequest(...)`
- `acceptFriendRequest(...)`
- `rejectFriendRequest(String requestId)`
- `removeFriend(...)`
- `blockUser(...)`
- `unblockUser(...)`
- `isUserBlocked(...)`
- `getFriendSuggestions(...)`
- `sendInvitation(...)`
- `reportUser(...)`

#### FirestoreFriendsRepository
Firestore implementation of FriendsRepository.

**Features:**
- 10-second timeout for all operations
- Comprehensive error handling with ErrorCode enum
- Permission error handling
- Network error handling
- Validation error handling

#### LocalFriendsRepository
Local storage implementation using SharedPreferences.

**Features:**
- Offline caching of search results
- Offline caching of friend suggestions
- Local block list storage
- Read-only operations for offline support

#### StatsRepository (Interface)
Abstract interface for user statistics/score data access.

**Methods:**
- `getHighestScore(String userId)`
- `getFriendScores(List<String> userIds)`

#### FirestoreStatsRepository
Firestore implementation of StatsRepository.

**Features:**
- Batch fetching for multiple users (batches of 10)
- Timeout handling (10 seconds)
- Error handling with fallback to empty results

## Data Models

### Friend
Represents a friend relationship.

**Properties:**
- `userId`: String (required)
- `displayName`: String?
- `email`: String?
- `addedAt`: DateTime?
- `isOnline`: bool

### FriendRequest
Represents a friend request.

**Properties:**
- `id`: String (required)
- `fromUserId`: String (required)
- `toUserId`: String (required)
- `fromDisplayName`: String?
- `fromEmail`: String?
- `createdAt`: DateTime (required)
- `status`: FriendRequestStatus (pending, accepted, rejected)

### FriendScore
Represents a friend's score for comparison.

**Properties:**
- `userId`: String (required)
- `displayName`: String?
- `email`: String?
- `score`: int (required)
- `rank`: int (required)

## Error Handling

### Error Codes
Friend-specific error codes have been added to the `ErrorCode` enum:

- `FRIEND_001`: Friend not found
- `FRIEND_002`: Friend request already sent
- `FRIEND_003`: Friend request not found
- `FRIEND_004`: Maximum friend requests reached
- `FRIEND_005`: Rate limit exceeded
- `FRIEND_006`: Search failed
- `FRIEND_007`: Invite failed
- `FRIEND_008`: Report failed
- `FRIEND_009`: Block failed
- `FRIEND_010`: Unblock failed

### Exception Types
- `AuthenticationException`: User not authenticated
- `ValidationException`: Invalid input data
- `NetworkException`: Network/connection errors
- `StorageException`: Firestore/storage errors
- `PermissionException`: Permission denied errors

### Error Recovery
All errors include recovery suggestions to guide users:
- Network errors suggest checking connection
- Rate limit errors suggest waiting before retrying
- Validation errors provide specific guidance

## Performance Optimizations

### Caching
- **Search Results**: 5-minute cache expiry
- **Friend Suggestions**: 10-minute cache expiry
- **Friend Scores**: 5-minute cache expiry

### Debouncing
- Search operations debounced by 500ms to prevent excessive API calls

### Pagination
- Friend list pagination (20 items per page)
- Load more functionality for large friend lists

### Rate Limiting
Rate limiting infrastructure is in place (to be integrated):
- Search: 20 per minute
- Friend requests: 10 per hour
- Invitations: 5 per hour
- Reports: 3 per day
- Block operations: 10 per hour

## Security

### Input Validation
- All user inputs validated using `FriendsValidator`
- Email format validation
- Phone number normalization
- User ID validation
- Report reason length validation

### Input Sanitization
- All text inputs sanitized using `InputSanitizer`
- HTML/script tag removal
- Control character removal
- Display name sanitization

### Permission Checks
- Contacts permission required for contact search
- Firestore security rules enforce data access
- User can only access/modify their own data or friend-related data

## Testing Strategy

### Unit Tests
- **FriendsService**: Test all friend operations
- **FriendScoreService**: Test score fetching and comparison
- **FriendsValidator**: Test all validation methods
- **FriendsRetryQueue**: Test retry logic and persistence
- **Repository Implementations**: Test data access operations

### Widget Tests
- **FriendsMoreScreen**: Test UI rendering, interactions, error states
- **FriendsMoreViewModel**: Test state management and debouncing

### Integration Tests
- Full friend management flow (send request, accept, remove)
- Friend score display flow
- Error handling scenarios
- Offline/online transitions

## Integration Points

1. **FriendsMoreScreen ↔ FriendsMoreViewModel**: Screen observes ViewModel for all state
2. **FriendsMoreViewModel ↔ FriendsService**: ViewModel calls service for friend operations
3. **FriendsMoreViewModel ↔ FriendScoreService**: ViewModel calls service for score data
4. **FriendsService ↔ Firestore**: Direct Firestore access (repository pattern ready for integration)
5. **FriendScoreService ↔ StatsRepository**: Service uses repository for score queries
6. **ServiceRegistry**: Registers FriendsService and FriendScoreService

## Future Improvements

1. **Complete FriendsService Refactoring**: Integrate repository pattern, rate limiting, and retry queue
2. **Enhanced Caching**: Implement more sophisticated cache invalidation strategies
3. **Offline Support**: Enhance local repository for full offline functionality
4. **Real-time Score Updates**: Add Firestore listeners for live score updates
5. **Advanced Friend Suggestions**: Implement ML-based friend suggestions
6. **Friend Activity Feed**: Show friend activity and achievements
7. **Group Friends**: Allow grouping friends into categories

## Files Created

### Services
- `lib/services/friends/friends_repository.dart`
- `lib/services/friends/firestore_friends_repository.dart`
- `lib/services/friends/local_friends_repository.dart`
- `lib/services/friends/friends_validator.dart`
- `lib/services/friends/friends_retry_queue.dart`
- `lib/services/friend_score_service.dart`
- `lib/services/stats/stats_repository.dart`
- `lib/services/stats/firestore_stats_repository.dart`

### UI
- `lib/screens/friends_more_view_model.dart`
- `lib/screens/friends_more_screen.dart` (refactored)

### Models
- `FriendScore` (in FriendScoreService)

### Documentation
- `docs/FRIENDS_SYSTEM.md`

## Files Modified

- `lib/exceptions/error_codes.dart`: Added friend-specific error codes
- `lib/core/service_registry.dart`: Registered FriendScoreService
- `lib/services/friends_service.dart`: Ready for repository pattern integration

## Notes

- The repository pattern infrastructure is complete and ready for integration
- FriendsService currently uses direct Firestore access but can be refactored to use repositories
- All new components follow the same architectural patterns as Daily Challenge and Trivia Creator systems
- Friend score display is fully functional and integrated
- Comprehensive error handling is in place throughout the system
















