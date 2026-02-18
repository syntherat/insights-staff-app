export function requireAccess(permissionKey) {
  return (req, res, next) => {
    const access = req.staff?.access || {};
    if (access?.[permissionKey] === true) return next();
    return res.status(403).json({ error: "Forbidden" });
  };
}
