import { pool } from "../config/db.js";

function normalizeRegNo(value) {
  return String(value || "").trim().toUpperCase();
}

export async function checkinDaysList({ includeInactive = false }) {
  const { rows } = await pool.query(
    `
    SELECT id, checkin_date, title, note, is_active, created_by_staff_id, created_at, updated_at
    FROM club_staff_checkin_days
    WHERE ($1::boolean = true OR is_active = true)
    ORDER BY checkin_date DESC;
    `,
    [includeInactive]
  );
  return rows;
}

export async function createCheckinDay({ checkinDate, title, note, createdByStaffId }) {
  const dateText = String(checkinDate || "").trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateText)) {
    throw new Error("checkin_date must be YYYY-MM-DD");
  }

  const { rows } = await pool.query(
    `
    INSERT INTO club_staff_checkin_days(checkin_date, title, note, is_active, created_by_staff_id)
    VALUES ($1::date, NULLIF($2::text,''), NULLIF($3::text,''), true, $4)
    ON CONFLICT (checkin_date)
    DO UPDATE SET
      title = COALESCE(EXCLUDED.title, club_staff_checkin_days.title),
      note = COALESCE(EXCLUDED.note, club_staff_checkin_days.note),
      is_active = true,
      updated_at = now()
    RETURNING id, checkin_date, title, note, is_active, created_by_staff_id, created_at, updated_at;
    `,
    [dateText, String(title || "").trim(), String(note || "").trim(), createdByStaffId || null]
  );

  return rows[0];
}

export async function setCheckinDayActive({ dayId, isActive }) {
  const { rows } = await pool.query(
    `
    UPDATE club_staff_checkin_days
    SET is_active=$2, updated_at=now()
    WHERE id=$1
    RETURNING id, checkin_date, title, note, is_active, created_by_staff_id, created_at, updated_at;
    `,
    [dayId, !!isActive]
  );
  return rows[0] || null;
}

export async function findDayById({ dayId }) {
  const { rows } = await pool.query(
    `
    SELECT id, checkin_date, title, note, is_active, created_by_staff_id, created_at, updated_at
    FROM club_staff_checkin_days
    WHERE id=$1
    LIMIT 1;
    `,
    [dayId]
  );
  return rows[0] || null;
}

export async function findActiveDayByDate({ dateText }) {
  const { rows } = await pool.query(
    `
    SELECT id, checkin_date, title, note, is_active, created_by_staff_id, created_at, updated_at
    FROM club_staff_checkin_days
    WHERE checkin_date::date=$1::date AND is_active=true
    LIMIT 1;
    `,
    [dateText]
  );
  return rows[0] || null;
}

export async function scanStaffCheckin({ dayId, regNo, staffId, staffUsername }) {
  const normalized = normalizeRegNo(regNo);
  if (!normalized) throw new Error("reg_no required");

  const { rows } = await pool.query(
    `
    INSERT INTO club_staff_checkins(day_id, staff_reg_no, checked_in_by_staff_id, checked_in_by_username, source)
    VALUES ($1,$2,$3,$4,'APP_SCAN')
    ON CONFLICT (day_id, staff_reg_no)
    DO UPDATE SET
      checked_in_at = now(),
      checked_in_by_staff_id = EXCLUDED.checked_in_by_staff_id,
      checked_in_by_username = EXCLUDED.checked_in_by_username
    RETURNING id, day_id, staff_reg_no, checked_in_at, checked_in_by_staff_id, checked_in_by_username, source, created_at;
    `,
    [dayId, normalized, staffId || null, staffUsername || null]
  );

  return rows[0];
}

export async function findMemberByRegNo({ regNo }) {
  const normalized = normalizeRegNo(regNo);
  if (!normalized) return null;

  const { rows } = await pool.query(
    `
    SELECT id, reg_no, name, is_active, created_at, updated_at
    FROM club_staff_members
    WHERE reg_no=$1 AND is_active=true
    LIMIT 1;
    `,
    [normalized]
  );

  return rows[0] || null;
}

export async function myCheckins({ staffRegNo, limit = 120 }) {
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
      ON m.reg_no = c.staff_reg_no
    WHERE c.staff_reg_no=$1
    ORDER BY d.checkin_date DESC, c.checked_in_at DESC
    LIMIT $2;
    `,
    [normalized, limit]
  );

  return rows;
}

export async function dayCheckinsList({ dayId }) {
  const { rows } = await pool.query(
    `
    SELECT c.id, c.staff_reg_no, c.checked_in_at, c.checked_in_by_username, m.name AS staff_name
    FROM club_staff_checkins c
    LEFT JOIN club_staff_members m
      ON m.reg_no = c.staff_reg_no
    WHERE c.day_id=$1
    ORDER BY c.checked_in_at DESC;
    `,
    [dayId]
  );
  return rows;
}
