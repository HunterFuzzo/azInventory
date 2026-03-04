// ============================================================
// ESX Inventory – Dev Server
// Serves NUI files and provides mock API endpoints
// ============================================================

const express = require('express');
const path = require('path');

const app = express();
const PORT = 3000;

// Parse JSON bodies
app.use(express.json());

// Logging middleware
app.use((req, res, next) => {
    if (req.method === 'POST') {
        console.log(`\x1b[33m[POST]\x1b[0m ${req.path}`, JSON.stringify(req.body));
    }
    next();
});

// Serve the html/ directory as the root
app.use(express.static(path.join(__dirname, '..', 'html')));

// ─── Mock NUI Callbacks ──────────────────────────────────

app.post('/esx_inventory/closeInventory', (req, res) => {
    console.log('\x1b[36m[INV]\x1b[0m Inventory closed');
    res.json({ ok: true });
});

app.post('/esx_inventory/moveItem', (req, res) => {
    const { fromZone, toZone, fromSlot, toSlot } = req.body;
    console.log(`\x1b[32m[MOVE]\x1b[0m ${fromZone}[${fromSlot}] → ${toZone}[${toSlot}]`);
    res.json({ success: true });
});

app.post('/esx_inventory/useItem', (req, res) => {
    const { item, slot } = req.body;
    console.log(`\x1b[35m[USE]\x1b[0m Item: ${item} (slot ${slot})`);
    res.json({ success: true });
});

app.post('/esx_inventory/dropItem', (req, res) => {
    const { item, count } = req.body;
    console.log(`\x1b[31m[DROP]\x1b[0m Item: ${item} x${count}`);
    res.json({ success: true });
});

app.post('/esx_inventory/giveItem', (req, res) => {
    const { item, count } = req.body;
    console.log(`\x1b[34m[GIVE]\x1b[0m Item: ${item} x${count}`);
    res.json({ success: true });
});

app.post('/esx_inventory/setShortkey', (req, res) => {
    const { slot, item } = req.body;
    console.log(`\x1b[33m[SHORTKEY]\x1b[0m Slot ${slot}: ${item}`);
    res.json({ ok: true });
});

// Catch-all for any other NUI callbacks
app.post('/esx_inventory/:action', (req, res) => {
    console.log(`\x1b[90m[NUI]\x1b[0m ${req.params.action}`, req.body);
    res.json({ ok: true });
});

// ─── Start ────────────────────────────────────────────────
app.listen(PORT, () => {
    console.log('');
    console.log('\x1b[31m╔══════════════════════════════════════════╗\x1b[0m');
    console.log('\x1b[31m║\x1b[0m  ESX Inventory – Dev Server              \x1b[31m║\x1b[0m');
    console.log('\x1b[31m║\x1b[0m                                          \x1b[31m║\x1b[0m');
    console.log(`\x1b[31m║\x1b[0m  http://localhost:${PORT}                   \x1b[31m║\x1b[0m`);
    console.log('\x1b[31m║\x1b[0m  Press TAB to open inv.                  \x1b[31m║\x1b[0m');
    console.log('\x1b[31m║\x1b[0m  Press ESC to close.                     \x1b[31m║\x1b[0m');
    console.log('\x1b[31m╚══════════════════════════════════════════╝\x1b[0m');
    console.log('');
});
