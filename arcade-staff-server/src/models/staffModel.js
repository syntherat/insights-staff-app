import bcrypt from "bcryptjs";
import { pool } from "../config/db.js";

export async function findStaffByUsername({ preferEventKey, username, allowAnyEventFallback = false }) {
  if (preferEventKey) {
    const scoped = await pool.query(
      `
      SELECT id, event_key, username, email, full_name, role, is_active, password_hash
      FROM arcade_staff
      WHERE event_key=$1 AND lower(username)=lower($2)
      LIMIT 1;
      `,
      [preferEventKey, username]
    );
    if (scoped.rows[0]) return scoped.rows[0];
  }

  if (!allowAnyEventFallback) return null;

  const fallback = await pool.query(
    `
    SELECT id, event_key, username, email, full_name, role, is_active, password_hash
    FROM arcade_staff
    WHERE lower(username)=lower($1)
    ORDER BY is_active DESC
    LIMIT 1;
    `,
    [username]
  );

  return fallback.rows[0] || null;
}

export async function verifyStaffPassword(staffRow, password) {
  if (!staffRow?.password_hash) return false;
  return bcrypt.compare(password, staffRow.password_hash);
}
