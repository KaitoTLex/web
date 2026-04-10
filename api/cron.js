// Hourly cron — probes all services and writes the result to KV so the
// status timeline stays populated even when nobody is visiting the page.
let kv = null;
try {
  const mod = require('@vercel/kv');
  kv = mod.kv;
} catch (_) {}

const SERVICES = [
  'code.functor.systems',
  'matrix.functor.systems',
  'slop.kaitotlex.engineering',
  'yap.kaitotlex.systems',
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

function toHourKey(date) {
  return 'ws:' + date.toISOString().slice(0, 13);
}

module.exports = async function handler(req, res) {
  // Vercel automatically sets CRON_SECRET and adds it as Bearer auth on cron requests.
  const secret = process.env.CRON_SECRET;
  if (secret && req.headers.authorization !== `Bearer ${secret}`) {
    return res.status(401).json({ error: 'unauthorized' });
  }

  if (!kv) {
    return res.status(503).json({ error: 'KV not configured' });
  }

  const now = new Date();
  const hourKey = toHourKey(floorToHour(now));

  const statuses = {};
  await Promise.all(SERVICES.map(async (s) => {
    statuses[s] = await probe(s);
  }));

  // Store for 26 h so we can always retrieve the last 12 h of history
  await kv.set(hourKey, statuses, { ex: 26 * 3600 });

  res.status(200).json({ ok: true, key: hourKey, statuses });
};
