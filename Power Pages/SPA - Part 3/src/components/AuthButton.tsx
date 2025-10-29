import './AuthButton.css';

// SVG icons for login/logout
const LoginIcon = () => (
  <svg
    width="20"
    height="20"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    strokeLinejoin="round"
  >
    <path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4" />
    <polyline points="10,17 15,12 10,7" />
    <line x1="15" y1="12" x2="3" y2="12" />
  </svg>
);

const LogoutIcon = () => (
  <svg
    width="20"
    height="20"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    strokeLinejoin="round"
  >
    <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
    <polyline points="16,17 21,12 16,7" />
    <line x1="21" y1="12" x2="9" y2="12" />
  </svg>
);

export const AuthButton = () => {
  const username = (window as any)["Microsoft"]?.Dynamic365?.Portal?.User?.userName ?? "";
  const firstName = (window as any)["Microsoft"]?.Dynamic365?.Portal?.User?.firstName ?? "";
  const lastName = (window as any)["Microsoft"]?.Dynamic365?.Portal?.User?.lastName ?? "";
  const isAuthenticated = username !== "";

  // @ts-ignore
  const tenantId = import.meta.env.VITE_TENANT_ID;

  const handleLogin = () => {
    // Using GET request with redirect to /Account/Login
    window.location.href = `/Account/Login?returnUrl=${encodeURIComponent(window.location.pathname)}`;
  };

  const handleLogout = () => {
    window.location.href = "/Account/Login/LogOff?returnUrl=%2F";
  };

  return (
    <div className="auth-button-container">
      {isAuthenticated ? (
        <div className="auth-user-section">
          <span className="welcome-text">
            Welcome {firstName} {lastName}
          </span>
          <button
            className="auth-button logout-button"
            onClick={handleLogout}
            title="Logout"
          >
            <LogoutIcon />
            <span className="button-text">Logout</span>
          </button>
        </div>
      ) : (
        <button
          className="auth-button login-button"
          onClick={handleLogin}
          title="Login"
        >
          <LoginIcon />
          <span className="button-text">Login</span>
        </button>
      )}
    </div>
  );
};