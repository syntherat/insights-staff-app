import bcrypt from "bcryptjs";
import { pool } from "../config/db.js";

export async function findStaffByUsername({ preferEventKey, username, allowAnyEventFallback = false }) {
  // Query permanent club_staff_accounts table
  const { rows } = await pool.query(
    `
    SELECT 
      id, 
      username, 
      email, 
      full_name, 
      role, 
      is_active, 
      password_hash,
      source_event_key as event_key
    FROM club_staff_accounts
    WHERE lower(username)=lower($1)
    LIMIT 1;
    `,
    [username]
  );

  return rows[0] || null;
}

export async function verifyStaffPassword(staffRow, password) {
  if (!staffRow?.password_hash) return false;
  return bcrypt.compare(password, staffRow.password_hash);
}
