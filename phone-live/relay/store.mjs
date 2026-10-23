import { DatabaseSync } from 'node:sqlite';
import { codec } from './security.mjs';

// Every value, including APNs tokens and request details, is encrypted at rest.
// The storage key must be protected separately from the database in deployment.
export class Store {
  constructor(path, key) {
    this.box = codec(key);
    this.db = new DatabaseSync(path);
    this.db.exec('PRAGMA journal_mode=WAL; PRAGMA busy_timeout=3000; CREATE TABLE IF NOT EXISTS records (kind TEXT, id TEXT, value TEXT NOT NULL, PRIMARY KEY(kind,id))');
  }
  put(kind, id, value) { this.db.prepare('INSERT OR REPLACE INTO records VALUES (?,?,?)').run(kind, id, this.box.seal(value)); return value; }
  get(kind, id) { const r = this.db.prepare('SELECT value FROM records WHERE kind=? AND id=?').get(kind,id); return r ? this.box.open(r.value) : null; }
  all(kind) { return this.db.prepare('SELECT value FROM records WHERE kind=?').all(kind).map(r=>this.box.open(r.value)); }
  remove(kind,id) { this.db.prepare('DELETE FROM records WHERE kind=? AND id=?').run(kind,id); }
  close() { this.db.close(); }
}
