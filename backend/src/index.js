require('dotenv').config();

const express = require('express');
const cors    = require('cors');

const connectDB       = require('./config/db');
const { initFirebase } = require('./config/firebase');

const donorRoutes            = require('./routes/donors');
const bloodRequestRoutes     = require('./routes/bloodRequests');
const bookingRoutes          = require('./routes/bookings');
const bloodBankRoutes        = require('./routes/bloodBanks');
const adminRoutes            = require('./routes/admin');
const donorRequestRoutes     = require('./routes/donorRequests');
const bloodBankAccountRoutes = require('./routes/bloodBankAccounts');

// ── Express app ────────────────────────────────────────────────────────────────
const app = express();

app.use(cors());
app.use(express.json({ limit: '8mb' }));

// ── Health check ───────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// ── API routes ─────────────────────────────────────────────────────────────────
app.use('/donors',               donorRoutes);
app.use('/blood-requests',       bloodRequestRoutes);
app.use('/bookings',             bookingRoutes);
app.use('/blood-banks',          bloodBankRoutes);
app.use('/admin',                adminRoutes);
app.use('/donor-requests',       donorRequestRoutes);
app.use('/blood-bank-accounts',  bloodBankAccountRoutes);

// ── 404 handler ────────────────────────────────────────────────────────────────
app.use((_req, res) => res.status(404).json({ error: 'Not found' }));

// ── Global error handler ───────────────────────────────────────────────────────
app.use((err, _req, res, _next) => {
  console.error('[Unhandled]', err);
  res.status(500).json({ error: 'Internal server error' });
});

// ── Start server ───────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;

async function startServer() {
  initFirebase();
  await connectDB();
  app.listen(PORT, () => {
    console.log(`[Server] Listening on port ${PORT}`);
  });
}

startServer().catch((err) => {
  console.error('[Server] Startup failed:', err);
  process.exit(1);
});
