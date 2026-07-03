# Change Password TCP Implementation Notes

This document records the implementation details for the **Change Password** feature in the user profile. This is distinct from the pre-existing **Forgot Password** feature.

## 1. Feature Purpose

This feature is for **already authenticated** users who want to change their password from the profile screen.

Flow:

```text
Logged-in user
 → opens profile
 → clicks "Change Password"
 → enters current password
 → enters new password
 → confirms new password
 → client sends CHANGE_PASSWORD action via TCP
 → server verifies current password
 → if correct, hashes new password and updates database
```

Key point: this feature does **NOT** reuse the `FORGOT_PASSWORD` flow, which uses a reset code.

## 2. Distinction From Forgot Password

### Forgot Password
User does not need to be logged in. User enters username, server generates a reset code, then user enters code + new password.

TCP Action: `FORGOT_PASSWORD`

### Change Password
User must be logged in. User must enter current password. Server only changes password if current password is correct.

TCP Action: `CHANGE_PASSWORD`

## 3. TCP Flow

```text
ChatView
 → ChangePasswordDialog (modal)
 → ChatController.changePassword(oldPassword, newPassword, onSuccess, onError)
 → ChatService.changePassword(userId, oldPassword, newPassword)
 → JSON action CHANGE_PASSWORD
 → TCP socket
 → ClientConnection
 → Router
 → ChangePasswordHandler
 → AuthService.changePassword(...)
 → UserRepository.updatePasswordById(...)
 → MySQL users.password_hash
```

## 4. Client Files

### 4.1. `ChangePasswordDialog.java`

File: `Code/Client/src/main/java/com/client/view/ChangePasswordDialog.java`

A dedicated modal dialog class with:
- Current password field
- New password field
- Confirm password field
- Cancel button
- Save button
- Error/success message label

Client-side validation:
1. No field can be empty
2. New password must be at least 6 characters
3. New password must differ from current password
4. New password and confirm password must match
5. Client must be connected to server via TCP

If valid, calls:
```java
chatController.changePassword(oldPassword, newPassword, onSuccess, onError)
```

### 4.2. `ChatController.java`

File: `Code/Client/src/main/java/com/client/controller/ChatController.java`

Method:
```java
public void changePassword(String oldPassword, String newPassword,
                           Consumer<String> onSuccess, Consumer<String> onError)
```

Runs on background thread via `CompletableFuture`, calls `chatService.changePassword()`. Callbacks dispatch to JavaFX thread via `Platform.runLater()`.

### 4.3. `ChatService.java`

File: `Code/Client/src/main/java/com/client/service/ChatService.java`

Method:
```java
public ApiResponse changePassword(long userId, String oldPassword, String newPassword)
```

Creates JSON request:
```json
{
  "action": "CHANGE_PASSWORD",
  "userId": 1,
  "oldPassword": "old_password",
  "newPassword": "new_password",
  "requestId": "..."
}
```

Sends via `sendRequestSync`. No HTTP endpoint — pure TCP socket.

## 5. File Server Đã Thêm Và Sửa

### 5.1. `ChangePasswordHandler.java`

File mới:

```text
Code/Server/src/main/java/com/server/handler/auth/ChangePasswordHandler.java
```

Handler này nhận request TCP từ `Router`.

Nó kiểm tra các trường bắt buộc:

```text
userId
oldPassword
newPassword
```

Các bước xử lý:

1. Nếu thiếu field thì trả lỗi.
2. Nếu `userId <= 0` hoặc mật khẩu bị rỗng thì trả lỗi.
3. Nếu mật khẩu mới ngắn hơn 6 ký tự thì trả lỗi.
4. Nếu connection đã có `userId`, handler kiểm tra user trong connection có khớp với `userId` request không.
5. Gọi `AuthService.changePassword(...)`.
6. Trả kết quả về client.

Lý do kiểm tra `connectionUserId`:

```text
Nếu một client đã JOIN với user A nhưng lại gửi request đổi mật khẩu cho user B,
server sẽ từ chối để tránh đổi nhầm tài khoản.
```

Handler không log mật khẩu cũ hoặc mật khẩu mới. Log chỉ ghi `userId` và trạng thái thành công/thất bại.

### 5.2. `Router.java`

File:

```text
Code/Server/src/main/java/com/server/tcp/Router.java
```

Mình thêm handler:

```java
private static ChangePasswordHandler changePasswordHandler = new ChangePasswordHandler();
```

Và thêm case mới:

```java
case "CHANGE_PASSWORD":
    response = changePasswordHandler.handleTcp(request, conn);
    break;
```

Như vậy server đã biết khi nhận action `CHANGE_PASSWORD` thì phải chuyển request sang `ChangePasswordHandler`.

### 5.3. `AuthService.java`

File:

```text
Code/Server/src/main/java/com/server/service/AuthService.java
```

Mình thêm enum kết quả:

```java
public enum ChangePasswordResult {
    SUCCESS,
    USER_NOT_FOUND,
    WRONG_OLD_PASSWORD,
    UPDATE_FAILED
}
```

Và thêm hàm:

```java
public ChangePasswordResult changePassword(long userId, String oldPassword, String newPassword)
```

Logic:

1. Tìm user theo `userId`.
2. Nếu không có user thì trả `USER_NOT_FOUND`.
3. Dùng BCrypt kiểm tra mật khẩu hiện tại:

```java
BCrypt.checkpw(oldPassword, user.getPasswordHash())
```

4. Nếu mật khẩu cũ sai thì trả `WRONG_OLD_PASSWORD`.
5. Nếu đúng, hash mật khẩu mới:

```java
BCrypt.hashpw(newPassword, BCrypt.gensalt())
```

6. Cập nhật database bằng `UserRepository.updatePasswordById`.
7. Nếu update thành công thì trả `SUCCESS`, nếu không thì trả `UPDATE_FAILED`.

### 5.4. `UserRepository.java`

File:

```text
Code/Server/src/main/java/com/server/repository/UserRepository.java
```

Mình thêm hàm:

```java
public boolean updatePasswordById(long userId, String newPasswordHash)
```

Hàm này update trực tiếp cột `password_hash` theo `id`:

```sql
UPDATE users SET password_hash = ? WHERE id = ?
```

Lý do dùng `userId`:

```text
Người dùng đang đăng nhập đã có currentUserId ở client.
Đổi mật khẩu theo userId rõ ràng hơn, không cần gửi username qua lại.
```

## 6. Response Server Trả Về

Nếu đổi mật khẩu thành công:

```json
{
  "action": "CHANGE_PASSWORD_RESPONSE",
  "status": "success",
  "message": "Password changed successfully",
  "requestId": "..."
}
```

Nếu mật khẩu hiện tại sai:

```json
{
  "action": "CHANGE_PASSWORD_RESPONSE",
  "status": "error",
  "message": "Current password is incorrect",
  "requestId": "..."
}
```

Nếu request thiếu field:

```json
{
  "status": "error",
  "message": "Missing required fields"
}
```

Nếu user không hợp lệ:

```json
{
  "status": "error",
  "message": "User not found"
}
```

## 7. UI Hiển Thị Lỗi Như Thế Nào?

Server trả message tiếng Anh để thống nhất với các handler hiện tại.

Phía UI map lại một số lỗi sang tiếng Việt:

```java
case "Current password is incorrect" -> "Mật khẩu hiện tại không đúng.";
case "New password must be at least 6 characters" -> "Mật khẩu mới phải có ít nhất 6 ký tự.";
case "User not found" -> "Không tìm thấy tài khoản.";
case "Unauthorized password change request" -> "Phiên đăng nhập không hợp lệ.";
```

Nếu đổi thành công, UI hiển thị:

```text
Đổi mật khẩu thành công.
```

## 8. Vì Sao Không Dùng Lại `FORGOT_PASSWORD`?

Không dùng lại `FORGOT_PASSWORD` vì hai luồng có mục đích khác nhau:

| Chức năng | Dùng khi nào? | Cần mật khẩu cũ? | Cần code? |
|---|---|---|---|
| Quên mật khẩu | Chưa đăng nhập hoặc quên mật khẩu | Không | Có |
| Đổi mật khẩu | Đã đăng nhập trong profile | Có | Không |

Nếu dùng chung action `FORGOT_PASSWORD`, code sẽ khó giải thích và dễ bị bắt bẻ vì đổi mật khẩu trong profile không cần mã xác nhận.

Vì vậy action mới `CHANGE_PASSWORD` là rõ ràng hơn.

## 9. Vấn Đề Bảo Mật Đã Xử Lý

Chức năng này đã xử lý các điểm quan trọng:

1. Không gửi mật khẩu qua HTTP endpoint, mà đi theo TCP action của project.
2. Không log mật khẩu cũ hoặc mật khẩu mới.
3. Kiểm tra mật khẩu cũ bằng BCrypt trước khi đổi.
4. Mật khẩu mới được hash bằng BCrypt trước khi lưu database.
5. Không lưu plain text password.
6. Kiểm tra `connectionUserId` để tránh client đổi mật khẩu cho user khác.
7. Validate mật khẩu mới tối thiểu 6 ký tự.

## 10. Các File Đã Đụng Tới

Danh sách file chính:

```text
Code/Client/src/main/java/ChatView.java
Code/Client/src/main/java/ChatTcpClient.java
Code/Server/src/main/java/com/server/handler/auth/ChangePasswordHandler.java
Code/Server/src/main/java/com/server/tcp/Router.java
Code/Server/src/main/java/com/server/service/AuthService.java
Code/Server/src/main/java/com/server/repository/UserRepository.java
```

File tài liệu này:

```text
Docs/10_Change_Password_TCP_Implementation.md
```

## 11. Cách Giải Thích Với Trưởng Nhóm

Có thể nói:

```text
Mình đã triển khai chức năng đổi mật khẩu trong profile theo TCP. UI mở modal nhập mật khẩu cũ, mật khẩu mới và xác nhận mật khẩu mới. Client gửi action CHANGE_PASSWORD qua ChatTcpClient. Server route action này qua Router tới ChangePasswordHandler. Handler gọi AuthService để kiểm tra mật khẩu cũ bằng BCrypt, sau đó hash mật khẩu mới và update password_hash theo userId.
```

## 12. Cách Trả Lời Nếu Giảng Viên Hỏi

Nếu thầy hỏi: "Đổi mật khẩu khác quên mật khẩu ở đâu?"

Trả lời:

```text
Quên mật khẩu dùng code xác nhận và không cần đăng nhập. Đổi mật khẩu là khi user đã đăng nhập, nên phải nhập mật khẩu hiện tại. Server kiểm tra mật khẩu hiện tại đúng thì mới cho đổi.
```

Nếu thầy hỏi: "Action TCP là gì?"

Trả lời:

```text
Action là CHANGE_PASSWORD. Client gửi JSON qua socket, Router đọc action rồi gọi ChangePasswordHandler.
```

Nếu thầy hỏi: "Có lưu mật khẩu plain text không?"

Trả lời:

```text
Không. Server chỉ nhận mật khẩu để kiểm tra, sau đó hash mật khẩu mới bằng BCrypt rồi lưu vào cột password_hash.
```

Nếu thầy hỏi: "Làm sao biết người này được đổi mật khẩu của tài khoản đó?"

Trả lời:

```text
Request có userId, và handler kiểm tra thêm userId trên connection nếu connection đã JOIN. Nếu connection thuộc user khác thì server từ chối.
```

## 13. Kiểm Tra Đã Chạy

Đã compile client:

```powershell
cd Code/Client
mvn -q -DskipTests compile
```

Đã compile server:

```powershell
cd Code/Server
mvn -q -DskipTests compile
```

Cả hai đều compile thành công.
