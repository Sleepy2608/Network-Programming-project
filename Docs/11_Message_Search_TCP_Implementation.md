# Message Search TCP Implementation Notes

This document records the implementation details for the **Message Search** feature (SCRUM-24).

The feature allows users to search messages within the currently open conversation, using the project's TCP socket architecture.

## 1. Feature Purpose

Message search operates within a specific conversation.

User flow:

```text
User opens a conversation
 → types keyword into "Search messages..." field
 → clicks "Search" or presses Enter
 → client sends SEARCH_MESSAGES action via TCP
 → server searches in messages table
 → server returns matching messages
 → UI displays results below chat header
```

## 2. Why TCP Action, Not HTTP Endpoint?

The project uses TCP sockets exclusively. Message search does NOT call an HTTP endpoint like `/api/messages/search`. Instead, the client sends a JSON action via `ChatService`.

Action: `SEARCH_MESSAGES`

## 3. Request TCP

Client sends:

```json
{
  "action": "SEARCH_MESSAGES",
  "conversationId": 1,
  "keyword": "hello",
  "limit": 20,
  "offset": 0,
  "requestId": "..."
}
```

| Field | Meaning |
|---|---|
| `action` | Action name for Router dispatch |
| `conversationId` | Search only in the currently open conversation |
| `keyword` | User-entered keyword |
| `limit` | Maximum results (server caps at 50) |
| `offset` | Pagination offset |
| `requestId` | Correlates response to request |

## 4. Response TCP

Success:

```json
{
  "action": "SEARCH_MESSAGES_RESPONSE",
  "status": "success",
  "conversationId": 1,
  "keyword": "hello",
  "count": 2,
  "messages": [
    {
      "id": 10,
      "conversationId": 1,
      "senderId": 3,
      "senderUsername": "alice",
      "type": "TEXT",
      "content": "hello",
      "createdAt": "..."
    }
  ],
  "requestId": "..."
}
```

Error:

```json
{
  "action": "SEARCH_MESSAGES_RESPONSE",
  "status": "error",
  "message": "Missing conversationId or keyword",
  "requestId": "..."
}
```

## 5. Client Files

### 5.1. `ChatService.java`

File: `Code/Client/src/main/java/com/client/service/ChatService.java`

Method:
```java
public ApiResponse searchMessages(long conversationId, String keyword, int limit, int offset)
```

Creates JSON action `SEARCH_MESSAGES` and sends via `sendRequestSync`.

### 5.2. `ChatController.java`

File: `Code/Client/src/main/java/com/client/controller/ChatController.java`

Method:
```java
public void searchMessages(long conversationId, String keyword, int limit, int offset,
                           Consumer<JsonObject> onSuccess, Consumer<String> onError)
```

Runs on background thread, dispatches results to JavaFX thread.

### 5.3. `ChatView.java`

File: `Code/Client/src/main/java/com/client/view/ChatView.java`

Added search UI in chat header:
- "Search messages..." input field
- "Search" button
- Results panel below chat header

New methods:
```java
searchMessagesInCurrentConversation()
renderMessageSearchResults(...)
createMessageSearchResultItem(...)
showMessageSearchStatus(...)
clearMessageSearchResults()
```

Client-side validation:
1. Empty keyword → hide results panel
2. Keyword < 2 chars → show error
3. No conversation selected → show error
4. Not connected via TCP → show error
5. Valid → call `chatController.searchMessages(...)`

Search results displayed as a list with:
- Sender name
- Creation time
- Message content

## 6. File Server Đã Thêm Và Sửa

### 6.1. `SearchMessagesHandler.java`

File mới:

```text
Code/Server/src/main/java/com/server/handler/message/SearchMessagesHandler.java
```

Handler này nhận action `SEARCH_MESSAGES` từ Router.

Nó kiểm tra:

1. Có `conversationId` và `keyword` không.
2. `conversationId` có hợp lệ không.
3. `keyword` có rỗng không.
4. `limit` không vượt quá giới hạn server cho phép.
5. User hiện tại có thuộc conversation này không.

Điểm quan trọng:

```text
Server không cho user search tin nhắn của conversation mà user không thuộc về.
```

Nếu hợp lệ, handler gọi:

```java
messageService.searchMessages(conversationId, keyword, limit, offset)
```

### 6.2. `Router.java`

File:

```text
Code/Server/src/main/java/com/server/tcp/Router.java
```

Mình thêm handler:

```java
private static SearchMessagesHandler searchMessagesHandler = new SearchMessagesHandler();
```

Và thêm case:

```java
case "SEARCH_MESSAGES":
    response = searchMessagesHandler.handleTcp(request, conn);
    break;
```

### 6.3. `MessageService.java`

File:

```text
Code/Server/src/main/java/com/server/service/MessageService.java
```

Mình thêm hàm:

```java
public List<Message> searchMessages(long conversationId, String keyword, int limit, int offset)
```

Service chỉ chuyển request xuống repository, giữ đúng mô hình:

```text
Handler -> Service -> Repository -> Database
```

### 6.4. `MessageRepository.java`

File:

```text
Code/Server/src/main/java/com/server/repository/MessageRepository.java
```

Mình thêm hàm:

```java
public List<Message> searchByConversation(long conversationId, String keyword, int limit, int offset)
```

Query đang dùng:

```sql
SELECT id, conversation_id, sender_id, type, content, created_at
FROM messages
WHERE conversation_id = ? AND LOWER(content) LIKE LOWER(?)
ORDER BY created_at DESC
LIMIT ? OFFSET ?
```

Ý nghĩa:

- Chỉ tìm trong conversation hiện tại.
- Tìm không phân biệt hoa thường.
- Sắp xếp tin mới hơn lên trước.
- Có `LIMIT` và `OFFSET` để sau này mở rộng phân trang.

## 7. Vì Sao Cần Kiểm Tra Member Của Conversation?

Nếu chỉ gửi `conversationId`, một client xấu có thể thử search conversation của người khác.

Vì vậy handler kiểm tra:

```java
conversationRepository.getMemberIds(conversationId).contains(userId)
```

Nếu user không thuộc conversation đó, server trả lỗi:

```text
Unauthorized message search request
```

Đây là điểm dễ bị giảng viên hỏi, nên cần giải thích rõ:

```text
Search message không chỉ là query DB. Server phải kiểm tra quyền trước, vì tin nhắn là dữ liệu riêng tư.
```

## 8. Các File Đã Đụng Tới

```text
Code/Client/src/main/java/ChatTcpClient.java
Code/Client/src/main/java/ChatView.java
Code/Server/src/main/java/com/server/handler/message/SearchMessagesHandler.java
Code/Server/src/main/java/com/server/tcp/Router.java
Code/Server/src/main/java/com/server/service/MessageService.java
Code/Server/src/main/java/com/server/repository/MessageRepository.java
Docs/11_Message_Search_TCP_Implementation.md
```

## 9. Cách Giải Thích Với Trưởng Nhóm

Có thể nói:

```text
Mình triển khai Message search theo TCP action SEARCH_MESSAGES. UI có ô tìm kiếm trong header chat. Client gửi conversationId và keyword qua ChatTcpClient. Server route qua Router tới SearchMessagesHandler, kiểm tra user có thuộc conversation không, rồi query messages.content trong DB và trả danh sách kết quả về UI.
```

## 10. Cách Trả Lời Nếu Giảng Viên Hỏi

Nếu thầy hỏi: "Tìm kiếm tin nhắn đi qua giao thức gì?"

Trả lời:

```text
Đi qua TCP socket. Client gửi action SEARCH_MESSAGES qua ChatTcpClient, không gọi HTTP endpoint.
```

Nếu thầy hỏi: "Server tìm theo cái gì?"

Trả lời:

```text
Server tìm theo conversationId và keyword. Query chỉ tìm trong bảng messages của conversation đang mở.
```

Nếu thầy hỏi: "Có kiểm tra quyền không?"

Trả lời:

```text
Có. Handler kiểm tra user hiện tại có thuộc conversation đó không rồi mới cho search.
```

Nếu thầy hỏi: "Tại sao cần limit và offset?"

Trả lời:

```text
Để tránh trả quá nhiều message một lần và để sau này có thể mở rộng phân trang kết quả search.
```

## 11. Kiểm Tra Cần Chạy

Sau khi code, cần chạy:

```powershell
cd Code/Client
mvn -q -DskipTests compile
```

```powershell
cd Code/Server
mvn -q -DskipTests compile
```
