import { Router } from "express";
import { asyncHandler } from "../middleware/asyncHandler.js";
import { requireStaffJWT, STAFF_SESSION_TOKEN_HEADER } from "../middleware/staffAuth.js";
import { findStaffByUsername, verifyStaffPassword } from "../models/staffModel.js";
import { resolveStaffAccess } from "../models/staffAccessModel.js";
import { signStaffToken } from "../utils/jwt.js";

const r = Router();

r.post("/login", asyncHandler(async (req, res) => {
  const arcadeEventKey = process.env.EVENT_KEY;
  const username = String(req.body?.username || "").trim();
  const password = String(req.body?.password || "");

  if (!username || !password) return res.status(400).json({ error: "username and password required" });

  const staff = await findStaffByUsername({
    preferEventKey: arcadeEventKey,
    username,
    allowAnyEventFallback: true,
  });
  if (!staff) return res.status(401).json({ error: "Invalid credentials" });
  if (!staff.is_active) return res.status(403).json({ error: "Staff inactive" });

  const ok = await verifyStaffPassword(staff, password);
  if (!ok) return res.status(401).json({ error: "Invalid credentials" });

  const access = await resolveStaffAccess({
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

r.get("/session", requireStaffJWT, asyncHandler(async (req, res) => {
  res.json({
    token: res.getHeader(STAFF_SESSION_TOKEN_HEADER) || null,
    staff: {
      id: req.staff.staff_id,
      username: req.staff.username,
      role: req.staff.role,
      full_name: null,
      email: null,
      access: req.staff.access || {},
    },
  });
}));

export default r;
