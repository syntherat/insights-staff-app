import { Router } from "express";
import { asyncHandler } from "../middleware/asyncHandler.js";
import { findStaffByUsername, verifyStaffPassword } from "../models/staffModel.js";
import { resolveStaffAccess } from "../models/staffAccessModel.js";
import { signStaffToken } from "../utils/jwt.js";

const r = Router();

r.post("/login", asyncHandler(async (req, res) => {
  const eventKey = process.env.EVENT_KEY;
  const username = String(req.body?.username || "").trim();
  const password = String(req.body?.password || "");

  if (!username || !password) return res.status(400).json({ error: "username and password required" });

  const staff = await findStaffByUsername({ eventKey, username });
  if (!staff) return res.status(401).json({ error: "Invalid credentials" });
  if (!staff.is_active) return res.status(403).json({ error: "Staff inactive" });

  const ok = await verifyStaffPassword(staff, password);
  if (!ok) return res.status(401).json({ error: "Invalid credentials" });

  const access = await resolveStaffAccess({
    eventKey,
    staffId: staff.id,
    role: staff.role,
  });

  const token = signStaffToken({
    staff_id: staff.id,
    username: staff.username,
    role: staff.role,
    event_key: staff.event_key,
    access,
  });

  res.json({
    token,
    staff: {
      id: staff.id,
      username: staff.username,
      role: staff.role,
      full_name: staff.full_name || null,
      email: staff.email || null,
      access,
    },
  });
}));

export default r;
