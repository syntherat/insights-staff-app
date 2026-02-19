-- Staff app access + permanent Staff Checkin
-- Run in the same Postgres DB used by arcade_staff and arcade_wallets tables.

CREATE TABLE IF NOT EXISTS club_staff_app_access (
  staff_id uuid NOT NULL REFERENCES arcade_staff(id) ON DELETE CASCADE,
  staff_reg_no text,
  can_gate boolean NOT NULL DEFAULT false,
  can_game boolean NOT NULL DEFAULT false,
  can_prize boolean NOT NULL DEFAULT false,
  can_staff_checkin boolean NOT NULL DEFAULT false,
  can_manage_checkin_days boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (staff_id)
);

CREATE INDEX IF NOT EXISTS idx_club_staff_app_access_staff_reg_no
  ON club_staff_app_access (staff_reg_no);

CREATE TABLE IF NOT EXISTS club_staff_checkin_days (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  checkin_date date NOT NULL,
  title text,
  note text,
  is_active boolean NOT NULL DEFAULT true,
  created_by_staff_id uuid REFERENCES arcade_staff(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (checkin_date)
);

CREATE INDEX IF NOT EXISTS idx_club_staff_checkin_days_active
  ON club_staff_checkin_days (checkin_date, is_active);

CREATE TABLE IF NOT EXISTS club_staff_checkins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  day_id uuid NOT NULL REFERENCES club_staff_checkin_days(id) ON DELETE CASCADE,
  staff_reg_no text NOT NULL,
  checked_in_at timestamptz NOT NULL DEFAULT now(),
  checked_in_by_staff_id uuid REFERENCES arcade_staff(id) ON DELETE SET NULL,
  checked_in_by_username text,
  source text NOT NULL DEFAULT 'APP_SCAN',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (day_id, staff_reg_no)
);

CREATE INDEX IF NOT EXISTS idx_club_staff_checkins_day
  ON club_staff_checkins (day_id, checked_in_at DESC);

CREATE INDEX IF NOT EXISTS idx_club_staff_checkins_reg
  ON club_staff_checkins (staff_reg_no, checked_in_at DESC);
