const DEFAULT_WINDOW_MS = 15 * 60 * 1000;
const DEFAULT_USER_MAX = 30;
const DEFAULT_IP_MAX = 300;

function positiveInteger(value, fallback) {
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function createDonorSearchRateLimit({
  windowMs = DEFAULT_WINDOW_MS,
  userMax = DEFAULT_USER_MAX,
  ipMax = DEFAULT_IP_MAX,
  now = Date.now,
} = {}) {
  const buckets = new Map();
  let requestsSinceCleanup = 0;

  function consume(key, limit, currentTime) {
    let bucket = buckets.get(key);
    if (!bucket || bucket.resetAt <= currentTime) {
      bucket = { count: 0, resetAt: currentTime + windowMs };
      buckets.set(key, bucket);
    }
    bucket.count += 1;
    return { allowed: bucket.count <= limit, resetAt: bucket.resetAt };
  }

  return function donorSearchRateLimit(req, res, next) {
    const currentTime = now();
    const uid = typeof req.uid === 'string' ? req.uid.trim() : '';
    // Express does not trust forwarded headers by default. req.ip therefore
    // uses the socket peer unless the application explicitly configures trust proxy.
    const ip = req.ip || req.socket?.remoteAddress || 'unknown';
    const userResult = uid ? consume(`uid:${uid}`, userMax, currentTime) : null;
    const ipResult = consume(`ip:${ip}`, ipMax, currentTime);

    requestsSinceCleanup += 1;
    if (requestsSinceCleanup >= 128) {
      for (const [key, bucket] of buckets) {
        if (bucket.resetAt <= currentTime) buckets.delete(key);
      }
      requestsSinceCleanup = 0;
    }

    const denied = [userResult, ipResult].filter((result) => result && !result.allowed);
    if (denied.length > 0) {
      const resetAt = Math.min(...denied.map((result) => result.resetAt));
      res.set('Retry-After', String(Math.max(1, Math.ceil((resetAt - currentTime) / 1000))));
      return res.status(429).json({ error: 'rate_limit_exceeded' });
    }
    return next();
  };
}

const donorSearchRateLimit = createDonorSearchRateLimit({
  windowMs: positiveInteger(process.env.DONOR_SEARCH_RATE_LIMIT_WINDOW_MS, DEFAULT_WINDOW_MS),
  userMax: positiveInteger(process.env.DONOR_SEARCH_RATE_LIMIT_USER_MAX, DEFAULT_USER_MAX),
  ipMax: positiveInteger(process.env.DONOR_SEARCH_RATE_LIMIT_IP_MAX, DEFAULT_IP_MAX),
});

module.exports = donorSearchRateLimit;
module.exports.createDonorSearchRateLimit = createDonorSearchRateLimit;
