# SinChat Codebase Structure

**Project:** SinChat (Real-Time Chat Application)
**Architecture:** Client-Server with TCP/JSON protocol and MySQL database
**Java Version:** 25

---

## TABLE OF CONTENTS
1. [Project Architecture Overview](#project-architecture-overview)
2. [Server Structure](#server-structure)
3. [Client Structure](#client-structure)
4. [Database Schema](#database-schema)
5. [Message Flow](#message-flow)
6. [Key Design Patterns](#key-design-patterns)
7. [File Count Summary](#file-count-summary)

---

## PROJECT ARCHITECTURE OVERVIEW

### Technology Stack
| Component | Technology | Version |
|---|---|---|
| **Runtime** | Java JDK | 25 |
| **Server Networking** | `java.net.ServerSocket` + Virtual Threads | JDK built-in |
| **Client GUI** | JavaFX | 25 |
| **Database** | MySQL | 8.x |
| **Connection Pool** | HikariCP | 5.1.0 |
| **JSON** | Gson | 2.10.1 |
| **Password Hashing** | jBCrypt | 0.4 |
| **Configuration** | dotenv-java | 3.0.0 |
| **Logging** | SLF4J + slf4j-simple | 2.0.13 |
| **Build** | Maven | 3.x |
| **Container** | Docker (multi-stage) | — |
| **Testing** | JUnit Jupiter + Mockito | 5.10.2 / 5.17.0 |

### High-Level Flow
```
Client (JavaFX Desktop App)
    ↓ TCP Socket (JSON lines, port 3000)
    ↓ LAN Discovery (port 9999)
Server (Virtual Threads)
    ↓ Router → 36 action types → 30 handlers
    ↓ Services → Repositories → HikariCP
Database (MySQL)
```

---

## SERVER STRUCTURE

### Directory Tree
```
Code/Server/
├── pom.xml
├── Dockerfile
├── .env
├── src/main/java/com/server/
│   ├── Main.java                          # Entry point
│   ├── ProfileHandler.java                # Profile get/update
│   ├── config/
│   │   └── Database.java                  # HikariCP pool + auto-migrations
│   ├── model/                             # 8 files
│   │   ├── User.java
│   │   ├── Message.java                   # Enum: TEXT/IMAGE/VIDEO/VOICE/FILE/SYSTEM
│   │   ├── MessageStatus.java             # Enum: SENT/DELIVERED/SEEN
│   │   ├── MessageSearchResult.java
│   │   ├── Friendship.java                # Enum: PENDING/ACCEPTED/BLOCKED
│   │   ├── Conversation.java              # Enum: PRIVATE/GROUP
│   │   ├── ChangeAvatar.java
│   │   └── Attachment.java
│   ├── repository/                        # 5 files
│   │   ├── UserRepository.java
│   │   ├── MessageRepository.java
│   │   ├── MessageStatusRepository.java
│   │   ├── FriendshipRepository.java
│   │   └── ConversationRepository.java
│   ├── service/                           # 6 files
│   │   ├── AuthService.java               # Login, register, OTP, change password
│   │   ├── MessageService.java            # Send, get, edit, delete, search
│   │   ├── ConversationService.java       # Private/group CRUD, member mgmt
│   │   ├── FriendshipService.java         # Friend requests, block/unblock
│   │   ├── AvatarService.java             # Base64 decode, resize, BLOB storage
│   │   └── UserNameService.java           # Display name update
│   ├── handler/                           # 30 files
│   │   ├── TypingHandler.java
│   │   ├── PingHandler.java
│   │   ├── JoinHandler.java
│   │   ├── auth/                          # 4 files
│   │   │   ├── LoginHandler.java          # Rate limiting: 5 fails → 60s lockout
│   │   │   ├── RegisterHandler.java
│   │   │   ├── ForgotPasswordHandler.java # 6-digit OTP, 5-min TTL, timing-attack
│   │   │   └── ChangePasswordHandler.java
│   │   ├── message/                       # 14 files
│   │   │   ├── SendMessageHandler.java
│   │   │   ├── GetMessagesHandler.java
│   │   │   ├── GetConversationsHandler.java
│   │   │   ├── ConversationHandler.java
│   │   │   ├── CreateGroupHandler.java
│   │   │   ├── GroupManagementHandler.java
│   │   │   ├── LeaveGroupHandler.java
│   │   │   ├── EditMessageHandler.java
│   │   │   ├── DeleteMessageHandler.java
│   │   │   ├── SearchMessagesHandler.java
│   │   │   ├── SearchUserHandler.java
│   │   │   ├── PinMessageHandler.java
│   │   │   ├── UnpinMessageHandler.java
│   │   │   ├── SetPinPolicyHandler.java
│   │   │   └── UpdateMessageStatusHandler.java
│   │   ├── friendship/                    # 8 files
│   │   │   ├── SendFriendRequestHandler.java
│   │   │   ├── RespondFriendRequestHandler.java
│   │   │   ├── GetFriendsHandler.java
│   │   │   ├── GetFriendRequestsHandler.java
│   │   │   ├── GetFriendshipStatusHandler.java
│   │   │   ├── UnfriendHandler.java
│   │   │   ├── BlockUserHandler.java
│   │   │   └── UnblockUserHandler.java
│   │   ├── changeavatar/
│   │   │   └── AvatarHandler.java
│   │   ├── avatar/
│   │   │   └── GetAvatarHandler.java
│   │   └── changeName/
│   │       └── NameHandler.java
│   └── tcp/                               # 9 files
│       ├── TcpServer.java                 # Virtual thread acceptor + lifecycle
│       ├── ClientConnection.java          # Per-client read loop + dispatch
│       ├── Router.java                    # Static dispatch on ~36 actions
│       ├── TcpConnectionManager.java      # userId ↔ Set<ClientConnection>
│       ├── PresenceService.java           # Online/offline broadcast
│       ├── LanDiscoveryBroadcaster.java   # Port 9999 discovery
│       ├── IdleConnectionSweeper.java     # 5s interval, 60s timeout
│       ├── TcpServerSocketFactory.java    # Plain/TLS socket factory
│       └── Connection.java                # Abstract base
└── src/test/java/com/server/
    ├── handler/       # Handler unit tests
    ├── service/       # Service unit tests
    ├── model/         # Model validation tests
    └── integration/   # End-to-end TCP integration tests
```

### Server File Count: 64 source + 16 test = 80 Java files

---

## CLIENT STRUCTURE

### Directory Tree
```
Code/Client/
├── pom.xml
├── dependency-reduced-pom.xml
└── src/main/
    ├── java/com/client/
    │   ├── Main.java                          # JavaFX Application
    │   ├── Launcher.java                      # Fat JAR bootstrap
    │   ├── controller/                        # 2 files
    │   │   ├── AuthController.java            # Async auth operations
    │   │   └── ChatController.java            # Async chat operations
    │   ├── service/                           # 2 files
    │   │   ├── ChatService.java               # TCP client (Singleton, ~40 methods)
    │   │   └── LanDiscoveryService.java       # LAN auto-discovery
    │   ├── view/                              # 8 files
    │   │   ├── LoginView.java                 # Auth UI (3 screens)
    │   │   ├── ChatView.java                  # Main 3-panel chat (~2000+ lines)
    │   │   ├── CreateGroupDialog.java
    │   │   ├── ManageGroupDialog.java
    │   │   ├── AvatarModalView.java
    │   │   ├── ChangePasswordDialog.java
    │   │   ├── ChangeUsernameDialog.java
    │   │   └── FriendRequestHistoryDialog.java
    │   ├── model/                             # 4 files
    │   │   ├── User.java
    │   │   ├── Message.java
    │   │   ├── Conversation.java
    │   │   └── ApiResponse.java               # record
    │   ├── emoji/                             # 2 files
    │   │   ├── EmojiManager.java              # WeChat-style rendering
    │   │   └── EmojiDef.java
    │   └── util/                              # 3 files
    │       ├── TimeUtils.java                 # Vietnamese relative time
    │       ├── StyleConstants.java            # Centralized theme
    │       └── ImageUtils.java                # Image encode/decode
    └── resources/
        └── emojis/
            ├── emoji_list.json
            ├── animated/
            └── static/
```

### Client File Count: 23 Java files

---

## DATABASE SCHEMA

Key tables (auto-migrated by `Database.runMigrations()`):

| Table | Purpose |
|---|---|
| `users` | User accounts: id, username, password_hash, email, is_online, last_seen, created_at |
| `conversations` | Chat conversations: id, type (PRIVATE/GROUP), name, avatar_url, created_by, last_message_at |
| `conversation_members` | Membership: conversation_id, user_id, role, joined_at |
| `messages` | Chat messages: id, conversation_id, sender_id, type, content, created_at, reply_to_message_id, forward_from_id, is_pinned, is_deleted, edited_to_id, pinned_by |
| `message_status` | Per-recipient status: message_id, user_id, status (SENT/DELIVERED/SEEN), updated_at |
| `attachments` | File metadata: id, message_id, file_url, file_name, file_size, mime_type |
| `friendships` | Friend relationships: user1_id, user2_id, status (PENDING/ACCEPTED/BLOCKED), action_user_id, created_at, updated_at |
| `user_avatars` | Avatar BLOB storage: user_id, avatar_data, updated_at |
| `conversation_roles` | Custom roles: conversation_id, user_id, role |
| `calls` | Call history (schema defined, not yet implemented) |
| `call_participants` | Call participants (schema defined, not yet implemented) |

---

## MESSAGE FLOW

```
Client (ChatService.sendMessage)
 → TCP Socket: {"action":"SEND_MESSAGE", "conversationId":45, ...}
 → Server ClientConnection.run() → reader.readLine()
 → Router.route() → "SEND_MESSAGE" → SendMessageHandler
 → MessageService.sendMessage() → MessageRepository.save() [transactional]
 → Response to sender: SEND_MESSAGE_RESPONSE {messageId, ...}
 → TcpConnectionManager.broadcastToUser(memberId, NEW_MESSAGE)
 → Recipient Client: ChatService reader → onNewMessage callback → ChatView
```

---

## KEY DESIGN PATTERNS

| Pattern | Where | Purpose |
|---|---|---|
| **Singleton** | `ChatService`, `AuthService`, `TcpConnectionManager`, `PresenceService`, `EmojiManager` | Single instance management |
| **Strategy/Command** | Handlers (`handleTcp` method) | Each action has its own handler class |
| **Observer** | `ChatService` callbacks (15+ event consumers) | Push event dispatching |
| **Repository** | `UserRepository`, `MessageRepository`, etc. | Data access abstraction |
| **Factory** | `TcpServerSocketFactory` | Plain/TLS socket creation |
| **MVC** | Client: `view/` → `controller/` → `service/` | Separation of concerns |
| **Virtual Threads** | `TcpServer` → `Thread.ofVirtual()` | High-concurrency without thread pools |
| **Future/Promise** | `CompletableFuture<ApiResponse>` in `pendingRequests` | Async request-response |
| **Connection Pool** | HikariCP in `Database.java` | Database connection reuse |

---

## FILE COUNT SUMMARY

| Category | Count |
|---|---|
| **Server Source** (`main`) | 64 Java files |
| **Server Tests** (`test`) | 16 Java files |
| **Client Source** (`main`) | 23 Java files |
| **Total Java Files** | 103 |
| **Documentation** | 12 Markdown files |
| **Database** | 11 tables (auto-migrated) |
- **Purpose:** User profile retrieval and updates
- **Methods:** `handleTcp(request, connection)`
- **Responsibility:** Get/update username, status message, online status

---

### Repositories (Data Access)

Repositories handle database queries with JDBC.

**[UserRepository.java](../Code/Server/src/main/java/com/server/repository/UserRepository.java)**
- **Methods:**
  - `findByUsername(username)` → User or null
  - `findById(userId)` → User or null
  - `save(user)` → boolean (insert new user)
  - `update(user)` → boolean (update existing user)
  - `delete(userId)` → boolean
- **Implementation:** JDBC prepared statements with Database connection pool

**[MessageRepository.java](../Code/Server/src/main/java/com/server/repository/MessageRepository.java)**
- **Methods:** (assumed)
  - `save(message)` → boolean
  - `findByConversationId(conversationId)` → List<Message>
  - `findById(messageId)` → Message or null
- **Database Table:** `messages` with indexes on conversation_id and sender_id

**[ConversationRepository.java](../Code/Server/src/main/java/com/server/repository/ConversationRepository.java)**
- **Methods:** (assumed)
  - `save(conversation)` → boolean
  - `findById(conversationId)` → Conversation or null
  - `findByUserId(userId)` → List<Conversation>
  - `addMember(conversationId, userId, role)` → boolean

---

### Models (Data Objects)

**[User.java](../Code/Server/src/main/java/com/server/model/User.java)**
```java
public class User {
    private long id;                  // PK, auto-increment
    private String username;          // UNIQUE, VARCHAR(50)
    private String passwordHash;      // VARCHAR(255)
    private String email;             // UNIQUE, VARCHAR(100)
    private String avatarUrl;         // TEXT (URL)
    private String statusMessage;     // VARCHAR(255)
    private boolean isOnline;         // TINYINT(1)
    private Timestamp lastSeen;       // TIMESTAMP
    private Timestamp createdAt;      // TIMESTAMP
}
```

**[Message.java](../Code/Server/src/main/java/com/server/model/Message.java)**
```java
public class Message {
    public enum MessageType { TEXT, IMAGE, VIDEO, VOICE, FILE, SYSTEM }
    
    private long id;                    // PK, auto-increment
    private long conversationId;        // FK → conversations.id
    private long senderId;              // FK → users.id
    private MessageType type;           // ENUM, default TEXT
    private String content;             // TEXT
    private Timestamp createdAt;        // TIMESTAMP
}
```

**[Conversation.java](../Code/Server/src/main/java/com/server/model/Conversation.java)**
```java
public class Conversation {
    public enum ConversationType { PRIVATE, GROUP }
    
    private long id;                        // PK, auto-increment
    private ConversationType type;          // ENUM: PRIVATE or GROUP
    private String name;                    // VARCHAR(100), null for PRIVATE
    private String avatarUrl;               // TEXT (group avatar)
    private Long createdBy;                 // FK → users.id
    private Timestamp createdAt;            // TIMESTAMP
    private Timestamp lastMessageAt;        // TIMESTAMP
}
```

**[Attachment.java](../Code/Server/src/main/java/com/server/model/Attachment.java)**
```java
public class Attachment {
    private long id;
    private long messageId;             // FK → messages.id
    private String fileUrl;             // TEXT
    private String fileName;            // VARCHAR(255)
    private long fileSize;              // BIGINT
    private String mimeType;            // VARCHAR(100)
}
```

**[MessageStatus.java](../Code/Server/src/main/java/com/server/model/MessageStatus.java)**
```java
public class MessageStatus {
    public enum Status { SENT, DELIVERED, SEEN }
    
    private long messageId;             // FK → messages.id
    private long userId;                // FK → users.id
    private Status status;              // ENUM
    private Timestamp updatedAt;        // TIMESTAMP
}
```

**[Friendship.java](../Code/Server/src/main/java/com/server/model/Friendship.java)**
```java
public class Friendship {
    public enum FriendshipStatus { PENDING, ACCEPTED, BLOCKED }
    
    private long user1Id;               // FK, part of composite PK
    private long user2Id;               // FK, part of composite PK
    private FriendshipStatus status;    // ENUM
}
```

**[ChangeAvatar.java](../Code/Server/src/main/java/com/server/model/ChangeAvatar.java)**
- Purpose: Data transfer object for avatar update requests

---

### Removed Legacy Realtime Layer

**[websocket/](../Code/Server/src/main/java/com/server/websocket/)**
- Currently empty folder
- Legacy placeholder only. Real-time messaging is handled by `TcpServer`, `ClientConnection`, and `Router`.

---

### Test Suite

**Test Location:** `src/test/java/com/server/`

#### Unit Tests

**Handler Tests (`handler/`)**
- [ForgotPasswordHandlerTest.java](../Code/Server/src/test/java/com/server/handler/auth/ForgotPasswordHandlerTest.java)
  - Tests reset code generation and password reset flow
- [RegisterHandlerTest.java](../Code/Server/src/test/java/com/server/handler/auth/RegisterHandlerTest.java)
  - Tests user registration with various inputs

**Model Tests (`model/`)**
- [UserTest.java](../Code/Server/src/test/java/com/server/model/UserTest.java)
- [MessageTest.java](../Code/Server/src/test/java/com/server/model/MessageTest.java)
- [ConversationTest.java](../Code/Server/src/test/java/com/server/model/ConversationTest.java)
- [AttachmentTest.java](../Code/Server/src/test/java/com/server/model/AttachmentTest.java)
- [MessageStatusTest.java](../Code/Server/src/test/java/com/server/model/MessageStatusTest.java)
- [FriendshipTest.java](../Code/Server/src/test/java/com/server/model/FriendshipTest.java)
- [ChangeAvatarTest.java](../Code/Server/src/test/java/com/server/model/ChangeAvatarTest.java)

**Service Tests (`service/`)**
- [AuthServiceTest.java](../Code/Server/src/test/java/com/server/service/AuthServiceTest.java)
  - Tests authentication logic, BCrypt hashing
- [MessageServiceTest.java](../Code/Server/src/test/java/com/server/service/MessageServiceTest.java)
- [ConversationServiceTest.java](../Code/Server/src/test/java/com/server/service/ConversationServiceTest.java)

#### Integration Tests (`integration/`)
- [AuthEndpointIntegrationTest.java](../Code/Server/src/test/java/com/server/integration/AuthEndpointIntegrationTest.java)
  - End-to-end authentication flow (register, login, forgot password)
- [EndpointIntegrationTest.java](../Code/Server/src/test/java/com/server/integration/EndpointIntegrationTest.java)
  - General TCP action integration tests
- [MessageEndpointIntegrationTest.java](../Code/Server/src/test/java/com/server/integration/MessageEndpointIntegrationTest.java)
  - Message sending and retrieval flow
- [AdditionalEndpointsIntegrationTest.java](../Code/Server/src/test/java/com/server/integration/AdditionalEndpointsIntegrationTest.java)
  - Profile, avatar, and other TCP action tests

---

## CLIENT STRUCTURE

### Location
```
Code/Client/
└── src/main/java/
    ├── Main.java
    ├── LoginView.java
    ├── ChatView.java
    └── ChatTcpClient.java
```

### Entry Point

**[Main.java](../Code/Client/src/main/java/Main.java)**
- **Purpose:** JavaFX application entry point
- **Functionality:**
  - Extends `Application` class (JavaFX)
  - Creates login scene on startup
  - Sets stage title to "SinChat"
  - Displays stage with login UI

---

### UI Components

**[LoginView.java](../Code/Client/src/main/java/LoginView.java)**
- **Purpose:** Login screen UI and logic
- **Key Features:**
  - Username/email input field
  - Password field with show/hide toggle
  - "Forgot Password" flow
  - "Register" navigation to registration screen
  - Form validation
  - Loading states during authentication
- **Styling:** Black background theme
- **Integration:** Uses `ChatTcpClient` for server communication

**[ChatView.java](../Code/Client/src/main/java/ChatView.java)**
- **Purpose:** Main chat interface after login
- **Key Features:**
  - Conversation list sidebar
  - Message display area
  - Message input field
  - User profile display (avatar, status message)
  - Real-time message updates
  - Conversation selection
  - Online status indicators
- **Styling:** Matches LoginView theme

---

### Network Client

**[ChatTcpClient.java](../Code/Client/src/main/java/ChatTcpClient.java)**
- **Purpose:** TCP socket client for server communication
- **Architecture:** Singleton pattern
- **Key Properties:**
  - `HOST`: "localhost"
  - `PORT`: 3000
  - `socket`: TCP socket connection
  - `reader`: BufferedReader for JSON responses
  - `writer`: PrintWriter for JSON requests
  - `gson`: Gson JSON serializer
  - `pendingRequests`: Map of request IDs to CompletableFutures for async responses

**Connection Methods:**
- `getInstance()`: Get or create singleton instance
- `connectAsync()`: Establish connection in background thread
  - Retry logic for connection failures
  - Reader/writer initialization with UTF-8 encoding
  - Separate thread for handling incoming messages

**Request Methods:**
- `login(username, password)` → CompletableFuture<ApiResponse>
- `register(username, password, email)` → CompletableFuture<ApiResponse>
- `sendMessage(conversationId, message)` → CompletableFuture<ApiResponse>
- `getMessages(conversationId)` → CompletableFuture<ApiResponse>
- `getConversations()` → CompletableFuture<ApiResponse>
- `getOrCreateConversation(userId1, userId2)` → CompletableFuture<ApiResponse>
- `updateAvatar(avatarUrl)` → CompletableFuture<ApiResponse>

**Event Callbacks:**
- `onNewMessage`: Consumer<JsonObject> - fired on incoming messages
- `onUserTyping`: Consumer<JsonObject> - fired on typing indicators
- `onConnected`: Runnable - fired on successful connection
- `onDisconnected`: Consumer<String> - fired on disconnection
- `onError`: Consumer<String> - fired on errors

**Internal Mechanism:**
- Each request gets unique `requestId` (UUID)
- Request is sent to server with `requestId`
- Server echoes `requestId` in response
- Client matches response to pending request via `requestId`
- CompletableFuture is completed with response
- Message listener thread (background) processes all incoming JSON

---

## DATABASE SCHEMA

### Database: `roacqgfa_ltm`
### Engine: MySQL 5.7
### Charset: utf8mb4_unicode_ci

### Tables

#### 1. **users**
```sql
CREATE TABLE users (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(50) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  email VARCHAR(100) UNIQUE,
  avatar_url TEXT,
  status_message VARCHAR(255),
  is_online TINYINT(1) DEFAULT 0,
  last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
```
- **Sample Data:** 2 test users (testuser, admin) with bcrypt hashed passwords

#### 2. **conversations**
```sql
CREATE TABLE conversations (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  type ENUM('PRIVATE', 'GROUP') NOT NULL,
  name VARCHAR(100),  -- null for PRIVATE
  avatar_url TEXT,    -- group avatar URL
  created_by BIGINT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_message_at TIMESTAMP,
  FOREIGN KEY (created_by) REFERENCES users(id)
)
```

#### 3. **conversation_members**
```sql
CREATE TABLE conversation_members (
  conversation_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  role ENUM('MEMBER', 'ADMIN') DEFAULT 'MEMBER',
  joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (conversation_id, user_id),
  FOREIGN KEY (conversation_id) REFERENCES conversations(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
)
```

#### 4. **messages**
```sql
CREATE TABLE messages (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  conversation_id BIGINT NOT NULL,
  sender_id BIGINT NOT NULL,
  type ENUM('TEXT', 'IMAGE', 'VIDEO', 'VOICE', 'FILE', 'SYSTEM') DEFAULT 'TEXT',
  content TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_messages_conversation (conversation_id),
  FOREIGN KEY (conversation_id) REFERENCES conversations(id),
  FOREIGN KEY (sender_id) REFERENCES users(id)
)
```

#### 5. **message_status**
```sql
CREATE TABLE message_status (
  message_id BIGINT,
  user_id BIGINT,
  status ENUM('SENT', 'DELIVERED', 'SEEN'),
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id)
)
```
- **Purpose:** Track delivery status of messages per user

#### 6. **attachments**
```sql
CREATE TABLE attachments (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  message_id BIGINT,
  file_url TEXT,
  file_name VARCHAR(255),
  file_size BIGINT,
  mime_type VARCHAR(100),
  FOREIGN KEY (message_id) REFERENCES messages(id)
)
```
- **Purpose:** Store file attachments with metadata

#### 7. **friendships**
```sql
CREATE TABLE friendships (
  user1_id BIGINT NOT NULL,
  user2_id BIGINT NOT NULL,
  status ENUM('PENDING', 'ACCEPTED', 'BLOCKED'),
  PRIMARY KEY (user1_id, user2_id),
  FOREIGN KEY (user1_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (user2_id) REFERENCES users(id) ON DELETE CASCADE
)
```
- **Purpose:** Friend request and friend list management

#### 8. **calls** (Planned/Not Implemented)
```sql
CREATE TABLE calls (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  conversation_id BIGINT,
  started_by BIGINT,
  type ENUM('VOICE', 'VIDEO'),
  started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  ended_at TIMESTAMP,
  FOREIGN KEY (conversation_id) REFERENCES conversations(id),
  FOREIGN KEY (started_by) REFERENCES users(id)
)
```
- **Purpose:** Voice/video call history

#### 9. **call_participants** (Planned/Not Implemented)
```sql
CREATE TABLE call_participants (
  call_id BIGINT,
  user_id BIGINT,
  joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  left_at TIMESTAMP,
  FOREIGN KEY (call_id) REFERENCES calls(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
)
```
- **Purpose:** Track participants in multi-user calls

---

## MESSAGE FLOW

### 1. Login Flow
```
Client                          Server
  |  {"action":"LOGIN",          |
  |   "username":"admin",        |
  |   "password":"pass123"}  --> Router
                                 |
                                 |---> LoginHandler
                                        |
                                        |---> AuthService.login()
                                              |
                                              |---> UserRepository.findByUsername()
                                                   (Database Query)
                                              |
                                              |---> BCrypt.checkpw()
                                                   (Password Verification)
                                        |
                                        |<--- User object or null
                                 |
  | <-- {"status":"success",
  |      "userId":1,
  |      "username":"admin"}
```

### 2. Send Message Flow
```
Client                          Server
  | {"action":"SEND_MESSAGE",    |
  |  "conversationId":1,         |
  |  "message":"Hello"}     --> Router
                                 |
                                 |---> SendMessageHandler
                                        |
                                        |---> MessageService.sendMessage()
                                              |
                                              |---> MessageRepository.save()
                                                   (Insert into messages table)
                                        |
                                        |<--- Message object
                                 |
  | <-- {"status":"success",
  |      "messageId":123,
  |      "createdAt":"..."}
```

### 3. Get Conversations Flow
```
Client                          Server
  | {"action":"GET_USER_CONVERSATIONS",
  |  "userId":1}            --> Router
                                 |
                                 |---> GetConversationsHandler
                                        |
                                        |---> ConversationService
                                              |
                                              |---> ConversationRepository.findByUserId()
                                                   (Query with conversation_members join)
                                        |
                                        |<--- List<Conversation>
                                 |
  | <-- {"status":"success",
  |      "conversations":[
  |        {"id":1, "type":"PRIVATE", ...}
  |      ]}
```

---

## KEY DESIGN PATTERNS

### 1. **Singleton Pattern**
- `ChatTcpClient`: Single instance per client (lazy initialized)
- `Router`: Reusable handler instances
- `AuthService`, etc.: Single instances per service

**Benefit:** Reduce object creation overhead, centralized state management

### 2. **Handler Pattern**
- Each action has dedicated handler class
- `handleTcp(JsonObject, ClientConnection)` method signature
- Loose coupling between router and handlers

**Benefit:** Separation of concerns, easy to test and extend

### 3. **Service Layer Pattern**
- Business logic isolated in service classes
- Services delegate data access to repositories
- Testable independently

**Benefit:** Clean architecture, business logic centralization

### 4. **Repository Pattern**
- Data access abstraction via repository classes
- JDBC queries wrapped in repository methods
- Connection pooling managed centrally

**Benefit:** Database independence, query optimization, easy mocking

### 5. **Model/Entity Pattern**
- Plain Java objects representing database entities
- Getters/setters for all properties
- Enums for fixed values (MessageType, ConversationType, etc.)

**Benefit:** Type safety, clear data structure

### 6. **Factory Pattern**
- `Database.getConnection()`: Returns pooled connections
- Connection pooling via HikariCP

**Benefit:** Connection reuse, resource efficiency

### 7. **Observer Pattern (Callbacks)**
- ChatTcpClient event callbacks: `onNewMessage`, `onConnected`, etc.
- View components subscribe to events

**Benefit:** Decoupled event handling, reactive UI updates

### 8. **JSON RPC Style**
- Request/Response with unique IDs
- `requestId` echoed in response
- Supports async request matching

**Benefit:** Correlation of requests/responses over TCP

### 9. **Thread Pool Pattern**
- TcpServer uses ExecutorService (100 threads)
- Each client connection handled in separate thread
- Prevents blocking on I/O

**Benefit:** Scalability, non-blocking server

### 10. **Async/Future Pattern**
- Client sends requests and gets CompletableFuture
- Background thread receives responses
- Future completed when response arrives

**Benefit:** Non-blocking client, responsive UI

---

## BUILD & DEPLOYMENT

### Server Build
```bash
cd Code/Server
mvn clean package
```

### Client Build
```bash
cd Code/Client
mvn clean package
```

### Docker Deployment
```bash
docker-compose up
```
- Server: Container running Java application on port 3000
- Database: MySQL container

### Configuration
- `.env` file in `Code/Server` directory:
  - `PORT`: Server port (default 3000)
  - `DB_URL`: Database JDBC URL
  - `DB_USER`: Database username
  - `DB_PASSWORD`: Database password

---

## SUMMARY

This is a well-architected **client-server chat application** with:
- **Clean Separation:** UI (Client) → Network (TCP/JSON) → Server → Database
- **Scalable:** Thread pool on server, connection pooling on DB
- **Secure:** BCrypt password hashing, prepared statements to prevent SQL injection
- **Testable:** Comprehensive unit and integration tests
- **Extensible:** Handler pattern allows easy addition of new TCP actions
- **Production-Ready:** Logging, error handling, environment configuration

The project demonstrates solid Java enterprise patterns and is suitable for real-world deployment on cloud platforms.

