-- Migration 0001: Create staff_accounts table for HOD and Faculty account management
-- Cloudflare D1 Database schema for Nexora BVC API

CREATE TABLE IF NOT EXISTS staff_accounts (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL CHECK(role IN ('hod', 'faculty')),
  department TEXT NOT NULL,
  designation TEXT,
  phone TEXT,
  cabin TEXT,
  qualification TEXT,
  specialization TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_staff_role ON staff_accounts(role);
CREATE INDEX IF NOT EXISTS idx_staff_department ON staff_accounts(department);
CREATE INDEX IF NOT EXISTS idx_staff_email ON staff_accounts(email);
CREATE INDEX IF NOT EXISTS idx_staff_active ON staff_accounts(is_active);
