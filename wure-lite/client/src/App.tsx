import { useState, useEffect } from "react";
import Icon from "./components/Icon";
import SimpleTable from "./components/SimpleTable";
import Login from "./components/Login";
import type { RecordRow } from "./components/SimpleTable";
import "./styles/app.css";

const API_BASE = import.meta.env.VITE_API_URL || "http://localhost:3001";
const TARGET_TABLE = "BESIM_RULES";
const USERS_TABLE = "BESIM_USERS";

type Page = "rules" | "users" | "settings";
type AuthUser = { id: number; username: string; name: string; surname: string; role: "ADMIN" | "USER" };

interface RulesData {
  table: string;
  count: number;
  rows: RecordRow[];
  columns: Array<{ name: string; dataType: string }>;
}

// API fetch helper with credentials
function apiFetch(url: string, init?: RequestInit): Promise<Response> {
  return fetch(url, { credentials: "include", ...init });
}

export default function App() {
  const [page, setPage] = useState<Page>("rules");
  const [currentUser, setCurrentUser] = useState<AuthUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [rules, setRules] = useState<RecordRow[]>([]);
  const [rulesLoading, setRulesLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selectedRuleIds, setSelectedRuleIds] = useState<Set<string>>(new Set());

  // Fetch current user on mount
  useEffect(() => {
    const fetchUser = async () => {
      try {
        const response = await apiFetch(`${API_BASE}/api/auth/me`);
        if (response.ok) {
          const data = await response.json();
          setCurrentUser(data.user);
        } else {
          setCurrentUser(null);
        }
      } catch (err) {
        console.error("Failed to fetch user:", err);
        setCurrentUser(null);
      } finally {
        setLoading(false);
      }
    };

    fetchUser();
  }, []);

  // Fetch rules data
  useEffect(() => {
    if (page !== "rules") return;

    const fetchRules = async () => {
      setRulesLoading(true);
      setError(null);
      try {
        const response = await apiFetch(`${API_BASE}/api/records/${TARGET_TABLE}?limit=500`);
        if (!response.ok) {
          throw new Error(`Failed to load rules: ${response.statusText}`);
        }
        const data = (await response.json()) as RulesData;
        setRules(data.rows);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Unknown error");
      } finally {
        setRulesLoading(false);
      }
    };

    fetchRules();
  }, [page]);

  const handleLogout = async () => {
    try {
      await apiFetch(`${API_BASE}/api/auth/logout`, { method: "POST" });
      setCurrentUser(null);
    } catch (err) {
      console.error("Logout failed:", err);
    }
  };

  if (loading) {
    return <div className="app-shell"><div className="loading">Načítání...</div></div>;
  }

  if (!currentUser) {
    return <Login onLoginSuccess={() => window.location.reload()} />;
  }

  const displayColumns = [
    { id: "RULE_ID", header: "ID", width: "5rem" },
    { id: "RULE_ACTIVE", header: "Aktivní", width: "10rem" },
    { id: "RULE_NAME", header: "Název", width: "auto" },
    { id: "MESSAGE_FCE_ID", header: "Backend", width: "20rem" },
    { id: "MESSAGE_FCE_VER", header: "Verze", width: "15rem" },
  ];

  return (
    <div className="app-shell">
      <nav className="app-nav">
        <div className="app-nav-brand">
          <Icon name="home" size={24} />
          <span className="app-nav-brand-text">wURE Lite</span>
        </div>
        <div className="app-nav-items">
          <button
            className={`app-nav-item ${page === "rules" ? "is-active" : ""}`}
            onClick={() => setPage("rules")}
          >
            <Icon name="stats" size={16} className="icon-inline" />
            Pravidla
          </button>
          <button
            className={`app-nav-item ${page === "users" ? "is-active" : ""}`}
            onClick={() => setPage("users")}
          >
            <Icon name="users" size={16} className="icon-inline" />
            Uživatelé
          </button>
          <button
            className={`app-nav-item ${page === "settings" ? "is-active" : ""}`}
            onClick={() => setPage("settings")}
          >
            <Icon name="settings" size={16} className="icon-inline" />
            Nastavení
          </button>
        </div>
        <div className="app-nav-spacer" />
        <div className="app-nav-user">
          <span className="app-nav-user-name">{currentUser.name} {currentUser.surname}</span>
          <button
            className="app-nav-item"
            onClick={handleLogout}
            title="Odhlásit"
          >
            <Icon name="logout" size={16} />
          </button>
        </div>
      </nav>

      <main className="app-main">
        {page === "rules" && (
          <div className="page-rules">
            <h2>Pravidla ({rules.length})</h2>
            {error && <div className="error-message">{error}</div>}
            {rulesLoading && <div className="loading">Načítání...</div>}
            {!rulesLoading && (
              <SimpleTable
                columns={displayColumns}
                rows={rules}
                rowKey={(row) => String(row.RULE_ID)}
                selectedRows={selectedRuleIds}
                onSelectionChange={setSelectedRuleIds}
              />
            )}
          </div>
        )}

        {page === "users" && (
          <div className="page-users">
            <h2>Uživatelé</h2>
            <p>Stránka uživatelů (v přípravě)</p>
          </div>
        )}

        {page === "settings" && (
          <div className="page-settings">
            <h2>Nastavení</h2>
            <p>Nastavení aplikace (v přípravě)</p>
          </div>
        )}
      </main>
    </div>
  );
}
