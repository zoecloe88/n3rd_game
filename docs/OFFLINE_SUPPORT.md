# Offline Support Documentation

## Overview

The offline support system ensures that multiplayer operations continue to work even when the network is unavailable. Failed operations are queued and automatically retried when connectivity is restored.

## Architecture

### Core Components

1. **MultiplayerRetryQueue** (`lib/services/multiplayer/multiplayer_retry_queue.dart`)
   - Persistent queue for failed operations
   - Exponential backoff retry logic
   - Survives app restarts

2. **NetworkService** (`lib/services/network_service.dart`)
   - Monitors network connectivity
   - Detects actual internet reachability
   - Notifies services of connectivity changes

3. **MultiplayerService Integration**
   - Automatic queue processing on network restoration
   - Seamless operation queuing on network errors

## Features

### Operation Queuing

The following operations are automatically queued on network failure:

- `submitRoundAnswer`: Answer submissions
- `setPlayerReady`: Ready status updates
- `sendPing`: Ping operations
- `nextRound`: Round advancement
- `leaveRoom`: Room leaving

### Retry Logic

- **Exponential Backoff**: Retry delays increase with each attempt (5s, 10s, 20s)
- **Max Retries**: 3 attempts per operation
- **Max Age**: Operations older than 7 days are dropped
- **Automatic Processing**: Queue is processed when network is restored

### Persistence

- **SharedPreferences**: Queue is stored locally
- **Survives Restarts**: Queue persists across app restarts
- **Automatic Loading**: Queue is loaded on service initialization

## Usage

### Automatic Operation

The retry queue works automatically. When an operation fails due to network error:

1. Operation is automatically queued
2. Network restoration triggers queue processing
3. Operations are retried with exponential backoff
4. Successful operations are removed from queue

### Manual Queue Management

```dart
// Get queue size
final queueSize = multiplayerService.retryQueue.queueSize;

// Clear queue (if needed)
await multiplayerService.retryQueue.clear();
```

## Data Flow

1. **Operation Fails**: Network error occurs → Operation queued
2. **Network Restored**: Connectivity detected → Queue processing triggered
3. **Retry Attempt**: Operation retried → Success or increment attempts
4. **Completion**: Operation succeeds or max retries reached

## Error Handling

- **Network Errors**: Automatically queued
- **Validation Errors**: Not queued (user error)
- **Permission Errors**: Not queued (permanent failure)
- **Timeout Errors**: Queued and retried

## Performance

- **Non-Blocking**: Queue processing doesn't block UI
- **Efficient**: Only failed operations are queued
- **Limited Size**: Old operations are automatically cleaned up

## Limitations

- **Max Queue Size**: No hard limit, but old operations are cleaned up
- **Retry Delays**: Operations may take time to retry
- **Storage**: Queue uses SharedPreferences (limited by device storage)


















