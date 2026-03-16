import Database from "better-sqlite3";
import path from "path";
import fs from "fs";

const dbPath = process.env.NODE_ENV === "production" ? "/var/lib/rbt/dashboard.db" : "./dashboard.db";

// Ensure directory exists
const dbDir = path.dirname(dbPath);
if (!fs.existsSync(dbDir)) {
  fs.mkdirSync(dbDir, { recursive: true });
}

const db = new Database(dbPath);

// Initialize tables
db.exec(`
  CREATE TABLE IF NOT EXISTS config (
    key TEXT PRIMARY KEY,
    value TEXT
  );

  CREATE TABLE IF NOT EXISTS tunnels (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE,
    protocol TEXT,
    listen_host TEXT,
    target_host TEXT,
    obfuscation TEXT,
    secret TEXT,
    port_hopping TEXT
  );
`);

export class DbService {
  static getConfig(key: string, defaultValue: string): string {
    const row = db.prepare("SELECT value FROM config WHERE key = ?").get(key) as { value: string } | undefined;
    return row ? row.value : defaultValue;
  }

  static setConfig(key: string, value: string) {
    db.prepare("INSERT OR REPLACE INTO config (key, value) VALUES (?, ?)").run(key, value);
  }

  static getTunnels() {
    return db.prepare("SELECT * FROM tunnels").all();
  }

  static addTunnel(tunnel: any) {
    const stmt = db.prepare(`
      INSERT INTO tunnels (name, protocol, listen_host, target_host, obfuscation, secret, port_hopping)
      VALUES (@name, @protocol, @listen_host, @target_host, @obfuscation, @secret, @port_hopping)
    `);
    stmt.run(tunnel);
  }

  static removeTunnel(name: string) {
    db.prepare("DELETE FROM tunnels WHERE name = ?").run(name);
  }
}
