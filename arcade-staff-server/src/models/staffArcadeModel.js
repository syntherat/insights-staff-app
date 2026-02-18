import { pool } from "../config/db.js";

function signed(type, amount) {
  const a = Math.abs(Number(amount));
  if (type === "CREDIT") return +a;
  if (type === "DEBIT") return -a;
  throw new Error("type must be CREDIT or DEBIT");
}

/** Lookup wallet + linked registration details (for Gate + Game) */
export async function walletLookupByCode({ eventKey, code }) {
  const { rows } = await pool.query(
    `
    SELECT
      w.id AS wallet_id,
      w.wallet_code,
      w.balance,
      w.reward_points_balance,
      w.event_key,
      w.member_id,

      r.id AS reg_id,
      r.category,
      r.status AS reg_status,
      r.checkin_status,
      r.checkin_at,
      r.reject_reason,

      -- If this wallet belongs to a member, get member's details
      -- Otherwise get registration holder's details
      COALESCE(m.name, r.name) AS name,
      COALESCE(m.email, r.email) AS email,
      COALESCE(m.contact, r.contact) AS contact,
      COALESCE(m.reg_no, r.reg_no) AS reg_no,

      p.code AS plan_code,
      p.title AS plan_title
    FROM arcade_wallets w
    JOIN arcade_registrations r ON r.id = w.registration_id
    LEFT JOIN arcade_registration_members m ON m.id = w.member_id
    LEFT JOIN arcade_plans p ON p.id = r.plan_id
    WHERE w.event_key=$1 AND w.wallet_code=$2
    LIMIT 1;
    `,
    [eventKey, code]
  );
  
  return rows[0] || null;
}

/** Get team members for a registration (from arcade_registration_members table) */
export async function getTeamMembers({ eventKey, regId, excludeMemberId }) {
  const { rows } = await pool.query(
    `
    SELECT
      m.id AS member_id,
      m.name,
      m.contact,
      m.reg_no,
      m.email,
      m.position,
      w.wallet_code,
      w.balance,
      w.reward_points_balance,
      false as is_primary,
      -- Check-in status: if member has wallet, check that wallet's registration status
      -- Otherwise show NULL
      CASE 
        WHEN w.id IS NOT NULL THEN (
          SELECT checkin_status 
          FROM arcade_registrations 
          WHERE id = m.registration_id
        )
        ELSE NULL
      END as checkin_status
    FROM arcade_registration_members m
    LEFT JOIN arcade_wallets w ON w.member_id = m.id AND w.event_key = $1
    WHERE m.registration_id = $2
      AND m.event_key = $1
      AND ($3::uuid IS NULL OR m.id != $3::uuid)
    ORDER BY m.position ASC;
    `,
    [eventKey, regId, excludeMemberId || null]
  );
  
  return rows;
}

/** Get primary registrant for a team (registration holder) */
export async function getPrimaryRegistrant({ eventKey, regId }) {
  const { rows } = await pool.query(
    `
    SELECT
      NULL::uuid AS member_id,
      r.name,
      r.contact,
      r.reg_no,
      r.email,
      0 AS position,
      w.wallet_code,
      w.balance,
      w.reward_points_balance,
      true as is_primary,
      r.checkin_status
    FROM arcade_registrations r
    LEFT JOIN arcade_wallets w ON w.registration_id = r.id AND w.member_id IS NULL AND w.event_key = $1
    WHERE r.id = $2 AND r.event_key = $1
    LIMIT 1;
    `,
    [eventKey, regId]
  );

  return rows[0] || null;
}

/** Gate approves check-in */
export async function checkinApprove({ eventKey, regId, staffId, staffUsername }) {
  const { rows } = await pool.query(
    `
    UPDATE arcade_registrations
    SET
      checkin_status='CHECKED_IN',
      checkin_at=now(),
      checkin_by_username=$3::text,
      updated_at=now()
    WHERE id=$2 AND event_key=$1
    RETURNING *;
    `,
    [eventKey, regId, staffUsername || null]
  );

  const item = rows[0] || null;

  if (item) {
await pool.query(
  `
  INSERT INTO arcade_staff_audit_events(event_key, staff_id, staff_username, action, entity_id, meta)
  VALUES (
    $1,
    $2,
    $3::text,
    'CHECKIN_APPROVE',
    $4::uuid,
    jsonb_build_object('reg_id', $4::uuid)
  );
  `,
  [eventKey, staffId, staffUsername || "", regId]
);

  }

  return item;
}
/** Gate rejects check-in */
export async function checkinReject({ eventKey, regId, staffId, staffUsername, reason }) {
  // make sure it's string or null, but never "undefined"
  const safeReason = reason == null ? "" : String(reason);
  
console.log("checkinReject HIT", { reason, type: typeof reason });
  const { rows } = await pool.query(
    `
    UPDATE arcade_registrations
    SET
      checkin_status = 'REJECTED',
      reject_reason  = NULLIF($4::text, ''),
      rejected_at    = now(),
      rejected_by    = $3,
      updated_at     = now()
    WHERE id=$2 AND event_key=$1
    RETURNING *;
    `,
    [eventKey, regId, staffId, safeReason]
  );

  const item = rows[0] || null;
  

  if (item) {
await pool.query(
  `
  INSERT INTO arcade_staff_audit_events(event_key, staff_id, staff_username, action, entity_id, meta)
  VALUES (
    $1,
    $2,
    $3::text,
    'CHECKIN_REJECT',
    $4::uuid,
    jsonb_build_object('reg_id', $4::uuid, 'reason', NULLIF($5::text,''))
  );
  `,
  [eventKey, staffId, staffUsername || "", regId, safeReason]
);

  }

  return item;
}

/** List active games (for GAME staff) */
export async function gamesActiveList({ eventKey }) {
  const { rows } = await pool.query(
    `
    SELECT id, name, default_debit_amount, allowed_debit_amounts
    FROM arcade_games
    WHERE event_key=$1 AND is_active=true
    ORDER BY name ASC;
    `,
    [eventKey]
  );
  return rows;
}

/** List active presets by game (for credit buttons) */
export async function presetsActiveByGame({ eventKey, gameId }) {
  const { rows } = await pool.query(
    `
    SELECT id, game_id, label, amount, currency
    FROM arcade_reward_presets
    WHERE event_key=$1 AND game_id=$2 AND is_active=true AND currency='TICKETS'
    ORDER BY sort_order ASC, label ASC;
    `,
    [eventKey, gameId]
  );
  return rows;
}

/** Recent transactions (context) */
export async function walletRecentTxns({ eventKey, walletId, limit = 3 }) {
  const { rows } = await pool.query(
    `
    SELECT id, created_at, type, amount, reason, balance_after, actor_username, game_id, currency
    FROM arcade_wallet_txns
    WHERE event_key=$1 AND wallet_id=$2
    ORDER BY created_at DESC
    LIMIT $3;
    `,
    [eventKey, walletId, limit]
  );
  return rows;
}

/**
 * Apply a staff transaction (DEBIT/CREDIT).
 * Guardrails:
 * - requires action_id idempotency
 * - can enforce checked-in requirement
 */
export async function staffTxnApply({
  eventKey,
  walletId,
  type,            // CREDIT/DEBIT
  amount,          // positive number
  reason,          // string required
  note,            // optional
  gameId,          // optional but recommended for GAME
  presetId,        // optional (if credit via preset)
  currency = "TOKENS", // TOKENS | TICKETS
  actionId,        // required for safety
  staffId,
  staffUsername,
  enforceCheckedIn = true,
}) {
  if (!["CREDIT", "DEBIT"].includes(type)) throw new Error("Invalid type");
  if (!Number.isFinite(amount) || Number(amount) <= 0) throw new Error("amount must be > 0");
  if (!["TOKENS", "TICKETS"].includes(currency)) throw new Error("Invalid currency");
  if (!actionId) throw new Error("action_id required");
  if (!reason || !String(reason).trim()) throw new Error("reason required");

  const delta = signed(type, amount);
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // idempotency
    const ex = await client.query(
      `SELECT * FROM arcade_wallet_txns WHERE event_key=$1 AND action_id=$2 LIMIT 1;`,
      [eventKey, actionId]
    );
    if (ex.rows[0]) {
      await client.query("COMMIT");
      return ex.rows[0];
    }

    // lock wallet
    const wq = await client.query(
      `SELECT id, balance, reward_points_balance, registration_id FROM arcade_wallets WHERE id=$1 AND event_key=$2 FOR UPDATE;`,
      [walletId, eventKey]
    );
    const w = wq.rows[0];
    if (!w) throw new Error("wallet not found");

    // checked-in guard
    if (enforceCheckedIn) {
      const rq = await client.query(
        `SELECT checkin_status FROM arcade_registrations WHERE id=$1 AND event_key=$2 LIMIT 1;`,
        [w.registration_id, eventKey]
      );
      const st = rq.rows[0]?.checkin_status;
      if (st !== "CHECKED_IN") throw new Error(`Not checked-in (status=${st || "unknown"})`);
    }

    const currentBalance =
      currency === "TICKETS" ? Number(w.reward_points_balance || 0) : Number(w.balance || 0);
    const nextBalance = currentBalance + delta;
    if (nextBalance < 0) throw new Error("Insufficient balance");

    if (currency === "TICKETS") {
      await client.query(
        `UPDATE arcade_wallets SET reward_points_balance=$2, updated_at=now() WHERE id=$1;`,
        [walletId, nextBalance]
      );
    } else {
      await client.query(
        `UPDATE arcade_wallets SET balance=$2, updated_at=now() WHERE id=$1;`,
        [walletId, nextBalance]
      );
    }

    const reasonFull = note ? `${String(reason).trim()} — ${String(note).trim()}` : String(reason).trim();

    const ins = await client.query(
      `
      INSERT INTO arcade_wallet_txns (
        wallet_id, type, amount, reason,
        actor_type, actor_id,
        event_key, game_id, preset_id,
        action_id, reversed_txn_id,
        balance_after,
        actor_username,
        currency
      )
      VALUES ($1,$2,$3,$4,'STAFF',$5,$6,$7,$8,$9,NULL,$10,$11,$12)
      RETURNING *;
      `,
      [
        walletId,
        type,
        Math.abs(Number(amount)),
        reasonFull,
        staffId || null,
        eventKey,
        gameId || null,
        presetId || null,
        actionId,
        nextBalance,
        staffUsername || null,
        currency
      ]
    );

    await client.query("COMMIT");
    return ins.rows[0];
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
}
