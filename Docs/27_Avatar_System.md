# 🖼️ Avatar System Deep Dive

## Overview
The avatar system handles image upload, server-side processing (resize to 512×512 PNG), BLOB storage in MySQL, and real-time broadcast of avatar changes. The client provides a rich avatar picker with crop, zoom, and gallery features.

---

## Source Files

| Layer | File | Package |
|---|---|---|
| **Server Handler** | `AvatarHandler.java` | `com.server.handler.changeavatar` |
| **Server Handler** | `GetAvatarHandler.java` | `com.server.handler.avatar` |
| **Server Service** | `AvatarService.java` | `com.server.service` |
| **Client View** | `AvatarModalView.java` | `com.client.view` |
| **Client Util** | `ImageUtils.java` | `com.client.util` |
| **Server Broadcast** | `PresenceService.java` | `com.server.tcp` |

---

## Upload Flow (Detailed)

```mermaid
sequenceDiagram
    participant User as User
    participant Modal as AvatarModalView
    participant Utils as ImageUtils
    participant Ctrl as ChatController
    participant Svc as ChatService
    participant Handler as AvatarHandler
    participant AvSvc as AvatarService
    participant DB as user_avatars
    participant Presence as PresenceService
    participant Peers as Friends & Peers

    User->>Modal: Click avatar in profile / Select image from file chooser
    Modal->>Modal: Load image for preview
    User->>Modal: Adjust zoom (1×–3×), drag position
    User->>Modal: Click "Save"
    
    Modal->>Modal: Capture cropped region → JavaFX Image
    Modal->>Utils: ImageUtils.imageToBase64Png(croppedImage)
    Utils-->>Modal: "data:image/png;base64,iVBORw0KGgo..."
    
    Modal->>Ctrl: changeAvatar(croppedImage, onSuccess, onError)
    Ctrl->>Svc: changeAvatar(userId, base64DataUrl)
    Svc->>Handler: {"action":"CHANGE_AVATAR", "userId":12, "avatarUrl":"data:image/png;base64,..."}
    
    Handler->>Handler: Validate userId matches connection
    Handler->>AvSvc: changeAvatar(userId, base64DataUrl)
    
    AvSvc->>AvSvc: Strip "data:image/png;base64," prefix
    AvSvc->>AvSvc: Base64.decode(cleanBase64) → byte[]
    AvSvc->>AvSvc: javax.imageio.ImageIO.read(byte[]) → BufferedImage
    AvSvc->>AvSvc: Resize to 512×512 (preserve aspect ratio, center crop)
    AvSvc->>AvSvc: Encode as PNG → byte[]
    
    AvSvc->>DB: INSERT INTO user_avatars (user_id, avatar_data)<br/>ON DUPLICATE KEY UPDATE avatar_data=VALUES(avatar_data)
    DB-->>AvSvc: success
    
    AvSvc-->>Handler: true
    Handler-->>Svc: {"status":"success", "message":"Avatar updated", "avatarUrl":"db:12"}
    Svc-->>Ctrl: ApiResponse
    Ctrl-->>Modal: onSuccess → close modal, update all avatar displays
    
    Handler->>Presence: broadcastAvatarChangeToPeers(userId, "db:12")
    Presence->>Peers: USER_AVATAR_CHANGED_EVENT
    Peers->>Peers: Update avatar in contact list, chat header, message bubbles
```

---

## Server-Side Processing (`AvatarService.java`)

### Resize Algorithm
```java
public boolean changeAvatar(long userId, String base64DataUrl) {
    // 1. Decode base64
    String cleanBase64 = base64DataUrl.replaceFirst("data:image/\\w+;base64,", "");
    byte[] imageBytes = Base64.getDecoder().decode(cleanBase64);
    
    // 2. Read as BufferedImage
    BufferedImage original = ImageIO.read(new ByteArrayInputStream(imageBytes));
    
    // 3. Resize to 512×512 (center crop if not square)
    BufferedImage resized = resizeToSquare(original, 512);
    
    // 4. Encode as PNG
    ByteArrayOutputStream baos = new ByteArrayOutputStream();
    ImageIO.write(resized, "PNG", baos);
    byte[] pngBytes = baos.toByteArray();
    
    // 5. Store in DB
    String sql = "INSERT INTO user_avatars (user_id, avatar_data) VALUES (?, ?) " +
                 "ON DUPLICATE KEY UPDATE avatar_data = VALUES(avatar_data)";
    // ...
}
```

### Why 512×512?
- **Consistent display**: All avatars are the same resolution
- **Reasonable file size**: ~50-200KB per avatar as PNG
- **Sufficient quality**: Good for modern displays, even when scaled up

---

## Client-Side Processing (`ImageUtils.java`)

### Image to Base64
```java
public static String imageToBase64Png(Image image) {
    BufferedImage buffered = javafx.embed.swing.SwingFXUtils.fromFXImage(image, null);
    ByteArrayOutputStream baos = new ByteArrayOutputStream();
    ImageIO.write(buffered, "PNG", baos);
    return "data:image/png;base64," + Base64.getEncoder().encodeToString(baos.toByteArray());
}
```

### Decode Avatar Data URL
```java
public static Image decodeAvatarDataUrl(String dataUrl) {
    if (dataUrl == null) return createDefaultAvatarImage();
    if (dataUrl.startsWith("data:")) {
        // Decode base64
        String base64 = dataUrl.substring(dataUrl.indexOf(",") + 1);
        byte[] bytes = Base64.getDecoder().decode(base64);
        return new Image(new ByteArrayInputStream(bytes));
    } else if (dataUrl.startsWith("db:")) {
        // Server reference — needs GET_AVATAR call
        return null; // caller handles via ChatController.getAvatar()
    }
    // Regular URL
    return new Image(dataUrl, true);
}
```

### Default Avatar
When no avatar is set:
1. Try local file
2. Try online fallback URL
3. Generate colored circle with initials (deterministic color based on userId)

---

## Get Avatar Flow

```mermaid
sequenceDiagram
    participant UI as ChatView
    participant Svr as Server
    participant DB as user_avatars

    UI->>Svr: {"action":"GET_AVATAR", "userId":15, "requestId":"uuid"}
    Svr->>DB: SELECT avatar_data FROM user_avatars WHERE user_id = 15
    DB-->>Svr: BLOB bytes
    
    alt Avatar exists
        Svr->>Svr: Base64.getEncoder().encode(blobBytes)
        Svr->>Svr: "data:image/png;base64," + encoded
        Svr-->>UI: {"status":"success", "avatarUrl":"data:image/png;base64,..."}
        UI->>UI: decodeAvatarDataUrl() → Image → ImageView
    else No avatar
        Svr-->>UI: {"status":"success", "avatarUrl":null}
        UI->>UI: createDefaultAvatarImage()
    end
```

---

## Avatar Modal (`AvatarModalView.java`)

### Features
| Feature | Description |
|---|---|
| Circular Preview | 500×500 pixel circle with clip |
| Zoom Slider | 1× to 3× magnification |
| Drag to Position | Click and drag within crop area |
| Gallery | Previously uploaded avatars (local cache) |
| File Upload | Native file chooser for new images |
| Cancel/Save | Preview updates in real-time |

### Layout
```
┌──────────────────────────────────────┐
│         Choose Avatar                │
├──────────────────────────────────────┤
│                                      │
│        ┌──────────────────┐          │
│        │                  │          │
│        │  500×500 Circle  │          │
│        │  Crop Preview    │          │
│        │                  │          │
│        └──────────────────┘          │
│                                      │
│   Zoom: [======|============] 3×     │
│                                      │
│   Previously Used:                   │
│   [img1] [img2] [img3]              │
│                                      │
│   [Choose Photo]  [Cancel]  [Save]  │
└──────────────────────────────────────┘
```

---

## Real-Time Broadcast

When avatar changes, `PresenceService.broadcastAvatarChangeToPeers()` sends `USER_AVATAR_CHANGED_EVENT` to all friends and conversation peers. The receiving client updates:
- Contact list avatar
- Chat header avatar  
- Existing message bubble avatars
- Profile panel avatar

---

## TCP Protocol

### Change Avatar
```json
// Request
{"action": "CHANGE_AVATAR", "userId": 12, "avatarUrl": "data:image/png;base64,iVBORw0KGgo...", "requestId": "uuid"}

// Response
{"action": "CHANGE_AVATAR_RESPONSE", "status": "success", "message": "Avatar updated", "avatarUrl": "db:12"}

// Broadcast
{"action": "USER_AVATAR_CHANGED_EVENT", "userId": 12, "avatarUrl": "db:12"}
```

### Get Avatar
```json
// Request
{"action": "GET_AVATAR", "userId": 12, "requestId": "uuid"}

// Response
{"action": "GET_AVATAR_RESPONSE", "status": "success", "avatarUrl": "data:image/png;base64,..."}
```

---

## Notable Design Decisions

| Decision | Rationale |
|---|---|
| Server-side resize to 512×512 | Consistent size; no client-side variation |
| BLOB storage in MySQL | Self-contained; no external file server |
| Base64 transport over JSON | Works with JSON line protocol; no binary framing needed |
| `ON DUPLICATE KEY UPDATE` | Simple upsert; one row per user |
| Broadcast avatar change | Immediate UI update for all viewers |
| Client crop before upload | Reduces bandwidth; server only processes final image |
| Default avatar with initials | Professional fallback without external dependencies |
