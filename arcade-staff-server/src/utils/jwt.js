import jwt from "jsonwebtoken";

export function signStaffToken(payload) {
  const secret = process.env.JWT_SECRET;
  const exp = process.env.JWT_EXPIRES_IN || "12h";
  return jwt.sign(payload, secret, { expiresIn: exp });
}

export function verifyToken(token) {
  const secret = process.env.JWT_SECRET;
  return jwt.verify(token, secret);
}
