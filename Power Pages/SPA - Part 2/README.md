# React + TypeScript + Vite

This template provides a minimal setup to get React working in Vite with HMR and some ESLint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Babel](https://babeljs.io/) (or [oxc](https://oxc.rs) when used in [rolldown-vite](https://vite.dev/guide/rolldown)) for Fast Refresh
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/) for Fast Refresh

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the ESLint configuration

If you are developing a production application, we recommend updating the configuration to enable type-aware lint rules:

# Power Pages SPA - Part 2: Adding Authentication to the Project

This project builds upon Part 1 by adding comprehensive authentication features to your Power Pages SPA. Learn how to implement secure user authentication, session management, and integration with Power Platform identity services.

## 🎯 What You'll Learn

- How to implement authentication in a Power Pages SPA
- Integration with Microsoft Entra ID (Azure AD)
- User session management and persistence
- Protected routes and authorization patterns
- Power Platform identity integration
- Security best practices for SPAs

## 🚀 Tech Stack

- **React 19** - Modern React with latest features
- **TypeScript** - Type-safe development
- **Vite** - Fast build tool and dev server
- **React Router DOM** - Client-side routing with protected routes
- **Microsoft Authentication Library (MSAL)** - Authentication integration
- **Power Platform APIs** - Backend integration

## 🔐 Authentication Features

### Implemented Features

- ✅ User login/logout flows
- ✅ Session persistence
- ✅ Protected route components
- ✅ User profile management
- ✅ Token refresh handling
- ✅ Role-based access control

### Security Features

- 🔒 JWT token validation
- 🔒 Secure token storage
- 🔒 CSRF protection
- 🔒 Session timeout handling
- 🔒 Proper logout cleanup

## 📋 Prerequisites

- Completed **Part 1** of the Power Pages SPA series
- Power Apps environment with Power Pages enabled
- Microsoft Entra ID tenant access
- App registration in Azure portal
- Basic understanding of OAuth 2.0 and JWT tokens

## 🛠️ Getting Started

### 1. Environment Setup

Create a `.env` file based on `.env.example`:

```bash
cp .env.example .env
```

Configure your environment variables:

```env
VITE_CLIENT_ID=your-azure-app-client-id
VITE_TENANT_ID=your-azure-tenant-id
VITE_REDIRECT_URI=http://localhost:5173
VITE_API_BASE_URL=https://your-powerpages-site.com/api
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Start Development Server

```bash
npm run dev
```

## 🏗️ Project Structure

```
├── src/
│   ├── components/
│   │   ├── auth/           # Authentication components
│   │   ├── common/         # Shared components
│   │   └── protected/      # Protected route components
│   ├── hooks/
│   │   ├── useAuth.ts      # Authentication hook
│   │   └── useApi.ts       # API integration hook
│   ├── services/
│   │   ├── authService.ts  # Authentication service
│   │   └── apiService.ts   # API communication
│   ├── types/
│   │   └── auth.ts         # Authentication type definitions
│   ├── utils/
│   │   ├── tokenManager.ts # Token management utilities
│   │   └── apiHelpers.ts   # API helper functions
│   └── contexts/
│       └── AuthContext.tsx # Authentication context
├── .env.example            # Environment template
└── .env                   # Your environment variables
```

## 🔧 Authentication Configuration

### 1. Azure App Registration

1. Navigate to Azure Portal → App Registrations
2. Create a new registration or use existing
3. Configure redirect URIs for your environment
4. Set up API permissions for Power Platform

### 2. Power Pages Configuration

1. Enable authentication in your Power Pages site
2. Configure identity providers
3. Set up proper CORS policies
4. Configure API endpoints for your SPA

### 3. MSAL Configuration

```typescript
// src/config/authConfig.ts
export const msalConfig = {
  auth: {
    clientId: import.meta.env.VITE_CLIENT_ID,
    authority: `https://login.microsoftonline.com/${
      import.meta.env.VITE_TENANT_ID
    }`,
    redirectUri: import.meta.env.VITE_REDIRECT_URI,
  },
  cache: {
    cacheLocation: "sessionStorage",
    storeAuthStateInCookie: false,
  },
};
```

## 🛡️ Authentication Flow

### Login Process

1. User clicks login button
2. Redirect to Microsoft login page
3. User authenticates with credentials
4. Receive authorization code
5. Exchange code for access token
6. Store tokens securely
7. Redirect to protected area

### Token Management

- Automatic token refresh before expiration
- Secure storage using browser APIs
- Proper cleanup on logout
- Error handling for expired tokens

### Protected Routes

```typescript
// Example protected route setup
<Route
  path="/dashboard"
  element={
    <ProtectedRoute>
      <Dashboard />
    </ProtectedRoute>
  }
/>
```

## 🔑 Available Scripts

| Script            | Description                                  |
| ----------------- | -------------------------------------------- |
| `npm run dev`     | Start development server with authentication |
| `npm run build`   | Build production-ready authenticated app     |
| `npm run lint`    | Run ESLint with authentication rules         |
| `npm run preview` | Preview production build with auth           |

## 🔐 Security Best Practices

### Token Security

- Store tokens in httpOnly cookies when possible
- Use secure flag for production
- Implement proper token rotation
- Never expose tokens in URLs or logs

### API Security

- Validate tokens on every API call
- Implement proper CORS policies
- Use HTTPS only in production
- Sanitize all user inputs

### Session Management

- Implement session timeout
- Provide clear logout functionality
- Handle concurrent sessions properly
- Monitor for suspicious activity

## 🚧 Common Issues & Solutions

### Authentication Issues

```bash
# Clear browser storage if facing token issues
localStorage.clear();
sessionStorage.clear();
```

### CORS Issues

- Verify Power Pages CORS settings
- Check Azure app registration configurations
- Ensure proper redirect URI setup

### Token Refresh Problems

- Implement proper error boundaries
- Handle network failures gracefully
- Provide fallback authentication flows

## 🔧 Environment Variables

| Variable            | Description              | Example                                     |
| ------------------- | ------------------------ | ------------------------------------------- |
| `VITE_CLIENT_ID`    | Azure app client ID      | `12345678-1234-1234-1234-123456789012`      |
| `VITE_TENANT_ID`    | Azure tenant ID          | `87654321-4321-4321-4321-210987654321`      |
| `VITE_REDIRECT_URI` | OAuth redirect URI       | `http://localhost:5173`                     |
| `VITE_API_BASE_URL` | Power Pages API base URL | `https://yoursite.powerappsportals.com/api` |

## 🧪 Testing Authentication

### Unit Tests

- Test authentication hooks
- Mock MSAL responses
- Verify token handling logic
- Test protected route behavior

### Integration Tests

- End-to-end login flows
- API integration with authentication
- Token refresh scenarios
- Logout cleanup verification

## 📚 Additional Resources

- [MSAL.js Documentation](https://docs.microsoft.com/azure/active-directory/develop/msal-js-initializing-client-applications)
- [Power Pages Authentication](https://docs.microsoft.com/power-pages/security/authentication/)
- [React Authentication Patterns](https://reactjs.org/docs/context.html)
- [OAuth 2.0 Security Best Practices](https://tools.ietf.org/html/rfc6749)

## 🚀 Deployment Considerations

### Production Setup

1. Update environment variables for production
2. Configure proper redirect URIs
3. Enable HTTPS enforcement
4. Set up monitoring and logging
5. Implement proper error boundaries

### Power Pages Integration

1. Upload authenticated SPA build
2. Configure authentication providers
3. Set up API endpoints with proper authentication
4. Test all authentication flows in production

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch for authentication features
3. Implement with proper testing
4. Update documentation
5. Submit a pull request with security review

## 📄 License

This project is part of the Power Platform learning series and is available for educational purposes. Please ensure compliance with your organization's security policies when implementing authentication features.

You can also install [eslint-plugin-react-x](https://github.com/Rel1cx/eslint-react/tree/main/packages/plugins/eslint-plugin-react-x) and [eslint-plugin-react-dom](https://github.com/Rel1cx/eslint-react/tree/main/packages/plugins/eslint-plugin-react-dom) for React-specific lint rules:

```js
// eslint.config.js
import reactX from "eslint-plugin-react-x";
import reactDom from "eslint-plugin-react-dom";

export default defineConfig([
  globalIgnores(["dist"]),
  {
    files: ["**/*.{ts,tsx}"],
    extends: [
      // Other configs...
      // Enable lint rules for React
      reactX.configs["recommended-typescript"],
      // Enable lint rules for React DOM
      reactDom.configs.recommended,
    ],
    languageOptions: {
      parserOptions: {
        project: ["./tsconfig.node.json", "./tsconfig.app.json"],
        tsconfigRootDir: import.meta.dirname,
      },
      // other options...
    },
  },
]);
```
