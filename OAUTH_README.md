# OAuth 三方登录功能

## 📋 功能概述

实现了 Apple、Google、GitHub 三种第三方登录方式，并特别处理了 Apple 匿名邮箱的去重问题，防止用户通过匿名邮箱无限注册新账号。

## 🔑 核心技术

### 1. Apple 登录（Sign in with Apple）

**关键特性：**
- ✅ 使用 `AuthenticationServices` 框架
- ✅ 支持匿名邮箱（`@privaterelay.appleid.com`）
- ✅ **通过 `userIdentifier` 识别同一用户**（防止无限注册）
- ✅ 安全验证：使用 nonce 和 SHA256

**匿名邮箱去重方案：**

Apple 提供的 `userIdentifier` 是固定的唯一标识符，即使用户使用匿名邮箱，同一 Apple ID 的 `userIdentifier` 始终相同。

```swift
// Apple 登录凭证
struct AppleLoginCredential {
    let userIdentifier: String  // 🔑 关键：用于识别同一用户
    let email: String?  // 可能是匿名邮箱
    let identityToken: String  // JWT Token
}

// 判断是否是匿名邮箱
var isPrivateEmail: Bool {
    return email?.contains("@privaterelay.appleid.com") ?? false
}
```

**后端处理逻辑：**

1. **首次登录**：
   - 用户使用 Apple 登录，可能提供匿名邮箱
   - 后端根据 `userIdentifier` 创建账号
   - 存储 `userIdentifier` 作为唯一标识

2. **再次登录**：
   - 用户使用同一 Apple ID 登录
   - `userIdentifier` 相同，后端识别为同一用户
   - **即使邮箱变化（或使用新的匿名邮箱），仍然是同一账号**

3. **防止无限注册**：
   - 用户尝试用新的匿名邮箱注册
   - 后端检查 `userIdentifier`，发现已存在
   - **更新邮箱而不是创建新账号**

```sql
-- 数据库表结构建议
CREATE TABLE users (
    id BIGINT PRIMARY KEY,
    email VARCHAR(255),
    apple_user_identifier VARCHAR(255) UNIQUE,  -- 关键字段
    google_user_id VARCHAR(255) UNIQUE,
    github_user_id VARCHAR(255) UNIQUE,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- 查询逻辑
-- 1. 先根据 userIdentifier 查找用户
SELECT * FROM users WHERE apple_user_identifier = ?;

-- 2. 如果找到，更新邮箱（如果变化）
UPDATE users SET email = ?, updated_at = NOW()
WHERE apple_user_identifier = ?;

-- 3. 如果未找到，创建新用户
INSERT INTO users (apple_user_identifier, email, created_at)
VALUES (?, ?, NOW());
```

### 2. Google 登录

**关键特性：**
- ✅ 使用 OAuth 2.0 授权码流程
- ✅ 通过 `ASWebAuthenticationSession` 实现
- ✅ 前端获取授权码，后端换取 Access Token

**流程：**
1. 前端构建 Google OAuth URL
2. 用户在 Google 页面授权
3. 回调返回授权码（`authorization_code`）
4. 前端将授权码发送给后端
5. 后端使用授权码换取 Access Token 和用户信息

### 3. GitHub 登录

**关键特性：**
- ✅ 使用 OAuth 2.0 授权码流程
- ✅ 通过 `ASWebAuthenticationSession` 实现
- ✅ 流程与 Google 类似

## 📂 文件结构

```
SFI/OAuth/
├── AppleSignInManager.swift      # Apple 登录管理器
├── GoogleSignInManager.swift     # Google 登录管理器
├── GitHubSignInManager.swift     # GitHub 登录管理器
└── OAuthManager.swift             # 统一的 OAuth 管理器

SFI/LoginView.swift                # 登录页面（已集成三方登录）
SFT/AQAPIService.swift             # API 服务（已添加三方登录接口）
```

## 🚀 使用方法

### 前端集成（已完成）

```swift
// LoginView.swift 中已集成
@StateObject private var oauthManager = OAuthManager(
    googleClientID: "YOUR_GOOGLE_CLIENT_ID",
    githubClientID: "YOUR_GITHUB_CLIENT_ID"
)

// Apple 登录
oauthManager.signInWithApple()

// Google 登录
oauthManager.signInWithGoogle()

// GitHub 登录
oauthManager.signInWithGitHub()
```

### 后端 API 接口

#### 1. Apple 登录

**接口：** `POST /api/v1/passport/auth/apple`

**请求参数：**
```json
{
  "identity_token": "eyJraWQiOiJXNldjT0tCIiwiYWxn...",
  "user_identifier": "001234.abcd1234efgh5678ijkl.9012",
  "email": "abc@privaterelay.appleid.com",  // 可选，可能是匿名邮箱
  "full_name": "张三"  // 可选，仅首次登录提供
}
```

**响应：**
```json
{
  "code": 200,
  "data": {
    "auth_data": "user_auth_data_string",
    "token": "jwt_token_here",
    "is_admin": false
  }
}
```

**后端处理步骤：**

1. **验证 Identity Token**（重要！）
   ```python
   # 伪代码
   from jwt import decode
   from cryptography.hazmat.primitives import serialization

   # 从 Apple 获取公钥
   apple_public_key = fetch_apple_public_key()

   # 验证 JWT
   try:
       payload = decode(
           identity_token,
           apple_public_key,
           algorithms=['RS256'],
           audience='YOUR_APP_BUNDLE_ID'
       )
       user_identifier = payload['sub']  # 用户唯一标识
   except:
       return {"code": 401, "message": "Invalid token"}
   ```

2. **查找或创建用户**
   ```python
   # 根据 user_identifier 查找用户
   user = db.query(User).filter_by(
       apple_user_identifier=user_identifier
   ).first()

   if user:
       # 用户已存在，更新邮箱（如果变化）
       if email and user.email != email:
           user.email = email
           user.updated_at = datetime.now()
           db.commit()
   else:
       # 创建新用户
       user = User(
           apple_user_identifier=user_identifier,
           email=email,
           full_name=full_name,
           created_at=datetime.now()
       )
       db.add(user)
       db.commit()

   # 生成 token 并返回
   auth_token = generate_jwt_token(user.id)
   return {
       "code": 200,
       "data": {
           "auth_data": user.id,
           "token": auth_token,
           "is_admin": user.is_admin
       }
   }
   ```

#### 2. Google 登录

**接口：** `POST /api/v1/passport/auth/google`

**请求参数：**
```json
{
  "authorization_code": "4/0AY0e-g7X..."
}
```

**后端处理步骤：**

1. **换取 Access Token**
   ```python
   import requests

   response = requests.post('https://oauth2.googleapis.com/token', data={
       'code': authorization_code,
       'client_id': GOOGLE_CLIENT_ID,
       'client_secret': GOOGLE_CLIENT_SECRET,
       'redirect_uri': REDIRECT_URI,
       'grant_type': 'authorization_code'
   })

   access_token = response.json()['access_token']
   ```

2. **获取用户信息**
   ```python
   user_info = requests.get(
       'https://www.googleapis.com/oauth2/v2/userinfo',
       headers={'Authorization': f'Bearer {access_token}'}
   ).json()

   google_user_id = user_info['id']
   email = user_info['email']
   name = user_info['name']
   ```

3. **创建或登录用户**（类似 Apple 登录）

#### 3. GitHub 登录

**接口：** `POST /api/v1/passport/auth/github`

**请求参数：**
```json
{
  "authorization_code": "abc123def456"
}
```

**后端处理步骤：**

1. **换取 Access Token**
   ```python
   response = requests.post('https://github.com/login/oauth/access_token', data={
       'client_id': GITHUB_CLIENT_ID,
       'client_secret': GITHUB_CLIENT_SECRET,
       'code': authorization_code
   }, headers={'Accept': 'application/json'})

   access_token = response.json()['access_token']
   ```

2. **获取用户信息**
   ```python
   user_info = requests.get(
       'https://api.github.com/user',
       headers={'Authorization': f'Bearer {access_token}'}
   ).json()

   github_user_id = user_info['id']
   email = user_info['email']  # 可能为空
   ```

## ⚠️ 重要注意事项

### 1. Apple 登录配置

在 Xcode 项目中：
1. 添加 `Sign in with Apple` capability
2. 配置 App ID 和 Identifiers

在 Apple Developer：
1. 启用 Sign in with Apple
2. 配置 Return URLs

### 2. Google 登录配置

1. 在 Google Cloud Console 创建 OAuth 2.0 客户端 ID
2. 配置重定向 URI：`com.googleusercontent.apps.YOUR_CLIENT_ID:/oauth2redirect`
3. 修改 `GoogleSignInManager` 中的 `clientID`

### 3. GitHub 登录配置

1. 在 GitHub Settings > Developer settings 创建 OAuth App
2. 配置 Callback URL：`your-app-scheme://oauth/callback`
3. 修改 `GitHubSignInManager` 中的 `clientID`

### 4. 安全性建议

- ✅ 后端必须验证 Apple Identity Token
- ✅ 不要在前端存储 client_secret
- ✅ 使用 HTTPS 传输敏感信息
- ✅ 实现请求频率限制，防止暴力攻击

## 📊 数据库设计建议

```sql
CREATE TABLE users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(255),
    password_hash VARCHAR(255),  -- 传统登录用

    -- 三方登录标识符
    apple_user_identifier VARCHAR(255) UNIQUE,
    google_user_id VARCHAR(255) UNIQUE,
    github_user_id VARCHAR(255) UNIQUE,

    -- 用户信息
    full_name VARCHAR(100),
    avatar_url VARCHAR(500),

    -- 账号状态
    is_admin BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,

    -- 时间戳
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- 索引
    INDEX idx_email (email),
    INDEX idx_apple_id (apple_user_identifier),
    INDEX idx_google_id (google_user_id),
    INDEX idx_github_id (github_user_id)
);
```

## 🧪 测试清单

- [ ] Apple 登录 - 正常流程
- [ ] Apple 登录 - 使用匿名邮箱
- [ ] Apple 登录 - 同一用户第二次登录（验证不会创建新账号）
- [ ] Apple 登录 - 用户更换匿名邮箱（验证邮箱更新）
- [ ] Apple 登录 - 用户取消授权
- [ ] Google 登录 - 正常流程
- [ ] Google 登录 - 用户取消授权
- [ ] GitHub 登录 - 正常流程
- [ ] GitHub 登录 - 用户取消授权
- [ ] 网络异常处理
- [ ] Token 过期处理

## 📚 参考资料

- [Apple Sign in with Apple 文档](https://developer.apple.com/documentation/sign_in_with_apple)
- [Google OAuth 2.0 文档](https://developers.google.com/identity/protocols/oauth2)
- [GitHub OAuth 文档](https://docs.github.com/en/developers/apps/building-oauth-apps)

---

创建时间：2025-10-01
分支：feature/oauth-login
