# Frontend OIDC Integration Guide

This guide explains how to integrate OIDC authentication with the AppTracker API from your frontend application.

## Overview

The AppTracker API uses OpenID Connect (OIDC) for authentication. Your frontend application needs to:

1. Authenticate users with the OIDC provider
2. Obtain an access token
3. Include the token in API requests

## Authentication Flow

```
┌──────────┐     ┌───────────────┐     ┌─────────────┐
│ Frontend │     │ OIDC Provider │     │ AppTracker  │
│   App    │     │  (e.g. SSO)   │     │    API      │
└────┬─────┘     └───────┬───────┘     └──────┬──────┘
     │                   │                    │
     │ 1. Redirect to    │                    │
     │    /authorize     │                    │
     │──────────────────>│                    │
     │                   │                    │
     │ 2. User logs in   │                    │
     │<──────────────────│                    │
     │                   │                    │
     │ 3. Authorization  │                    │
     │    code returned  │                    │
     │<──────────────────│                    │
     │                   │                    │
     │ 4. Exchange code  │                    │
     │    for tokens     │                    │
     │──────────────────>│                    │
     │                   │                    │
     │ 5. Access token   │                    │
     │    received       │                    │
     │<──────────────────│                    │
     │                   │                    │
     │ 6. API request with Bearer token       │
     │────────────────────────────────────────>│
     │                   │                    │
     │ 7. API response   │                    │
     │<────────────────────────────────────────│
```

## Configuration

You'll need the following from your OIDC provider:

| Setting | Description | Example |
|---------|-------------|---------|
| Issuer URL | The OIDC provider's base URL | `https://sso.xnh.app` |
| Client ID | Your application's client ID | `apptracker-frontend` |
| Redirect URI | Where to redirect after login | `https://yourapp.com/callback` |

## Implementation

### 1. Choose an OIDC Library

Use a well-maintained OIDC client library for your framework:

| Framework | Recommended Library |
|-----------|---------------------|
| React | `oidc-client-ts`, `react-oidc-context` |
| Vue | `oidc-client-ts`, `vue-oidc-client` |
| Angular | `angular-auth-oidc-client` |
| Vanilla JS | `oidc-client-ts` |

### 2. Configure the OIDC Client

Example using `oidc-client-ts`:

```typescript
import { UserManager, WebStorageStateStore } from 'oidc-client-ts';

const userManager = new UserManager({
  authority: 'https://sso.xnh.app',        // Your OIDC issuer
  client_id: 'apptracker-frontend',         // Your client ID
  redirect_uri: 'https://yourapp.com/callback',
  post_logout_redirect_uri: 'https://yourapp.com/',
  response_type: 'code',
  scope: 'openid profile email',
  userStore: new WebStorageStateStore({ store: window.localStorage }),
});
```

### 3. Implement Login

```typescript
// Redirect to OIDC provider for login
async function login() {
  await userManager.signinRedirect();
}

// Handle the callback after login
async function handleCallback() {
  const user = await userManager.signinRedirectCallback();
  console.log('Logged in as:', user.profile.name);
  return user;
}
```

### 4. Make Authenticated API Requests

Include the access token in the `Authorization` header:

```typescript
async function callApi(endpoint: string, options: RequestInit = {}) {
  const user = await userManager.getUser();

  if (!user || user.expired) {
    throw new Error('User not authenticated');
  }

  const response = await fetch(`https://api.yourapp.com${endpoint}`, {
    ...options,
    headers: {
      ...options.headers,
      'Authorization': `Bearer ${user.access_token}`,
      'Content-Type': 'application/json',
    },
  });

  if (response.status === 401) {
    // Token expired, redirect to login
    await userManager.signinRedirect();
    return;
  }

  return response.json();
}
```

### 5. Sync User Profile

After login, call the sync endpoint to fetch the user's profile (name, email) from the OIDC provider:

```typescript
async function handleCallback() {
  const user = await userManager.signinRedirectCallback();

  // Sync profile data from OIDC provider to our backend
  await callApi('/designer/me/sync', { method: 'POST' });

  return user;
}
```

This fetches the user's `name` and `email` from the OIDC provider's userinfo endpoint and stores it in the database. You only need to call this once after login (or when you want to refresh the profile).

### 6. Get User Information

There are two ways to get user information:

**Option A: From the ID Token (no API call needed)**

```typescript
const user = await userManager.getUser();
console.log(user.profile.name);   // From ID token
console.log(user.profile.email);  // From ID token
```

**Option B: From the API**

```typescript
const me = await callApi('/designer/me');
console.log(me.name);   // From database (synced via /designer/me/sync)
console.log(me.email);  // From database
```

Use Option A for quick UI display. Use Option B when you need the server's view of the user (e.g., to check `createdAt` or other server-side data).

### 7. Example API Calls

```typescript
// Get current user profile
const me = await callApi('/designer/me');
console.log('Designer:', me);

// Create an icon pack version
const iconPackVersion = await callApi('/icon-pack-version/create', {
  method: 'POST',
  body: JSON.stringify({
    versionString: '1.0.0',
    expireAt: Date.now() + 86400000, // 24 hours from now
  }),
});

// Search for apps
const apps = await callApi('/app-info/search?query=chrome');
```

## Token Handling

### Token Expiration

OIDC tokens have an expiration time. Handle token refresh:

```typescript
// Check if token needs refresh
const user = await userManager.getUser();
if (user && user.expired) {
  // Attempt silent refresh
  try {
    await userManager.signinSilent();
  } catch (error) {
    // Silent refresh failed, redirect to login
    await userManager.signinRedirect();
  }
}
```

### Logout

```typescript
async function logout() {
  await userManager.signoutRedirect();
}
```

## API Endpoints

### Protected Endpoints (require authentication)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/designer/me` | Get current user profile |
| POST | `/designer/me/sync` | Sync profile from OIDC provider |
| POST | `/icon-pack-version/create` | Create a new icon pack version |
| GET | `/icon-pack-version/:id/requests` | Get requests for an icon pack |
| DELETE | `/request-record/:id` | Delete a request record |

### Public Endpoints (no authentication required)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/app-info/search` | Search for app information |

## Error Handling

The API returns standard HTTP status codes:

| Status | Meaning |
|--------|---------|
| 200 | Success |
| 401 | Unauthorized - invalid or expired token |
| 403 | Forbidden - you don't have permission |
| 404 | Not found |

Example error handling:

```typescript
async function callApi(endpoint: string, options: RequestInit = {}) {
  const user = await userManager.getUser();

  if (!user || user.expired) {
    await userManager.signinRedirect();
    return;
  }

  const response = await fetch(`https://api.yourapp.com${endpoint}`, {
    ...options,
    headers: {
      ...options.headers,
      'Authorization': `Bearer ${user.access_token}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    switch (response.status) {
      case 401:
        // Try silent refresh first
        try {
          await userManager.signinSilent();
          // Retry the request
          return callApi(endpoint, options);
        } catch {
          await userManager.signinRedirect();
        }
        break;
      case 403:
        throw new Error('You do not have permission to perform this action');
      case 404:
        throw new Error('Resource not found');
      default:
        throw new Error(`API error: ${response.status}`);
    }
  }

  return response.json();
}
```

## Security Considerations

1. **Always use HTTPS** in production
2. **Never store tokens in localStorage** if XSS is a concern - consider using secure cookies or in-memory storage
3. **Validate the `iss` claim** matches your expected issuer
4. **Use short-lived access tokens** with refresh tokens for better security

## Troubleshooting

### "401 Unauthorized" on all requests

- Check that the access token is being sent in the `Authorization` header
- Verify the token hasn't expired
- Ensure the `OIDC_AUDIENCE` on the server matches your client ID

### "Invalid token audience" error

- The `aud` claim in your token must contain the client ID configured on the server (`OIDC_AUDIENCE`)
- Check your OIDC provider's configuration for the audience/resource setting

### Token refresh fails silently

- Ensure your OIDC provider supports silent refresh
- Check that your redirect URI is correctly configured
- Some browsers block third-party cookies which can break silent refresh
