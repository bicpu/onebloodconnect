const express      = require('express');
const router       = express.Router();
const authenticate = require('../middleware/auth');
const authorizeRoles = require('../middleware/authorizeRoles');
const BloodBank    = require('../models/BloodBank');

router.use(authenticate);

// ─── GET /blood-banks ─────────────────────────────────────────────────────────
// Returns all blood banks. Optional ?bloodGroup=O%2B to filter by stock.
router.get('/', async (req, res) => {
  try {
    const { bloodGroup } = req.query;
    let banks = await BloodBank.find().sort({ createdAt: -1 }).lean();

    // Filter by blood group if provided — only return banks with stock > 0
    if (bloodGroup) {
      banks = banks.filter(b => {
        const stock = b.stock || {};
        const qty = typeof stock.get === 'function'
          ? stock.get(bloodGroup)
          : stock[bloodGroup];
        return qty && qty > 0;
      });
    }

    // Convert Map to plain object for JSON serialisation
    banks = banks.map(b => ({
      ...b,
      stock: b.stock instanceof Map
        ? Object.fromEntries(b.stock)
        : (b.stock || {}),
    }));

    res.json(banks);
  } catch (err) {
    console.error('[BloodBank GET /]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── POST /blood-banks ────────────────────────────────────────────────────────
// Admin creates a new blood bank entry.
router.post('/', authorizeRoles('admin'), async (req, res) => {
  try {
    const { name, address, city, phone, hours, isVerified, stock } = req.body;

    if (!name) {
      return res.status(400).json({ error: 'name is required' });
    }

    const bank = await BloodBank.create({
      name:        name.trim(),
      address:     address    || '',
      city:        city       || '',
      phone:       phone      || '',
      hours:       hours      || '8:00 AM – 6:00 PM',
      isVerified:  isVerified !== false,
      stock:       stock      || {},
      manualEntry: true,
    });

    // Convert Map to plain object for response
    const bankObj = bank.toObject();
    bankObj.stock = bank.stock instanceof Map
      ? Object.fromEntries(bank.stock)
      : (bankObj.stock || {});

    res.status(201).json(bankObj);
  } catch (err) {
    console.error('[BloodBank POST /]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── DELETE /blood-banks/:id ──────────────────────────────────────────────────
// Admin removes a blood bank entry.
router.delete('/:id', authorizeRoles('admin'), async (req, res) => {
  try {
    const bank = await BloodBank.findByIdAndDelete(req.params.id);
    if (!bank) return res.status(404).json({ error: 'Blood bank not found' });
    res.json({ success: true });
  } catch (err) {
    console.error('[BloodBank DELETE /:id]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
