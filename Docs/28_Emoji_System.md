# 😊 Emoji System

## Overview
SinChat features a WeChat-style emoji system. Emojis are defined in a JSON file and rendered differently based on context: solo emojis display as large animated GIFs, while inline emojis display as small static PNGs.

---

## Source Files

| Layer | File | Package |
|---|---|---|
| **Client Manager** | `EmojiManager.java` (Singleton) | `com.client.emoji` |
| **Client Model** | `EmojiDef.java` | `com.client.emoji` |
| **Client View** | `ChatView.java` (emoji picker, rendering) | `com.client.view` |
| **Resource** | `emoji_list.json` | `src/main/resources/emojis/` |
| **Resource** | `animated/*.gif` | `src/main/resources/emojis/animated/` |
| **Resource** | `static/*.png` | `src/main/resources/emojis/static/` |

---

## Emoji Definition (`emoji_list.json`)

```json
[
  {
    "code": ":smile:",
    "label": "smile",
    "desc": "Smiling face",
    "fileName": "smile",
    "gifNum": 30
  },
  {
    "code": ":heart:",
    "label": "heart",
    "desc": "Red heart",
    "fileName": "heart",
    "gifNum": 28
  }
]
```

| Field | Description |
|---|---|
| `code` | Text code used in messages (e.g., `:smile:`) |
| `label` | Unique identifier |
| `desc` | Human-readable description |
| `fileName` | Base filename for image files |
| `gifNum` | Number of frames in animated GIF (for timing) |

---

## Rendering Rules (WeChat-Style)

The `EmojiManager.renderMessageContent(String content)` method applies these rules:

```
Input: ":smile:"
→ 1 emoji, no text
→ Large animated GIF (120×120 pixels)

Input: ":smile: :heart:"
→ 2+ emojis, no text
→ Small static PNG inline (28×28 pixels)

Input: "Hello :smile:"
→ Text + emoji(s)
→ Text with small static PNG inline (28×28 pixels)

Input: "Hello world"
→ Text only, no emojis
→ Plain Label
```

---

## Rendering Flow

```mermaid
flowchart TD
    A[Message Content String] --> B{Parse emoji codes}
    B --> C{How many emojis?}
    C -->|1 emoji, no text| D[Create large animated GIF<br/>120×120 pixels]
    C -->|2+ emojis, no text| E[Create HBox with small PNGs<br/>28×28 pixels each]
    C -->|Text + emoji(s)| F[Create TextFlow<br/>Text nodes + small PNG ImageViews<br/>28×28 pixels each]
    C -->|No emojis| G[Create plain Label]
```

---

## Implementation (`EmojiManager.java`)

### Initialization
```java
// Load emoji definitions from resources
InputStream is = getClass().getResourceAsStream("/emojis/emoji_list.json");
EmojiDef[] defs = gson.fromJson(new InputStreamReader(is), EmojiDef[].class);
emojiMap = defs.stream().collect(Collectors.toMap(EmojiDef::getLabel, e -> e));
```

### Content Parsing
The message content is parsed for emoji codes (format: `:label:`). Non-emoji text segments and emoji segments are identified and rendered separately.

### Animated GIF Loading
```java
public Node buildLargeEmojiNode(String label) {
    EmojiDef def = emojiMap.get(label);
    String path = "/emojis/animated/" + def.getFileName() + ".gif";
    Image image = new Image(getClass().getResourceAsStream(path), 120, 120, true, true);
    return new ImageView(image);
}
```

### Static PNG Loading
```java
// For inline rendering
String path = "/emojis/static/" + def.getFileName() + ".png";
Image image = new Image(getClass().getResourceAsStream(path), 28, 28, true, true);
ImageView iv = new ImageView(image);
```

---

## Emoji Picker UI

The `ChatView` includes an emoji picker:
- **Button**: Smiley face icon next to message input
- **Popup**: Grid of emoji buttons (6 columns)
- **Click**: Inserts emoji code (e.g., `:smile:`) at cursor position in input field
- **Hover**: Shows emoji label tooltip

---

## Client-Side Rendering Pipeline

```
User sends message with ":smile: Hello :heart:"
    ↓
Server stores raw text with emoji codes
    ↓
Server broadcasts raw text
    ↓
Receiver client: EmojiManager.renderMessageContent(content)
    ↓
Parses content → identifies emoji segments + text segments
    ↓
Rule: text + emojis → TextFlow with small inline PNGs
    ↓
Renders: [😊 PNG 28×28] [Hello text] [❤️ PNG 28×28]
```

---

## File Organization

```
src/main/resources/emojis/
├── emoji_list.json          # Emoji definitions (code, label, fileName, gifNum)
├── animated/                # Animated GIFs for solo display
│   ├── smile.gif
│   ├── heart.gif
│   ├── cry.gif
│   └── ...
└── static/                  # Static PNGs for inline display
    ├── smile.png
    ├── heart.png
    ├── cry.png
    └── ...
```

---

## Notable Design Decisions

| Decision | Rationale |
|---|---|
| Emoji codes in message text (`:smile:`) | Standard format; human-readable; no special binary encoding |
| Separate animated/static files | Animated GIFs are larger; only loaded for solo display |
| 120×120 for solo vs 28×28 for inline | Solo is a visual statement; inline matches text size |
| Text-only → plain Label | Avoids unnecessary TextFlow overhead |
| Emoji definitions in JSON | Easy to add/modify emojis without code changes |
| Singleton EmojiManager | Single load point; shared across all chat views |
| Emojis stored as codes in DB | Minimal storage; rendering happens client-side |
