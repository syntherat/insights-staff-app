import { pool } from "../config/db.js";

function defaultsFromRole(role) {
  const r = String(role || "").toUpperCase();
  if (r === "STAFF") {
    return {
      can_gate: false,
      can_game: false,
      can_prize: false,
      can_staff_checkin: true,
      can_manage_checkin_days: false,
    };
  }
  if (r === "GATE") {
    return {
      can_gate: true,
      can_game: false,
      can_prize: false,
      can_staff_checkin: false,
      can_manage_checkin_days: false,
    };
  }
  if (r === "GAME") {
    return {
      can_gate: false,
      can_game: true,
      can_prize: true,
      can_staff_checkin: false,
      can_manage_checkin_days: false,
    };
  }
  if (r === "PRIZE") {
    return {
      can_gate: false,
      can_game: false,
      can_prize: true,
      can_staff_checkin: false,
      can_manage_checkin_days: false,
    };
  }
  return {
    can_gate: false,
    can_game: false,
    can_prize: false,
    can_staff_checkin: false,
    can_manage_checkin_days: false,
  };
}

export async function resolveStaffAccess({ eventKey, staffId, role }) {
  const fallback = defaultsFromRole(role);
  if (!staffId) {
    return {
      ...fallback,
      staff_reg_no: null,
    };
  }

  const { rows } = await pool.query(
    `
    SELECT
      staff_reg_no,
      can_gate,
      can_game,
      can_prize,
      can_staff_checkin,
      can_manage_checkin_days
    FROM club_staff_app_access
    WHERE event_key=$1 AND staff_id=$2
    LIMIT 1;
    `,
    [eventKey, staffId]
  );

  const row = rows[0];
  if (!row) {
    return {
      ...fallback,
      staff_reg_no: null,
    };
  }

  return {
    can_gate: row.can_gate,
    can_game: row.can_game,
    can_prize: row.can_prize,
    can_staff_checkin: row.can_staff_checkin,
    can_manage_checkin_days: row.can_manage_checkin_days,
    staff_reg_no: row.staff_reg_no || null,
  };
}
