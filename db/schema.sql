-- Devam takip uygulamasının SQLite şeması.
-- Dosya idempotenttir: tekrar çalıştırıldığında mevcut nesneleri bozmaz.
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS students (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT NOT NULL CHECK (length(trim(name)) > 0),
  status     TEXT NOT NULL CHECK (status IN ('aktif', 'donduruldu', 'mezun')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS course_sessions (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  session_no   INTEGER NOT NULL UNIQUE CHECK (session_no BETWEEN 1 AND 10),
  session_date TEXT,
  title        TEXT NOT NULL CHECK (length(trim(title)) > 0),
  created_at   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS attendance_records (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id        INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  course_session_id INTEGER NOT NULL REFERENCES course_sessions(id) ON DELETE CASCADE,
  absent            INTEGER NOT NULL CHECK (absent IN (0, 1)),
  created_at        TEXT NOT NULL,
  updated_at        TEXT NOT NULL,
  UNIQUE (student_id, course_session_id)
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id  INTEGER REFERENCES students(id) ON DELETE SET NULL,
  action      TEXT NOT NULL CHECK (length(trim(action)) > 0),
  entity_type TEXT NOT NULL CHECK (length(trim(entity_type)) > 0),
  entity_id   INTEGER,
  before_json TEXT,
  after_json  TEXT,
  created_at  TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_students_status ON students (status);
CREATE INDEX IF NOT EXISTS idx_students_name ON students (name);
CREATE INDEX IF NOT EXISTS idx_attendance_records_student ON attendance_records (student_id);
CREATE INDEX IF NOT EXISTS idx_attendance_records_session ON attendance_records (course_session_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_student ON audit_logs (student_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs (created_at);

PRAGMA user_version = 1;
