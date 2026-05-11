import { useState } from "react";
import Icon from "./Icon";

const API_BASE = import.meta.env.VITE_API_URL || "http://localhost:3001";

interface LoginProps {
  onLoginSuccess: () => void;
}

export default function Login({ onLoginSuccess }: LoginProps) {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      const response = await fetch(`${API_BASE}/api/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "include",
        body: JSON.stringify({ username, password }),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.message || "Přihlášení selhalo");
      }

      onLoginSuccess();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Chyba při přihlášení");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-container">
        <div className="login-card">
          <div className="login-header">
            <Icon name="home" size={32} />
            <h1>wURE Lite</h1>
          </div>

          <form onSubmit={handleSubmit} className="login-form">
            {error && <div className="login-error">{error}</div>}

            <div className="login-field">
              <label htmlFor="username" className="login-label">
                Uživatelské jméno
              </label>
              <input
                id="username"
                type="text"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                placeholder="Zadejte jméno"
                disabled={loading}
                className="login-input"
              />
            </div>

            <div className="login-field">
              <label htmlFor="password" className="login-label">
                Heslo
              </label>
              <input
                id="password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Zadejte heslo"
                disabled={loading}
                className="login-input"
              />
            </div>

            <button
              type="submit"
              disabled={loading || !username || !password}
              className="login-button"
            >
              {loading ? "Přihlašuji..." : "Přihlásit"}
            </button>
          </form>

          <p className="login-info">
            Ujistěte se, že backend běží na <code>http://localhost:3001</code>
          </p>
        </div>
      </div>
    </div>
  );
}
