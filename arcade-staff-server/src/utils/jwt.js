import jwt from "jsonwebtoken";

export function signStaffToken(payload) {
  const secret = process.env.JWT_SECRET;
  const exp = process.env.JWT_EXPIRES_IN || "30d";
  return jwt.sign(payload, secret, { expiresIn: exp });
}

export function verifyToken(token) {
  const secret = process.env.JWT_SECRET;
  return jwt.verify(token, secret);
}

export function buildStaffTokenPayload(decoded) {
  return {
    staff_id: decoded.staff_id,
    username: decoded.username,
    role: decoded.role,
    event_key: decoded.event_key,
    access: decoded.access,
  };
}
