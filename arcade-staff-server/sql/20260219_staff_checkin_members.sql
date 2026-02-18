-- Predefined member list for Staff Checkin barcode validation
-- Run in the same Postgres DB used by arcade_staff tables.

CREATE TABLE IF NOT EXISTS club_staff_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_key text NOT NULL,
  reg_no text NOT NULL,
  name text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (event_key, reg_no)
);

CREATE INDEX IF NOT EXISTS idx_club_staff_members_event_reg
  ON club_staff_members (event_key, reg_no);

CREATE INDEX IF NOT EXISTS idx_club_staff_members_event_name
  ON club_staff_members (event_key, name);
