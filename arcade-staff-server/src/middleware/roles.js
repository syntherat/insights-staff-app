// src/middleware/roles.js
export function requireRole(...roles) {
  return (req, res, next) => {
    const role = req.staff?.role;

    if (!role) return res.status(401).json({ error: "Unauthorized" });

    // ✅ STAFF can access everything
    if (role === "STAFF") return next();

    // ✅ otherwise must match allowed roles
    if (!roles.includes(role)) return res.status(403).json({ error: "Forbidden" });

    return next();
  };
}
