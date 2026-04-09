// Vercel KV is optional — falls back to current-only if not configured.
let kv = null;
try {
  const mod = require('@vercel/kv');
  kv = mod.kv;
} catch (_) {}

const SERVICES = [
  'code.functor.systems',
  'matrix.functor.systems',
  'slop.kaitotlex.engineering',
  'log.kaitotlex.systems',
  'missioncontrol.kaitotlex.systems',
  'functor.mit.edu',
];

async function probe(hostname) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8000);
  try {
    const r = await fetch(`https://${hostname}`, {
      method: 'HEAD',
      signal: controller.signal,
      redirect: 'follow',
    });
    clearTimeout(timer);
    // Treat anything that actually responds as online (even 4xx)
    return r.status < 500 ? 'online' : 'degraded';
  } catch {
    clearTimeout(timer);
    return 'offline';
  }
}

function floorToHour(date) {
  const d = new Date(date);
  d.setUTCMinutes(0, 0, 0);
  return d;
}

// Key format: "ws:2025-04-09T10" — one entry per UTC hour
function toHourKey(date) {
  return 'ws:' + date.toISOString().slice(0, 13);
}

async function probeAll() {
  const statuses = {};
  await Promise.all(SERVICES.map(async (s) => {
    statuses[s] = await probe(s);
  }));
  return statuses;
}

module.exports = async function handler(req, res) {
  const now = new Date();
  let history;

  if (kv) {
    // ── KV path: real 12-hour history ──────────────────────────────
    const currentHour = floorToHour(now);
    const currentKey = toHourKey(currentHour);

    let current = await kv.get(currentKey);
    if (!current) {
      current = await probeAll();
      // Store for 26 h so we can always retrieve last 12 h
      await kv.set(currentKey, current, { ex: 26 * 3600 });
    }

    // Build slot list, oldest first (index 0 = 11 h ago, index 11 = now)
    const slots = Array.from({ length: 12 }, (_, i) => {
      const t = floorToHour(new Date(now.getTime() - (11 - i) * 3_600_000));
      return { key: toHourKey(t), ts: t.toISOString() };
    });

    const vals = await Promise.all(slots.map(({ key }) => kv.get(key)));

    history = slots.map(({ ts }, i) => ({
      timestamp: ts,
      statuses: vals[i] ?? null,
    }));

    // Always overwrite the last slot with fresh data
    history[11] = { timestamp: currentHour.toISOString(), statuses: current };

  } else {
    // ── No KV: probe now, leave past slots null ─────────────────────
    const current = await probeAll();
    history = Array.from({ length: 12 }, (_, i) => {
      const t = floorToHour(new Date(now.getTime() - (11 - i) * 3_600_000));
      return {
        timestamp: t.toISOString(),
        statuses: i === 11 ? current : null,
      };
    });
  }

  // Cache at Vercel edge for 60 s; allow stale up to 5 min while revalidating
  res.setHeader('Cache-Control', 'public, s-maxage=60, stale-while-revalidate=300');
  res.status(200).json({ history });
};
