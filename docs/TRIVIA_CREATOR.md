# Trivia Creator Architecture

## Overview

The Trivia Creator feature allows users to create custom trivia questions with validation, moderation, and sharing capabilities. The architecture follows a service-oriented pattern with clear separation of concerns.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    TriviaCreatorScreen                        │
│                      (UI Layer)                              │
│  - Form rendering                                            │
│  - User interactions                                         │
│  - Error display                                             │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       │ Uses
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                 TriviaCreatorViewModel                       │
│                  (State Management)                          │
│  - Form state                                                │
│  - Validation state                                          │
│  - Debouncing for AI suggestions                            │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       │ Uses
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                 TriviaCreatorService                         │
│                  (Business Logic)                            │
│  - Validation                                                │
│  - Rate limiting                                             │
│  - Content moderation                                        │
│  - Input sanitization                                        │
└──────┬───────────────────────────────┬───────────────────────┘
       │                               │
       │ Uses                           │ Uses
       ▼                               ▼
┌──────────────────────┐    ┌──────────────────────────────┐
│  TriviaRepository    │    │  ContentModerationService     │
│     (Interface)      │    │  - Profanity filtering        │
└──────┬───────────────┘    │  - Content validation         │
       │                    └──────────────────────────────┘
       │
       │ Implemented by
       │
       ├──────────────────────┬──────────────────────┐
       ▼                      ▼                      ▼
┌──────────────┐    ┌──────────────────┐    ┌──────────────┐
│ Firestore   │    │ LocalTrivia      │    │ RetryQueue   │
│ Repository  │    │ Repository       │    │ - Persistent │
│ - Cloud     │    │ - Offline        │    │ - Auto-retry  │
│ - Real-time │    │ - SharedPrefs    │    │ - Exp backoff │
└─────────────┘    └──────────────────┘    └──────────────┘
```

## Components

### TriviaCreatorScreen

The UI layer that renders the form and handles user interactions.

**Responsibilities:**
- Render form fields (category, question, words, answers)
- Display loading states
- Show error messages with recovery suggestions
- Handle button interactions

**Key Features:**
- Loading indicators during operations
- Disabled buttons during operations
- Error display with recovery suggestions
- Form validation feedback

### TriviaCreatorViewModel

Manages form state and provides debouncing for AI suggestions.

**Responsibilities:**
- Track form field values
- Manage validation errors
- Debounce AI suggestion requests (500ms)
- Provide form data to service

**Key Features:**
- Reactive state management
- Debouncing to prevent excessive API calls
- Error state management

### TriviaCreatorService

Core business logic layer that handles all trivia creation operations.

**Responsibilities:**
- Input validation
- Rate limiting
- Content moderation
- Input sanitization
- Save operations (local and cloud)
- Friend sharing
- Retry queue management

**Key Features:**
- Comprehensive validation (length, format, duplicates)
- Rate limiting (10 saves/min, 5 AI/min, 5 shares/min)
- Content moderation integration
- Automatic retry queue for failed saves
- Error handling with ErrorCode enum

### TriviaRepository Interface

Abstract interface for storage operations.

**Methods:**
- `saveCustomTrivia()` - Save to cloud
- `saveLocalTrivia()` - Save locally
- `shareTrivia()` - Share with friend
- `getCustomTrivia()` - Get user's trivia
- `getLocalTrivia()` - Get local trivia
- `getSharedTrivia()` - Get shared trivia
- `deleteCustomTrivia()` - Delete trivia

### FirestoreTriviaRepository

Cloud storage implementation using Firestore.

**Collections:**
- `custom_trivia` - User-created trivia
- `shared_trivia` - Trivia shared between users

**Features:**
- Timeout handling (10 seconds)
- Error recovery
- Permission checks

### LocalTriviaRepository

Local storage implementation using SharedPreferences.

**Features:**
- Offline support
- Storage size limits (100 items max)
- Automatic cleanup of old items

### TriviaRetryQueue

Persistent queue for failed saves.

**Features:**
- Persists to SharedPreferences
- Exponential backoff
- Maximum retry attempts (3)
- Maximum age (7 days)
- Automatic processing on init

## Data Flow

### Save to Cloud Flow

1. User fills form and clicks "Save to Cloud"
2. Screen calls `service.saveTriviaToCloud()`
3. Service validates input (length, format, duplicates)
4. Service checks rate limit
5. Service checks authentication
6. Service validates content moderation
7. Service sanitizes inputs
8. Service saves to Firestore via repository
9. On failure, service queues for retry
10. Service notifies listeners
11. Screen displays success/error message

### AI Suggestion Flow

1. User clicks "AI Assist" and selects type
2. ViewModel debounces request (500ms)
3. ViewModel calls AIEditionService
4. ViewModel applies suggestions to form
5. ViewModel notifies listeners
6. Screen updates form fields

### Retry Queue Flow

1. Failed save is queued
2. Queue persists to SharedPreferences
3. On service init, queue is loaded
4. Queue processes in background
5. Successful saves are removed
6. Failed saves increment attempt count
7. Max attempts or age reached items are removed

## Validation Rules

### Category
- Required
- Max length: 100 characters
- Min length: 2 characters (via content moderation)

### Question
- Required
- Max length: 500 characters
- Min length: 10 characters (via content moderation)

### Words
- Required: Exactly 6 words
- Max length per word: 50 characters
- Must be unique (no duplicates)
- Case-insensitive duplicate check

### Correct Answers
- Required: 1-3 answers
- Max length per answer: 50 characters
- Must be in words list
- Case-insensitive matching

## Error Handling

All errors use the ErrorCode enum with recovery suggestions:

- **ValidationException**: Input validation failures
- **AuthenticationException**: User not authenticated
- **NetworkException**: Network connectivity issues
- **StorageException**: Storage operation failures
- **PermissionException**: Permission denied

Each exception includes:
- Error message
- ErrorCode
- Recovery suggestion

## Rate Limiting

- **Saves**: 10 per minute
- **AI Suggestions**: 5 per minute
- **Shares**: 5 per minute

Rate limit violations throw `ValidationException` with `ErrorCode.authTooManyRequests`.

## Security

### Input Sanitization
All inputs are sanitized using `InputSanitizer.sanitizeText()` before saving.

### Content Moderation
All content is validated using `ContentModerationService.validateTriviaContent()`.

### Permission Checks
- User authentication required for cloud saves
- User authentication required for sharing
- Firestore security rules enforce permissions

## Testing

### Unit Tests
- Service validation logic
- Repository operations
- ViewModel state management

### Widget Tests
- Screen rendering
- Form interactions
- Error display

### Integration Tests
- Full save flow
- Error recovery
- Retry queue processing

## Future Enhancements

1. **Caching**: Cache saved trivia for faster access
2. **Sync**: Automatic sync between local and cloud
3. **Batch Operations**: Save multiple trivia at once
4. **Templates**: Pre-filled trivia templates
5. **Analytics**: Track trivia creation metrics



















