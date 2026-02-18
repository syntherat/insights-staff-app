import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import helmet from "helmet";

import staffAuthRoutes from "./routes/staffAuthRoutes.js";
import staffArcadeRoutes from "./routes/staffArcadeRoutes.js";

dotenv.config();

const app = express();

app.use(helmet());
app.use(cors({ origin: process.env.CORS_ORIGIN || "*", credentials: false }));
app.use(express.json({ limit: "1mb" }));

app.get("/", (_req, res) => res.json({ ok: true, service: "arcade-staff-server" }));

app.use("/api/staff/auth", staffAuthRoutes);
app.use("/api/staff", staffArcadeRoutes);

// error handler
app.use((err, _req, res, _next) => {
  console.error(err);
  const msg = err?.message || "Server error";
  res.status(500).json({ error: msg });
});

const port = Number(process.env.PORT || 5051);
app.listen(port, () => console.log(`✅ Staff server running on :${port}`));
