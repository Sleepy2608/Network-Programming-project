# 🔍 User Search

## Overview
The user search feature allows finding other users by username. Results include avatar and friendship status, enabling quick actions like starting a chat or sending a friend request directly from search results.

---

## Source Files

| Layer | File | Package |
|---|---|---|
| **Server Handler** | `SearchUserHandler.java` | `com.server.handler.message` |
| **Server Repository** | `UserRepository.java` (searchUsers method) | `com.server.repository` |
| **Server Repository** | `FriendshipRepository.java` (status lookup) | `com.server.repository` |
| **Client View** | `ChatView.java` (search bar, results panel) | `com.client.view` |
| **Client Controller** | `ChatController.java` | `com.client.controller` |
| **Client Service** | `ChatService.java` | `com.client.service` |

---

## Flow

```mermaid
sequenceDiagram
    participant UI as ChatView (search bar)
    participant Ctrl as ChatController
    participant Svc as ChatService
    participant Svr as Server
    participant DB as MySQL

    UI->>UI: User types "ali" in search bar
    UI->>Ctrl: searchUsers("ali", onSuccess, onError)
    Ctrl->>Svc: searchUsers(currentUserId, "ali")
    Svc->>Svr: {"action":"SEARCH_USERS", "userId":12, "keyword":"ali"}
    
    Svr->>DB: SELECT id, username, avatar_url FROM users<br/>WHERE LOWER(username) LIKE '%ali%'<br/>AND id != 12<br/>LIMIT 15
    
    DB-->>Svr: [{id:15, username:"alice"}, {id:23, username:"ali_baba"}, ...]
    
    loop For each result
        Svr->>DB: SELECT status FROM friendships<br/>WHERE (user1=12 AND user2=result.id)<br/>OR (user1=result.id AND user2=12)
        DB-->>Svr: friendship status
    end
    
    Svr-->>Svc: {"status":"success", "users": [
        {"userId":15, "username":"alice", "avatarUrl":"db:15", "friendshipStatus":"friends"},
        {"userId":23, "username":"ali_baba", "avatarUrl":"db:23", "friendshipStatus":"none"}
    ]}
    
    Svc-->>Ctrl: JsonArray
    Ctrl-->>UI: Platform.runLater() → render results
    UI->>UI: Show results with context-sensitive action buttons
```

---

## Key Implementation Details

### Server-Side: LIKE Search
```java
// UserRepository.searchUsers()
String sql = "SELECT id, username FROM users WHERE LOWER(username) LIKE ? AND id != ? LIMIT 15";
PreparedStatement ps = conn.prepareStatement(sql);
ps.setString(1, "%" + keyword.toLowerCase() + "%");
ps.setLong(2, excludeUserId);
```

### Server-Side: Friendship Status Attachment
After fetching search results, the handler queries `FriendshipRepository.getFriendshipStatus()` for each result to attach the current relationship:
```java
for (JsonElement userElement : usersArray) {
    JsonObject user = userElement.getAsJsonObject();
    long otherId = user.get("userId").getAsLong();
    String status = friendshipRepository.getFriendshipStatus(requestUserId, otherId);
    user.addProperty("friendshipStatus", status);
}
```

### Client-Side: Context-Sensitive Buttons
Based on `friendshipStatus`, the search result shows:
- `"friends"` → "Nhắn tin" (Message) button
- `"pending_sent"` → "Đã gửi yêu cầu" (Request sent, disabled)
- `"pending_received"` → "Chấp nhận" (Accept) button
- `"blocked"` → "Đã chặn" (Blocked, disabled)
- `"none"` → "Kết bạn" (Add Friend) button

---

## Search Scope
- Searches by **username only** (not email or display name)
- **Case-insensitive** (uses `LOWER()`)
- Excludes the searching user from results (`id != ?`)
- **Limit**: 15 results maximum

---

## TCP Protocol

### Request
```json
{
  "action": "SEARCH_USERS",
  "userId": 12,
  "keyword": "ali",
  "requestId": "uuid"
}
```

### Response
```json
{
  "action": "SEARCH_USERS_RESPONSE",
  "status": "success",
  "users": [
    {
      "userId": 15,
      "username": "alice",
      "avatarUrl": "db:15",
      "friendshipStatus": "friends"
    },
    {
      "userId": 23,
      "username": "ali_baba",
      "avatarUrl": null,
      "friendshipStatus": "none"
    }
  ],
  "requestId": "uuid"
}
```

---

## Client UI

### Search Bar
- Located in left panel of `ChatView`
- Placeholder: "Tìm kiếm..."
- Triggers search on typing (with debounce)
- Results appear below the search bar

### Result Items
Each result shows:
- Circle avatar (initials fallback)
- Username
- Context-sensitive action button (varies by friendship status)

---

## Notable Design Decisions

| Decision | Rationale |
|---|---|
| LIKE with `%keyword%` (not prefix-only) | More flexible; finds partial matches anywhere in username |
| `LOWER()` for case-insensitive | Works reliably across MySQL collations |
| Friendship status in results | Single round-trip; client can show appropriate actions immediately |
| Limit 15 | Prevents overwhelming results; sufficient for most use cases |
| Exclude self from results | Prevents searching for yourself |
| No pagination | 15 results is small enough for single page |
