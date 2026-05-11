const express = require("express");
const cors = require("cors");
const dotenv = require("dotenv");
const oracledb = require("oracledb");
const fs = require("fs/promises");
const path = require("path");
const util = require("util");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const cookieParser = require("cookie-parser");

const BCRYPT_ROUNDS = 10;
const USERS_TABLE = "BESIM_USERS";
const PASSWORD_COLUMN = "PASSWORD_HASH";
const JWT_COOKIE = "wure_lite_token";
const JWT_EXPIRY = "8h";

function getJwtSecret() {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    if (!global.__WURE_DEV_JWT_SECRET) {
      global.__WURE_DEV_JWT_SECRET = require("crypto").randomBytes(48).toString("hex");
      console.warn("[auth] JWT_SECRET not set — using ephemeral secret (all sessions reset on restart)");
    }
    return global.__WURE_DEV_JWT_SECRET;
  }
  return secret;
}

function signToken(payload) {
  return jwt.sign(payload, getJwtSecret(), { expiresIn: JWT_EXPIRY });
}

function verifyToken(token) {
  return jwt.verify(token, getJwtSecret());
}

async function hashPasswordIfNeeded(tableName, columnName, value) {
  if (
    tableName === USERS_TABLE &&
    columnName === PASSWORD_COLUMN &&
    typeof value === "string" &&
    value.trim() !== ""
  ) {
    return await bcrypt.hash(value, BCRYPT_ROUNDS);
  }
  return value;
}

dotenv.config({ path: path.join(__dirname, "..", ".env") });

const LOG_LEVEL = String(process.env.LOG_LEVEL || "info").toLowerCase();
const LOG_LEVEL_WEIGHT = {
  silent: 0,
  error: 1,
  info: 2,
  debug: 3,
};
const CURRENT_LOG_LEVEL = LOG_LEVEL_WEIGHT[LOG_LEVEL] ?? LOG_LEVEL_WEIGHT.info;

function logInfo(...args) {
  if (CURRENT_LOG_LEVEL >= LOG_LEVEL_WEIGHT.info) {
    console.log(...args);
  }
}

function logError(...args) {
  if (CURRENT_LOG_LEVEL >= LOG_LEVEL_WEIGHT.error) {
    console.error(...args);
  }
}

const app = express();
const port = Number(process.env.PORT || 3001);

const TABLE_NAME_PATTERN = /^BESIM_[A-Z0-9_]+$/;
const COLUMN_NAME_PATTERN = /^[A-Z][A-Z0-9_]*$/;
const DB_CONFIG_PATH = path.join(__dirname, "..", "config", "db-config.json");
const USER_SETTINGS_TABLE = "BESIM_USER_SETTINGS";

oracledb.outFormat = oracledb.OUT_FORMAT_OBJECT;
oracledb.fetchAsString = [oracledb.CLOB, oracledb.NCLOB];

function sanitizeRow(row) {
  const plain = {};
  for (const key of Object.keys(row)) {
    const val = row[key];
    if (val === null || val === undefined) {
      plain[key] = null;
    } else if (val instanceof Date) {
      plain[key] = val.toISOString();
    } else if (typeof val !== "object" && typeof val !== "function") {
      plain[key] = val;
    } else {
      try {
        plain[key] = JSON.parse(JSON.stringify(val));
      } catch (_) {
        plain[key] = util.inspect(val, { depth: 5, maxArrayLength: 50, breakLength: 120 });
      }
    }
  }
  return plain;
}

app.use(cors({ origin: true, credentials: true }));
app.use(express.json());
app.use(cookieParser());

function normalizeTableName(rawTableName) {
  const tableName = String(rawTableName || "").trim().toUpperCase();
  if (!TABLE_NAME_PATTERN.test(tableName)) {
    return null;
  }
  return tableName;
}

function normalizeDbConfig(rawConfig) {
  const config = rawConfig && typeof rawConfig === "object" ? rawConfig : {};
  return {
    user: String(config.user || "").trim(),
    password: String(config.password || "").trim(),
    connectString: String(config.connectString || "").trim(),
  };
}

function maskDbConfig(config) {
  return {
    user: config.user,
    connectString: config.connectString,
    hasPassword: Boolean(config.password),
  };
}

async function readSavedDbConfig() {
  try {
    const raw = await fs.readFile(DB_CONFIG_PATH, "utf8");
    return normalizeDbConfig(JSON.parse(raw));
  } catch (error) {
    if (error.code === "ENOENT") {
      return null;
    }
    throw error;
  }
}

async function buildEffectiveDbConfig(inputConfig) {
  const saved = await readSavedDbConfig();
  const input = normalizeDbConfig(inputConfig);
  const environment = normalizeDbConfig({
    user: process.env.ORACLE_USER,
    password: process.env.ORACLE_PASSWORD,
    connectString: process.env.ORACLE_CONNECT_STRING,
  });

  const effective = {
    user: input.user || saved?.user || environment.user,
    password: input.password || saved?.password || environment.password,
    connectString: input.connectString || saved?.connectString || environment.connectString,
  };

  const missingFields = Object.entries(effective)
    .filter(([, value]) => !String(value || "").trim())
    .map(([key]) => key);

  if (missingFields.length > 0) {
    throw new Error(`Missing DB config values: ${missingFields.join(", ")}`);
  }

  return normalizeDbConfig(effective);
}

async function testConnection(config) {
  let connection;
  try {
    connection = await oracledb.getConnection(config);
    await connection.execute("SELECT 1 AS ok FROM dual");
  } finally {
    if (connection) {
      await connection.close();
    }
  }
}

async function getConnection() {
  const config = await buildEffectiveDbConfig();
  return oracledb.getConnection(config);
}

async function tableExists(connection, tableName) {
  const result = await connection.execute(
    `SELECT 1 FROM user_tables WHERE table_name = :tableName`,
    { tableName }
  );
  return (result.rows || []).length > 0;
}

async function getTableColumnDetails(connection, tableName) {
  const result = await connection.execute(
    `SELECT column_name, data_type
       FROM user_tab_columns
      WHERE table_name = :tableName
      ORDER BY column_id`,
    { tableName }
  );

  const columns = (result.rows || []).map((r) => ({
    name: String(r.COLUMN_NAME).toUpperCase(),
    dataType: String(r.DATA_TYPE || "VARCHAR2").toUpperCase(),
  }));

  const byName = {};
  columns.forEach((c) => {
    byName[c.name] = c.dataType;
  });

  return { columns, byName };
}

async function getTableColumns(connection, tableName) {
  const result = await connection.execute(
    `SELECT column_name
       FROM user_tab_columns
      WHERE table_name = :tableName`,
    { tableName }
  );

  return new Set((result.rows || []).map((r) => String(r.COLUMN_NAME).toUpperCase()));
}

app.get("/api/health", (_req, res) => {
  res.json({ ok: true });
});

app.get("/api/columns/:table", async (req, res) => {
  const tableName = normalizeTableName(req.params.table);

  if (!tableName) {
    return res.status(400).json({ message: "Invalid table name. Expected BESIM_*" });
  }

  let connection;

  try {
    connection = await getConnection();

    if (!(await tableExists(connection, tableName))) {
      return res.status(404).json({ message: "Table not found" });
    }

    const { columns } = await getTableColumnDetails(connection, tableName);
    return res.json({ table: tableName, columns });
  } catch (error) {
    return res.status(500).json({ message: "Failed to load columns", detail: error.message });
  } finally {
    if (connection) {
      await connection.close();
    }
  }
});

app.get("/api/db-config", async (_req, res) => {
  try {
    const config = await buildEffectiveDbConfig();
    return res.json(maskDbConfig(config));
  } catch (_error) {
    const environment = normalizeDbConfig({
      user: process.env.ORACLE_USER,
      password: process.env.ORACLE_PASSWORD,
      connectString: process.env.ORACLE_CONNECT_STRING,
    });
    return res.json(maskDbConfig(environment));
  }
});

app.get("/api/tables", async (_req, res) => {
  let connection;

  try {
    connection = await getConnection();
    const result = await connection.execute(
      `SELECT table_name
         FROM user_tables
        WHERE table_name LIKE 'BESIM\\_%' ESCAPE '\\'
        ORDER BY table_name`
    );

    res.json((result.rows || []).map((r) => r.TABLE_NAME));
  } catch (error) {
    res.status(500).json({ message: "Failed to load tables", detail: error.message });
  } finally {
    if (connection) {
      await connection.close();
    }
  }
});

// Auth middleware
function requireAuth(req, res, next) {
  const token = req.cookies?.[JWT_COOKIE];
  if (!token) return res.status(401).json({ message: "Nepřihlášen" });
  try {
    req.user = verifyToken(token);
    next();
  } catch {
    res.clearCookie(JWT_COOKIE);
    return res.status(401).json({ message: "Relace vypršela — přihlaste se znovu" });
  }
}

// Auth routes
app.post("/api/auth/login", async (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) {
    return res.status(400).json({ message: "Zadejte uživatelské jméno a heslo" });
  }

  let connection;
  try {
    connection = await getConnection();

    const result = await connection.execute(
      `SELECT ID, USERNAME, PASSWORD_HASH, NAME, SURNAME, ROLE, IS_ACTIVE
         FROM ${USERS_TABLE}
        WHERE USERNAME = :username`,
      { username: String(username).trim() }
    );
    
    const user = result.rows?.[0];
    if (!user) {
      return res.status(401).json({ message: "Nesprávné uživatelské jméno nebo heslo" });
    }

    if (String(user.IS_ACTIVE) !== "1") {
      return res.status(403).json({ message: "Účet je deaktivován" });
    }

    const passwordOk = await bcrypt.compare(String(password), String(user.PASSWORD_HASH));
    if (!passwordOk) {
      return res.status(401).json({ message: "Nesprávné uživatelské jméno nebo heslo" });
    }

    const payload = {
      id:       user.ID,
      username: user.USERNAME,
      name:     user.NAME,
      surname:  user.SURNAME,
      role:     user.ROLE,
    };

    const token = signToken(payload);
    res.cookie(JWT_COOKIE, token, {
      httpOnly: true,
      sameSite: "lax",
      maxAge: 8 * 60 * 60 * 1000,
      secure: process.env.NODE_ENV === "production",
    });

    return res.json({ ok: true, user: payload });
  } catch (error) {
    logError("[auth/login] error:", error.message);
    return res.status(500).json({ message: "Chyba serveru při přihlašování" });
  } finally {
    if (connection) await connection.close();
  }
});

app.get("/api/auth/me", (req, res) => {
  const token = req.cookies?.[JWT_COOKIE];
  if (!token) return res.status(401).json({ message: "Nepřihlášen" });
  try {
    const user = verifyToken(token);
    return res.json({ user });
  } catch {
    res.clearCookie(JWT_COOKIE);
    return res.status(401).json({ message: "Relace vypršela" });
  }
});

app.post("/api/auth/logout", (req, res) => {
  res.clearCookie(JWT_COOKIE);
  return res.json({ ok: true });
});

// Protected routes
app.use("/api/records", requireAuth);

app.get("/api/records/:table", async (req, res) => {
  const tableName = normalizeTableName(req.params.table);
  const limit = Math.max(1, Math.min(500, Number(req.query.limit) || 100));

  if (!tableName) {
    return res.status(400).json({ message: "Invalid table name. Expected BESIM_*" });
  }

  let connection;

  try {
    connection = await getConnection();

    if (!(await tableExists(connection, tableName))) {
      return res.status(404).json({ message: "Table not found" });
    }

    const { columns } = await getTableColumnDetails(connection, tableName);

    const sql = `SELECT ROWIDTOCHAR(t.ROWID) AS ROW_ID_CHAR, t.* FROM ${tableName} t FETCH FIRST :limit ROWS ONLY`;
    const result = await connection.execute(sql, { limit });

    const safeRows = (result.rows || []).map(sanitizeRow);
    return res.json({
      table: tableName,
      count: safeRows.length,
      rows: safeRows,
      columns,
    });
  } catch (error) {
    return res.status(500).json({ message: "Failed to load records", detail: error.message });
  } finally {
    if (connection) {
      await connection.close();
    }
  }
});

app.listen(port, () => {
  logInfo(`wURE Lite API listening on http://localhost:${port}`);
});
