import { verifyToken } from "../utils/jwt.js";

export function requireStaffJWT(req, res, next) {
  const header = req.headers.authorization || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;

  if (!token) return res.status(401).json({ error: "Missing Authorization Bearer token" });

  try {
    const decoded = verifyToken(token);
    // decoded: { staff_id, username, role, event_key, iat, exp }
    req.staff = decoded;
    return next();
  } catch (e) {
    return res.status(401).json({ error: "Invalid or expired token" });
  }
}
