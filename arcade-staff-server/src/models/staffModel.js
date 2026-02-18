import bcrypt from "bcryptjs";
import { pool } from "../config/db.js";

export async function findStaffByUsername({ eventKey, username }) {
  const { rows } = await pool.query(
    `
    SELECT id, event_key, username, email, full_name, role, is_active, password_hash
    FROM arcade_staff
    WHERE event_key=$1 AND lower(username)=lower($2)
    LIMIT 1;
    `,
    [eventKey, username]
  );
  return rows[0] || null;
}

export async function verifyStaffPassword(staffRow, password) {
  if (!staffRow?.password_hash) return false;
  return bcrypt.compare(password, staffRow.password_hash);
}
