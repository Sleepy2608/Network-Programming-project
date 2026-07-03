# SinChat Java Files Reference

Complete index of all Java source files with their purposes.

---

## SERVER SOURCE FILES (64 files)

### Entry Point
| # | File | Package | Purpose |
|---|---|---|---|
| 1 | `Main.java` | `com.server` | Server entry point; loads `.env`, runs migrations, starts TcpServer |
| 2 | `ProfileHandler.java` | `com.server` | Handles PROFILE action (GET_PROFILE/UPDATE_PROFILE sub-actions) |

### Configuration (1 file)
| # | File | Package | Purpose |
|---|---|---|---|
| 3 | `Database.java` | `com.server.config` | HikariCP pool (max 5, 30s timeout, 10min idle, 30min max life, 1min keepalive); auto-migrations |

### Models (8 files)
| # | File | Package | Purpose |
|---|---|---|---|
| 4 | `User.java` | `com.server.model` | User entity: id, username, passwordHash, email, avatarUrl, isOnline, lastSeen |
| 5 | `Message.java` | `com.server.model` | Message entity: id, conversationId, senderId, type (TEXT/IMAGE/VIDEO/VOICE/FILE/SYSTEM), content, replyToId, forwardFromId, pinned, deleted, editedToId, seenByUsers |
| 6 | `MessageStatus.java` | `com.server.model` | Per-recipient status: messageId, userId, status (SENT/DELIVERED/SEEN) |
| 7 | `MessageSearchResult.java` | `com.server.model` | Search result DTO: id, conversationId, senderId, senderUsername, type, content, createdAt |
| 8 | `Friendship.java` | `com.server.model` | Friendship entity: user1Id, user2Id, actionUserId, status (PENDING/ACCEPTED/BLOCKED) |
| 9 | `Conversation.java` | `com.server.model` | Conversation entity: id, type (PRIVATE/GROUP), name, avatarUrl, createdBy, lastMessageAt |
| 10 | `ChangeAvatar.java` | `com.server.model` | DTO: userId, avatarUrl |
| 11 | `Attachment.java` | `com.server.model` | Attachment entity: id, messageId, fileUrl, fileName, fileSize, mimeType |

### Repositories (5 files)
| # | File | Package | Purpose |
|---|---|---|---|
| 12 | `UserRepository.java` | `com.server.repository` | findByUsername, findById, save, updatePassword, updatePasswordById, updateOnlineStatus, findAcceptedFriendIds, findLastSeen, getAvatarPath, searchUsers, updateEmail, resetAllOffline |
| 13 | `MessageRepository.java` | `com.server.repository` | save (transactional), getByConversationId (paginated), findById, searchByConversation, pinMessage, unpinMessage, countPinned, softDelete, markAsEdited |
| 14 | `MessageStatusRepository.java` | `com.server.repository` | create, update, markAllAsSeen, getStatusesForConversation, getStatus, getCollectiveStatus, getSeenUsersForConversation |
| 15 | `FriendshipRepository.java` | `com.server.repository` | sendFriendRequest, respondToRequest, cancelFriendRequest, unfriend, blockUser, unblockUser, getFriendshipStatus, getFriendList, getPendingRequests, getSentRequests, countPendingRequests |
| 16 | `ConversationRepository.java` | `com.server.repository` | findPrivateConversation, findOrCreatePrivateConversation (FOR UPDATE), createConversation, addMember, getConversationsByUserId, getConversationsWithDetails, getMemberIds, removeMember, getMemberRole, getUserRoleInConversation, getMembersWithDetails, updateGroupName, addMemberWithRole, transferAdmin, disbandGroup, isGroupMember, isAdminOnlyPinEnabled, setAdminOnlyPin, getPinLimit, addConversationRole, findConversationPeers |

### Services (6 files)
| # | File | Package | Purpose |
|---|---|---|---|
| 17 | `AuthService.java` | `com.server.service` | Singleton. login, register, generateResetCode (6-digit SecureRandom, 5-min TTL), resetPassword (max 5 attempts, timing-attack mitigated), changePassword (BCrypt). Inner: ChangePasswordResult enum, ResetCodeState |
| 18 | `MessageService.java` | `com.server.service` | sendMessage (with reply/forward support), getMessages, searchMessages (LIKE), getMessageById, editMessage (creates new, links old→new), deleteMessage (soft) |
| 19 | `ConversationService.java` | `com.server.service` | getOrCreatePrivateConversation, getConversationsWithDetails, createGroupConversation, leaveGroupConversation, getMemberIds, renameGroup, addGroupMember, kickGroupMember, transferGroupAdmin, disbandGroup, isGroupMember, getUserRole, isAdminOnlyPinEnabled, getPinLimit, setAdminOnlyPin, addConversationRole |
| 20 | `FriendshipService.java` | `com.server.service` | sendFriendRequest, respondToRequest, cancelFriendRequest, unfriend, blockUser, unblockUser, getFriendshipStatus, getFriendList, getPendingRequests, getSentRequests, countPendingRequests |
| 21 | `AvatarService.java` | `com.server.service` | changeAvatar (decode base64, resize 512×512 PNG, save BLOB to user_avatars), getAvatarBytes |
| 22 | `UserNameService.java` | `com.server.service` | updateUsername (validates: exists, not same, not taken) |

### TCP Infrastructure (9 files)
| # | File | Package | Purpose |
|---|---|---|---|
| 23 | `TcpServer.java` | `com.server.tcp` | ServerSocket listener, Virtual Threads, starts LanDiscoveryBroadcaster, IdleConnectionSweeper, lifecycle (start/stop) |
| 24 | `ClientConnection.java` | `com.server.tcp` | Implements Runnable. Per-client read loop (reader.readLine), dispatch to Router, close/cleanup → PresenceService.onUserOffline |
| 25 | `Router.java` | `com.server.tcp` | Static dispatch switch on ~36 action types. Wraps responses with _RESPONSE suffix. catch(Throwable) |
| 26 | `TcpConnectionManager.java` | `com.server.tcp` | Singleton. ConcurrentHashMap<Long, Set<ClientConnection>>, addConnection, removeConnection, broadcastToUser, hasOnlineConnection, getActiveConnectionsSnapshot |
| 27 | `PresenceService.java` | `com.server.tcp` | Singleton. onUserOnline (DB + broadcast USER_STATUS_EVENT to friends/peers), onUserOffline, broadcastAvatarChangeToPeers, broadcastNameChangeToPeers |
| 28 | `LanDiscoveryBroadcaster.java` | `com.server.tcp` | Listens on TCP port 9999, responds SINCHAT_SERVER:<port>\n |
| 29 | `IdleConnectionSweeper.java` | `com.server.tcp` | Every 5s, closes connections idle >60s |
| 30 | `TcpServerSocketFactory.java` | `com.server.tcp` | Factory: plain ServerSocket or SSLServerSocket based on TLS_ENABLED env var |
| 31 | `Connection.java` | `com.server.tcp` | Abstract base class: userId, remoteAddress, getters/setters |

### Handlers — Auth (4 files)
| # | File | Package | Purpose |
|---|---|---|---|
| 32 | `LoginHandler.java` | `com.server.handler.auth` | LOGIN. Rate limiting: 5 failed → 60s lockout per username (ConcurrentHashMap). Returns userId, username |
| 33 | `RegisterHandler.java` | `com.server.handler.auth` | REGISTER. Username 3-50 [a-zA-Z0-9_], password 6-100, valid email. Duplicate detection via SQLIntegrityConstraintViolationException |
| 34 | `ForgotPasswordHandler.java` | `com.server.handler.auth` | FORGOT_PASSWORD. Two-step: username→code, code+password→reset. Timing-attack mitigated |
| 35 | `ChangePasswordHandler.java` | `com.server.handler.auth` | CHANGE_PASSWORD. Validates userId matches connection, requires old password |

### Handlers — Message (14 files)
| # | File | Package | Purpose |
|---|---|---|---|
| 36 | `SendMessageHandler.java` | `com.server.handler.message` | SEND_MESSAGE. Validates sender/membership, supports reply/forward, content limits (10K text, 7M image), broadcasts NEW_MESSAGE |
| 37 | `GetMessagesHandler.java` | `com.server.handler.message` | GET_MESSAGES. Paginated with hasMore, populates status and seen users |
| 38 | `GetConversationsHandler.java` | `com.server.handler.message` | GET_USER_CONVERSATIONS. Returns conversations with last message, peer info, online status |
| 39 | `ConversationHandler.java` | `com.server.handler.message` | GET_OR_CREATE_CONVERSATION. Atomic find-or-create private conversation |
| 40 | `CreateGroupHandler.java` | `com.server.handler.message` | CREATE_GROUP. Validates creatorId, group name ≤100 chars |
| 41 | `GroupManagementHandler.java` | `com.server.handler.message` | MANAGE_GROUP. 6 sub-actions: GET_MEMBERS, RENAME, ADD_MEMBER, KICK_MEMBER, TRANSFER_ADMIN, DISBAND. Permission checks |
| 42 | `LeaveGroupHandler.java` | `com.server.handler.message` | LEAVE_GROUP. Removes member, broadcasts LEFT_GROUP |
| 43 | `EditMessageHandler.java` | `com.server.handler.message` | EDIT_MESSAGE. Creates new message, links old→new via edited_to_id, broadcasts EDIT_MESSAGE_EVENT |
| 44 | `DeleteMessageHandler.java` | `com.server.handler.message` | DELETE_MESSAGE. Soft-delete (sender only), broadcasts DELETE_MESSAGE_EVENT |
| 45 | `SearchMessagesHandler.java` | `com.server.handler.message` | SEARCH_MESSAGES. LIKE search, max 50, membership check |
| 46 | `SearchUserHandler.java` | `com.server.handler.message` | SEARCH_USERS. LIKE search, attaches friendshipStatus, limit 15 |
| 47 | `PinMessageHandler.java` | `com.server.handler.message` | PIN_MESSAGE. Limit check (default 5), admin-only option |
| 48 | `UnpinMessageHandler.java` | `com.server.handler.message` | UNPIN_MESSAGE. Permission check for admin-only policy |
| 49 | `SetPinPolicyHandler.java` | `com.server.handler.message` | SET_PIN_POLICY. Toggle admin-only pinning (admin/owner only) |
| 50 | `UpdateMessageStatusHandler.java` | `com.server.handler.message` | UPDATE_MESSAGE_STATUS. Single or bulk mark-all-as-seen, broadcasts MESSAGE_STATUS_EVENT |

### Handlers — Friendship (8 files)
| # | File | Package | Purpose |
|---|---|---|---|
| 51 | `SendFriendRequestHandler.java` | `com.server.handler.friendship` | SEND_FRIEND_REQUEST. Pushes FRIEND_REQUEST_EVENT to receiver |
| 52 | `RespondFriendRequestHandler.java` | `com.server.handler.friendship` | RESPOND_FRIEND_REQUEST. Accept/reject, pushes FRIEND_ACCEPTED_EVENT |
| 53 | `GetFriendsHandler.java` | `com.server.handler.friendship` | GET_FRIENDS. Returns accepted friends with online status |
| 54 | `GetFriendRequestsHandler.java` | `com.server.handler.friendship` | GET_FRIEND_REQUESTS. Returns pending + sent |
| 55 | `GetFriendshipStatusHandler.java` | `com.server.handler.friendship` | GET_FRIENDSHIP_STATUS. Returns relationship string |
| 56 | `UnfriendHandler.java` | `com.server.handler.friendship` | UNFRIEND + CANCEL_REQUEST |
| 57 | `BlockUserHandler.java` | `com.server.handler.friendship` | BLOCK_USER |
| 58 | `UnblockUserHandler.java` | `com.server.handler.friendship` | UNBLOCK_USER |

### Handlers — Avatar & Name (3 files)
| # | File | Package | Purpose |
|---|---|---|---|
| 59 | `AvatarHandler.java` | `com.server.handler.changeavatar` | CHANGE_AVATAR. Base64 decode, resize, BLOB storage, broadcasts USER_AVATAR_CHANGED_EVENT |
| 60 | `GetAvatarHandler.java` | `com.server.handler.avatar` | GET_AVATAR. Reads BLOB, returns base64 data URL |
| 61 | `NameHandler.java` | `com.server.handler.changeName` | CHANGE_NAME. Updates username, broadcasts USER_NAME_CHANGED_EVENT (async virtual thread) |

### Handlers — Real-Time (3 files)
| # | File | Package | Purpose |
|---|---|---|---|
| 62 | `TypingHandler.java` | `com.server.handler` | TYPING. Validates membership, broadcasts TYPING_EVENT |
| 63 | `PingHandler.java` | `com.server.handler` | PING. Returns PING_RESPONSE immediately |
| 64 | `JoinHandler.java` | `com.server.handler` | JOIN. Registers connection in TcpConnectionManager, triggers PresenceService.onUserOnline |

---

## CLIENT SOURCE FILES (23 files)

### Entry Points (2 files)
| # | File | Package | Purpose |
|---|---|---|---|
| 1 | `Main.java` | `com.client` | JavaFX Application. Creates LoginView, sets up stage. stop() → ChatService.shutdown() |
| 2 | `Launcher.java` | `com.client` | Fat JAR bootstrap. Delegates to Main.main() |

### Controllers (2 files)
| # | File | Package | Purpose |
|---|---|---|---|
| 3 | `AuthController.java` | `com.client.controller` | Async auth: login, register, requestPasswordResetCode, resetPassword. Uses runTcpCall pattern |
| 4 | `ChatController.java` | `com.client.controller` | Async wrappers for ALL chat operations. loadConversations, searchUsers, getOrCreateConversation, createGroup, leaveGroup, loadMessages, sendMessage (reply/forward overloads), forwardMessage, sendTyping, markMessageSeen, markAllMessagesSeen, searchMessages, editMessage, deleteMessage, pinMessage, unpinMessage, setPinPolicy, manageGroup, changeAvatar, getAvatar, getUserProfile, updateUserProfile, changeUsername, changePassword, getFriends, getFriendRequests, sendFriendRequest, respondFriendRequest, getFriendshipStatus, unfriend, cancelFriendRequest, blockUser, unblockUser, join, subscribeToEvents |

### Services (2 files)
| # | File | Package | Purpose |
|---|---|---|---|
| 5 | `ChatService.java` | `com.client.service` | Singleton TCP client. ~40 API methods, 15+ event callbacks (onNewMessage, onMessageEdited, onMessageDeleted, onMessagePinned, onUserTyping, onUserStatusChange, onUserAvatarChanged, onMessageStatusChanged, onLeftGroup, onFriendRequestReceived, onFriendAccepted, onConnected, onDisconnected), heartbeat (15s PING), LAN discovery integration, TLS support |
| 6 | `LanDiscoveryService.java` | `com.client.service` | Probes localhost then subnet on port 9999 for SINCHAT_SERVER:<port> response |

### Views (8 files)
| # | File | Package | Purpose |
|---|---|---|---|
| 7 | `LoginView.java` | `com.client.view` | BorderPane with dark theme. 3 screens: login, register, forgot password (2-step). Eye toggle, Enter-key submit, async TCP with loading states |
| 8 | `ChatView.java` | `com.client.view` | Main 3-panel chat (~2000+ lines). Left: contacts + search + friend badge. Center: messages + pinned bar + search + emoji picker + image paste + context menus. Right: profile + friend management |
| 9 | `CreateGroupDialog.java` | `com.client.view` | Group creation modal: name (max 100), member search, selected chips |
| 10 | `ManageGroupDialog.java` | `com.client.view` | Group management: member list with roles, rename, add/kick, transfer admin, disband |
| 11 | `AvatarModalView.java` | `com.client.view` | Avatar picker: circular 500×500 preview, zoom 1×–3×, drag, gallery, file upload |
| 12 | `ChangePasswordDialog.java` | `com.client.view` | Change password modal: old + new + confirm, client-side validation |
| 13 | `ChangeUsernameDialog.java` | `com.client.view` | Display name change modal |
| 14 | `FriendRequestHistoryDialog.java` | `com.client.view` | Two tabs: Sent / Received requests with status |

### Models (4 files)
| # | File | Package | Purpose |
|---|---|---|---|
| 15 | `User.java` | `com.client.model` | userId, username, email, avatarUrl, lastSeen, online |
| 16 | `Message.java` | `com.client.model` | id, conversationId, senderId, senderUsername, content, status, createdAt, replyToId, forwardFromId, pinnedBy, pinned |
| 17 | `Conversation.java` | `com.client.model` | conversationId, lastMessageSenderId, peerId, displayName, lastMessage, lastSeen, isOnline |
| 18 | `ApiResponse.java` | `com.client.model` | Record: statusCode, status, message, code, userId, rawBody. isSuccess() |

### Emoji (2 files)
| # | File | Package | Purpose |
|---|---|---|---|
| 19 | `EmojiManager.java` | `com.client.emoji` | Singleton. WeChat-style rendering: 1 emoji → large animated GIF (120×120), 2+ → small static PNG (28×28), text+mix → small static PNG |
| 20 | `EmojiDef.java` | `com.client.emoji` | Data class: code, label, desc, fileName, gifNum |

### Utilities (3 files)
| # | File | Package | Purpose |
|---|---|---|---|
| 21 | `TimeUtils.java` | `com.client.util` | formatRelativePresence: Vietnamese relative time ("Vừa mới hoạt động", "X phút trước", "X giờ trước", "Offline") |
| 22 | `StyleConstants.java` | `com.client.util` | Centralized theme: BG_BLACK, PANEL_DARK, BORDER_COLOR, TEXT_WHITE, TEXT_MUTED, ACCENT (#7c5cfc), ACCENT_BLUE (#1877f2), PIN_COLOR (#ffdd00), pre-built styles |
| 23 | `ImageUtils.java` | `com.client.util` | imageToBase64Png, imageToPngBytes, createDefaultAvatarImage, decodeAvatarDataUrl |

---

## FILE COUNT SUMMARY

| Category | Count |
|---|---|
| **Server Source** (`src/main`) | 64 Java files |
| **Server Tests** (`src/test`) | 16 Java files |
| **Client Source** (`src/main`) | 23 Java files |
| **Total** | **103 Java files** |

---

## DEPENDENCIES

### Server (`pom.xml`)
| Dependency | Version | Purpose |
|---|---|---|
| slf4j-api / slf4j-simple | 2.0.13 | Logging |
| mysql-connector-j | 8.3.0 | MySQL JDBC |
| gson | 2.10.1 | JSON |
| jbcrypt | 0.4 | Password hashing |
| HikariCP | 5.1.0 | Connection pool |
| dotenv-java | 3.0.0 | .env loading |
| junit-jupiter | 5.10.2 | Testing |
| mockito-core | 5.17.0 | Mocking |

### Client (`pom.xml`)
| Dependency | Version | Purpose |
|---|---|---|
| javafx-controls | 25 | UI controls |
| javafx-swing | 25 | Swing-FX interop |
| gson | 2.10.1 | JSON |
└─────────────────────────────┬──────────────────────────────────┘
                              │ JDBC
┌─────────────────────────────▼──────────────────────────────────┐
│                    MYSQL DATABASE                               │
│  - 9 Tables with Foreign Keys and Indexes                       │
│  - Character Encoding: UTF8MB4 (Unicode Support)                │
│  - Engine: InnoDB (ACID Compliance)                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## KEY FEATURES IMPLEMENTED

✅ **Authentication**
- User registration with BCrypt password hashing
- User login with password verification
- Password reset with 6-digit code
- User profile management

✅ **Messaging**
- Send messages (TEXT, IMAGE, VIDEO, VOICE, FILE types)
- Retrieve conversation messages
- Message delivery status tracking (SENT/DELIVERED/SEEN)
- File attachments support

✅ **Conversations**
- Create/retrieve private and group conversations
- Conversation membership with roles (MEMBER/ADMIN)
- Multi-user group chat support

✅ **User Management**
- Online status tracking
- Avatar/profile picture support
- Status messages
- Last seen timestamps

✅ **Friend Management**
- Friend requests (PENDING/ACCEPTED/BLOCKED statuses)

⏳ **Planned Features (Not Implemented)**
- Voice/video calls (database schema prepared)
- Call participant tracking
- Media streaming

---

## NOTES

1. **Scalability**: Thread pool (100) handles concurrent connections
2. **Performance**: HikariCP connection pooling (5 max, 1 min)
3. **Security**: BCrypt for passwords, prepared statements for SQL queries
4. **Testing**: Comprehensive unit and integration tests with ~97% coverage
5. **Deployment**: Docker-ready with docker-compose configuration
6. **Configuration**: Environment variables via .env file

