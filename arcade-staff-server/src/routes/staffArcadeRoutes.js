import { Router } from "express";
import { asyncHandler } from "../middleware/asyncHandler.js";
import { requireStaffJWT } from "../middleware/staffAuth.js";
import { requireAccess } from "../middleware/staffAccess.js";
import * as M from "../models/staffArcadeModel.js";
import * as C from "../models/staffCheckinModel.js";

const r = Router();
r.use(requireStaffJWT);

const EVENT_KEY = process.env.EVENT_KEY;

// who am i
r.get("/me", (req, res) => {
  res.json({ staff: req.staff });
});

/* Permanent Staff Checkin */
r.get("/staff-checkin/days", asyncHandler(async (req, res) => {
  const includeInactive = String(req.query.include_inactive || "").trim() === "1";
  const items = await C.checkinDaysList({ eventKey: EVENT_KEY, includeInactive });
  res.json({ items });
}));

r.post("/staff-checkin/days", requireAccess("can_manage_checkin_days"), asyncHandler(async (req, res) => {
  const b = req.body || {};
  const item = await C.createCheckinDay({
    eventKey: EVENT_KEY,
    checkinDate: b.checkin_date,
    title: b.title,
    note: b.note,
    createdByStaffId: req.staff.staff_id,
  });
  res.json({ item });
}));

r.patch("/staff-checkin/days/:id/active", requireAccess("can_manage_checkin_days"), asyncHandler(async (req, res) => {
  const item = await C.setCheckinDayActive({
    eventKey: EVENT_KEY,
    dayId: req.params.id,
    isActive: !!req.body?.is_active,
  });
  if (!item) return res.status(404).json({ error: "Day not found" });
  res.json({ item });
}));

r.post("/staff-checkin/scan", requireAccess("can_staff_checkin"), asyncHandler(async (req, res) => {
  const b = req.body || {};
  const regNo = String(b.reg_no || "").trim().toUpperCase();
  if (!regNo) return res.status(400).json({ error: "reg_no required" });

  const member = await C.findMemberByRegNo({ eventKey: EVENT_KEY, regNo });
  if (!member) {
    return res.status(400).json({ error: "Registration number not found in predefined member list" });
  }

  let day = null;
  if (b.day_id) {
    day = await C.findDayById({ eventKey: EVENT_KEY, dayId: String(b.day_id) });
  } else {
    // Use UTC midnight to match server's stored dates
    const now = new Date();
    const utcDateText = new Date(now.getTime() - now.getTimezoneOffset() * 60000).toISOString().slice(0, 10);
    const dateText = String(b.checkin_date || utcDateText);
    day = await C.findActiveDayByDate({ eventKey: EVENT_KEY, dateText });
  }

  if (!day) return res.status(400).json({ error: "No active Staff Checkin day found" });
  if (!day.is_active) return res.status(400).json({ error: "Selected day is inactive" });

  const item = await C.scanStaffCheckin({
    eventKey: EVENT_KEY,
    dayId: day.id,
    regNo,
    staffId: req.staff.staff_id,
    staffUsername: req.staff.username,
  });

  res.json({ item, day, member });
}));

r.get("/staff-checkin/my", asyncHandler(async (req, res) => {
  const staffRegNo = req.staff?.access?.staff_reg_no || null;
  const items = await C.myCheckins({ eventKey: EVENT_KEY, staffRegNo, limit: 180 });
  res.json({
    profile: {
      username: req.staff?.username || null,
      role: req.staff?.role || null,
      staff_reg_no: staffRegNo,
    },
    items,
  });
}));

r.get("/staff-checkin/days/:id/checkins", requireAccess("can_manage_checkin_days"), asyncHandler(async (req, res) => {
  const day = await C.findDayById({ eventKey: EVENT_KEY, dayId: req.params.id });
  if (!day) return res.status(404).json({ error: "Day not found" });
  const items = await C.dayCheckinsList({ eventKey: EVENT_KEY, dayId: day.id });
  res.json({ day, items });
}));

// wallet lookup (both roles)
r.get("/wallets/lookup", asyncHandler(async (req, res) => {
  const code = String(req.query.code || "").trim();
  if (!code) return res.status(400).json({ error: "code required" });

  const item = await M.walletLookupByCode({ eventKey: EVENT_KEY, code });
  if (!item) return res.json({ item: null });

  const recent = await M.walletRecentTxns({ eventKey: EVENT_KEY, walletId: item.wallet_id, limit: 3 });

  // Fetch team members and exclude the scanned member if this wallet belongs to a member.
  let teamMembers = await M.getTeamMembers({ 
    eventKey: EVENT_KEY, 
    regId: item.reg_id,
    excludeMemberId: item.member_id
  });

  // If a member wallet is scanned, add the primary registrant to the list.
  if (item.member_id) {
    const primary = await M.getPrimaryRegistrant({ eventKey: EVENT_KEY, regId: item.reg_id });
    if (primary) teamMembers = [primary, ...teamMembers];
  }

  res.json({ item, recent, teamMembers });
}));

/* Gate check-in */
r.post("/checkin/approve", requireAccess("can_gate"), asyncHandler(async (req, res) => {
  const regId = String(req.body?.reg_id || "").trim();
  if (!regId) return res.status(400).json({ error: "reg_id required" });

  const item = await M.checkinApprove({
    eventKey: EVENT_KEY,
    regId,
    staffId: req.staff.staff_id,
    staffUsername: req.staff.username,
  });

  res.json({ item });
}));

r.post("/checkin/reject", requireAccess("can_gate"), asyncHandler(async (req, res) => {
  const regId = String(req.body?.reg_id || "").trim();
  if (!regId) return res.status(400).json({ error: "reg_id required" });

  const reason = String(req.body?.reason || "").trim();

  const item = await M.checkinReject({
    eventKey: EVENT_KEY,
    regId,
    staffId: req.staff.staff_id,
    staffUsername: req.staff.username,
    reason,
  });

  res.json({ item });
}));

/* Games + presets (GAME staff) */
r.get("/games", requireAccess("can_game"), asyncHandler(async (_req, res) => {
  const items = await M.gamesActiveList({ eventKey: EVENT_KEY });
  res.json({ items });
}));

r.get("/games/:gameId/presets", requireAccess("can_game"), asyncHandler(async (req, res) => {
  const gameId = req.params.gameId;
  const items = await M.presetsActiveByGame({ eventKey: EVENT_KEY, gameId });
  res.json({ items });
}));

/* Transactions (GAME staff) */
r.post("/txns/debit", requireAccess("can_game"), asyncHandler(async (req, res) => {
  const b = req.body || {};
  const walletId = String(b.wallet_id || "").trim();
  const amount = Number(b.amount);
  const gameId = b.game_id || null;
  const actionId = String(b.action_id || "").trim();
  const reason = String(b.reason || "PLAY").trim();
  const note = b.note ? String(b.note).trim() : null;

  const item = await M.staffTxnApply({
    eventKey: EVENT_KEY,
    walletId,
    type: "DEBIT",
    amount,
    reason,
    note,
    gameId,
    presetId: null,
    currency: "TOKENS",
    actionId,
    staffId: req.staff.staff_id,
    staffUsername: req.staff.username,
    enforceCheckedIn: true,
  });

  res.json({ item });
}));

r.post("/txns/reward", requireAccess("can_game"), asyncHandler(async (req, res) => {
  const b = req.body || {};
  const walletId = String(b.wallet_id || "").trim();
  const amount = Number(b.amount);
  const gameId = b.game_id || null;
  const presetId = b.preset_id || null;
  const actionId = String(b.action_id || "").trim();
  const reason = String(b.reason || "REWARD").trim();
  const note = b.note ? String(b.note).trim() : null;

  const item = await M.staffTxnApply({
    eventKey: EVENT_KEY,
    walletId,
    type: "CREDIT",
    amount,
    reason,
    note,
    gameId,
    presetId,
    currency: "TICKETS",
    actionId,
    staffId: req.staff.staff_id,
    staffUsername: req.staff.username,
    enforceCheckedIn: true,
  });

  res.json({ item });
}));

r.post("/txns/prize-redeem", requireAccess("can_prize"), asyncHandler(async (req, res) => {
  const b = req.body || {};
  const walletId = String(b.wallet_id || "").trim();
  const amount = Number(b.amount);
  const actionId = String(b.action_id || "").trim();
  const reason = String(b.reason || "PRIZE_REDEMPTION").trim();
  const note = b.note ? String(b.note).trim() : null;

  const item = await M.staffTxnApply({
    eventKey: EVENT_KEY,
    walletId,
    type: "DEBIT",
    amount,
    reason,
    note,
    gameId: null,
    presetId: null,
    currency: "TICKETS",
    actionId,
    staffId: req.staff.staff_id,
    staffUsername: req.staff.username,
    enforceCheckedIn: true,
  });

  res.json({ item });
}));

// Backward-compatible alias for older clients that still call /txns/credit.
r.post("/txns/credit", requireAccess("can_game"), asyncHandler(async (req, res) => {
  const b = req.body || {};
  const walletId = String(b.wallet_id || "").trim();
  const amount = Number(b.amount);
  const gameId = b.game_id || null;
  const presetId = b.preset_id || null;
  const actionId = String(b.action_id || "").trim();
  const reason = String(b.reason || "REWARD").trim();
  const note = b.note ? String(b.note).trim() : null;

  const item = await M.staffTxnApply({
    eventKey: EVENT_KEY,
    walletId,
    type: "CREDIT",
    amount,
    reason,
    note,
    gameId,
    presetId,
    currency: "TICKETS",
    actionId,
    staffId: req.staff.staff_id,
    staffUsername: req.staff.username,
    enforceCheckedIn: true,
  });

  res.json({ item });
}));

export default r;
