import { pool } from "../config/db.js";

function normalizeRegNo(value) {
  return String(value || "").trim().toUpperCase();
}

export async function checkinDaysList({ eventKey, includeInactive = false }) {
  const { rows } = await pool.query(
    `
    SELECT id, event_key, checkin_date, title, note, is_active, created_by_staff_id, created_at, updated_at
    FROM club_staff_checkin_days
    WHERE event_key=$1
      AND ($2::boolean = true OR is_active = true)
    ORDER BY checkin_date DESC;
    `,
    [eventKey, includeInactive]
  );
  return rows;
}

export async function createCheckinDay({ eventKey, checkinDate, title, note, createdByStaffId }) {
  const dateText = String(checkinDate || "").trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateText)) {
    throw new Error("checkin_date must be YYYY-MM-DD");
  }

  const { rows } = await pool.query(
    `
    INSERT INTO club_staff_checkin_days(event_key, checkin_date, title, note, is_active, created_by_staff_id)
    VALUES ($1, $2::date, NULLIF($3::text,''), NULLIF($4::text,''), true, $5)
    ON CONFLICT (event_key, checkin_date)
    DO UPDATE SET
      title = COALESCE(EXCLUDED.title, club_staff_checkin_days.title),
      note = COALESCE(EXCLUDED.note, club_staff_checkin_days.note),
      is_active = true,
      updated_at = now()
    RETURNING id, event_key, checkin_date, title, note, is_active, created_by_staff_id, created_at, updated_at;
    `,
    [eventKey, dateText, String(title || "").trim(), String(note || "").trim(), createdByStaffId || null]
  );

  return rows[0];
}

export async function setCheckinDayActive({ eventKey, dayId, isActive }) {
  const { rows } = await pool.query(
    `
    UPDATE club_staff_checkin_days
    SET is_active=$3, updated_at=now()
    WHERE id=$2 AND event_key=$1
    RETURNING id, event_key, checkin_date, title, note, is_active, created_by_staff_id, created_at, updated_at;
    `,
    [eventKey, dayId, !!isActive]
  );
  return rows[0] || null;
}

export async function findDayById({ eventKey, dayId }) {
  const { rows } = await pool.query(
    `
    SELECT id, event_key, checkin_date, title, note, is_active, created_by_staff_id, created_at, updated_at
    FROM club_staff_checkin_days
    WHERE event_key=$1 AND id=$2
    LIMIT 1;
    `,
    [eventKey, dayId]
  );
  return rows[0] || null;
}

export async function findActiveDayByDate({ eventKey, dateText }) {
  const { rows } = await pool.query(
    `
    SELECT id, event_key, checkin_date, title, note, is_active, created_by_staff_id, created_at, updated_at
    FROM club_staff_checkin_days
    WHERE event_key=$1 AND checkin_date::date=$2::date AND is_active=true
    LIMIT 1;
    `,
    [eventKey, dateText]
  );
  return rows[0] || null;
}

export async function scanStaffCheckin({ eventKey, dayId, regNo, staffId, staffUsername }) {
  const normalized = normalizeRegNo(regNo);
  if (!normalized) throw new Error("reg_no required");

  const { rows } = await pool.query(
    `
    INSERT INTO club_staff_checkins(event_key, day_id, staff_reg_no, checked_in_by_staff_id, checked_in_by_username, source)
    VALUES ($1,$2,$3,$4,$5,'APP_SCAN')
    ON CONFLICT (event_key, day_id, staff_reg_no)
    DO UPDATE SET
      checked_in_at = now(),
      checked_in_by_staff_id = EXCLUDED.checked_in_by_staff_id,
      checked_in_by_username = EXCLUDED.checked_in_by_username
    RETURNING id, event_key, day_id, staff_reg_no, checked_in_at, checked_in_by_staff_id, checked_in_by_username, source, created_at;
    `,
    [eventKey, dayId, normalized, staffId || null, staffUsername || null]
  );

  return rows[0];
}

export async function findMemberByRegNo({ eventKey, regNo }) {
  const normalized = normalizeRegNo(regNo);
  if (!normalized) return null;

  const { rows } = await pool.query(
    `
    SELECT id, event_key, reg_no, name, is_active, created_at, updated_at
    FROM club_staff_members
    WHERE event_key=$1 AND reg_no=$2 AND is_active=true
    LIMIT 1;
    `,
    [eventKey, normalized]
  );

  return rows[0] || null;
}

export async function myCheckins({ eventKey, staffRegNo, limit = 120 }) {
  const normalized = normalizeRegNo(staffRegNo);
  if (!normalized) return [];

  const { rows } = await pool.query(
    `
    SELECT
      c.id,
      c.day_id,
      c.staff_reg_no,
      m.name AS staff_name,
      c.checked_in_at,
      c.checked_in_by_username,
      d.checkin_date,
      d.title,
      d.note
    FROM club_staff_checkins c
    JOIN club_staff_checkin_days d ON d.id = c.day_id
    LEFT JOIN club_staff_members m
      ON m.event_key = c.event_key AND m.reg_no = c.staff_reg_no
    WHERE c.event_key=$1 AND c.staff_reg_no=$2
    ORDER BY d.checkin_date DESC, c.checked_in_at DESC
    LIMIT $3;
    `,
    [eventKey, normalized, limit]
  );

  return rows;
}

export async function dayCheckinsList({ eventKey, dayId }) {
  const { rows } = await pool.query(
    `
    SELECT c.id, c.staff_reg_no, c.checked_in_at, c.checked_in_by_username, m.name AS staff_name
    FROM club_staff_checkins c
    LEFT JOIN club_staff_members m
      ON m.event_key = c.event_key AND m.reg_no = c.staff_reg_no
    WHERE c.event_key=$1 AND c.day_id=$2
    ORDER BY c.checked_in_at DESC;
    `,
    [eventKey, dayId]
  );
  return rows;
}
