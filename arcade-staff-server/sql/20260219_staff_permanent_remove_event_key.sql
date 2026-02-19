-- Convert staff-app permanent tables to non-event-scoped structure.
-- This keeps data and removes event_key dependency for:
--   club_staff_app_access, club_staff_checkin_days, club_staff_checkins, club_staff_members

BEGIN;

-- 1) club_staff_app_access: keep latest row per staff_id
WITH ranked AS (
  SELECT ctid,
         row_number() OVER (
           PARTITION BY staff_id
           ORDER BY updated_at DESC, created_at DESC, ctid DESC
         ) AS rn
  FROM club_staff_app_access
)
DELETE FROM club_staff_app_access a
USING ranked r
WHERE a.ctid = r.ctid
  AND r.rn > 1;

ALTER TABLE club_staff_app_access
  DROP COLUMN IF EXISTS event_key CASCADE;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'club_staff_app_access'::regclass
      AND contype = 'p'
  ) THEN
    ALTER TABLE club_staff_app_access
      ADD CONSTRAINT club_staff_app_access_pkey PRIMARY KEY (staff_id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_club_staff_app_access_staff_reg_no
  ON club_staff_app_access (staff_reg_no);

-- 2) club_staff_checkin_days: merge duplicate checkin_date rows if they exist
WITH ranked_days AS (
  SELECT id,
         checkin_date,
         row_number() OVER (
           PARTITION BY checkin_date
           ORDER BY updated_at DESC, created_at DESC, id DESC
         ) AS rn,
         first_value(id) OVER (
           PARTITION BY checkin_date
           ORDER BY updated_at DESC, created_at DESC, id DESC
         ) AS keep_id
  FROM club_staff_checkin_days
), remap AS (
  SELECT id AS old_id, keep_id
  FROM ranked_days
  WHERE rn > 1
)
UPDATE club_staff_checkins c
SET day_id = r.keep_id
FROM remap r
WHERE c.day_id = r.old_id;

WITH ranked_days AS (
  SELECT id,
         row_number() OVER (
           PARTITION BY checkin_date
           ORDER BY updated_at DESC, created_at DESC, id DESC
         ) AS rn
  FROM club_staff_checkin_days
)
DELETE FROM club_staff_checkin_days d
USING ranked_days r
WHERE d.id = r.id
  AND r.rn > 1;

ALTER TABLE club_staff_checkin_days
  DROP COLUMN IF EXISTS event_key CASCADE;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'club_staff_checkin_days'::regclass
      AND contype = 'u'
      AND conname = 'club_staff_checkin_days_checkin_date_key'
  ) THEN
    ALTER TABLE club_staff_checkin_days
      ADD CONSTRAINT club_staff_checkin_days_checkin_date_key UNIQUE (checkin_date);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_club_staff_checkin_days_active
  ON club_staff_checkin_days (checkin_date, is_active);

-- 3) club_staff_members: keep latest row per reg_no
WITH ranked AS (
  SELECT ctid,
         row_number() OVER (
           PARTITION BY reg_no
           ORDER BY updated_at DESC, created_at DESC, ctid DESC
         ) AS rn
  FROM club_staff_members
)
DELETE FROM club_staff_members m
USING ranked r
WHERE m.ctid = r.ctid
  AND r.rn > 1;

ALTER TABLE club_staff_members
  DROP COLUMN IF EXISTS event_key CASCADE;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'club_staff_members'::regclass
      AND contype = 'u'
      AND conname = 'club_staff_members_reg_no_key'
  ) THEN
    ALTER TABLE club_staff_members
      ADD CONSTRAINT club_staff_members_reg_no_key UNIQUE (reg_no);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_club_staff_members_event_reg
  ON club_staff_members (reg_no);

CREATE INDEX IF NOT EXISTS idx_club_staff_members_event_name
  ON club_staff_members (name);

-- 4) club_staff_checkins: remove duplicates and drop event_key
WITH ranked AS (
  SELECT ctid,
         row_number() OVER (
           PARTITION BY day_id, staff_reg_no
           ORDER BY checked_in_at DESC, created_at DESC, ctid DESC
         ) AS rn
  FROM club_staff_checkins
)
DELETE FROM club_staff_checkins c
USING ranked r
WHERE c.ctid = r.ctid
  AND r.rn > 1;

ALTER TABLE club_staff_checkins
  DROP COLUMN IF EXISTS event_key CASCADE;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'club_staff_checkins'::regclass
      AND contype = 'u'
      AND conname = 'club_staff_checkins_day_id_staff_reg_no_key'
  ) THEN
    ALTER TABLE club_staff_checkins
      ADD CONSTRAINT club_staff_checkins_day_id_staff_reg_no_key UNIQUE (day_id, staff_reg_no);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_club_staff_checkins_day
  ON club_staff_checkins (day_id, checked_in_at DESC);

CREATE INDEX IF NOT EXISTS idx_club_staff_checkins_reg
  ON club_staff_checkins (staff_reg_no, checked_in_at DESC);

COMMIT;
