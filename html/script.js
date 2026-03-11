/* ============================================================
   AZ Inventory – GLife Extinction Style
   Client-side NUI Script
   ============================================================ */

(() => {
    'use strict';

    // ─── State ────────────────────────────────────────────────
    const state = {
        isOpen: false,
        bagItems: [],
        containerItems: [],
        shortkeyItems: [null, null, null, null, null, null],
        maxWeight: 1000,
        containerMaxWeight: 50,
        selectedSlot: null,
        contextTarget: null,
        lastAction: null,
        containerType: 'protected', // 'protected' or 'stash'
        currentTab: 'inventory',
        shopItems: [],
        shopSearchQuery: '',
        shopFilter: 'all',
        autoReload: false,
    };

    let _globalDragClone = null;
    let _globalMouseHandler = null;

    // ─── DOM References ───────────────────────────────────────
    const $ = (sel) => document.querySelector(sel);
    const $$ = (sel) => document.querySelectorAll(sel);

    const dom = {
        container: $('#inventory-container'),
        bagGrid: $('#bag-grid'),
        containerGrid: $('#container-grid'),
        shortkeysSlots: $('#shortkeys-slots'),
        weightCurrent: $('#weight-current'),
        weightMax: $('#weight-max'),
        weightBarFill: $('#weight-bar-fill'),
        containerWeightCurrent: $('#container-weight-current'),
        containerWeightMax: $('#container-weight-max'),
        containerLabel: $('#container-label'),
        contextMenu: $('#context-menu'),
        tooltip: $('#item-tooltip'),
        tooltipName: $('#tooltip-name'),
        tooltipDesc: $('#tooltip-desc'),
        tooltipWeight: $('#tooltip-weight'),
        tooltipQty: $('#tooltip-qty'),
        playerName: $('#player-name'),
        playerId: $('#player-id'),
        money: $('#player-money'),
        shopGrid: $('#shop-grid'),
        sectionBag: $('#section-bag'),
        sectionContainer: $('#section-container'),
        sectionHotbar: $('#section-hotbar'),
        sectionShop: $('#section-shop'),
        sectionProfile: $('#section-profile'),
        sidebarItems: $$('.sidebar-item'),
    };

    // ─── Test Mode Detection ──────────────────────────────────
    const isTestMode = typeof GetParentResourceName === 'undefined';
    const resourceName = isTestMode ? 'az_inventory' : GetParentResourceName();

    // ─── Mock Data (Test Mode) ────────────────────────────────
    const MOCK_ITEMS = [
        // 🔫 Weapons
        { name: 'awp', label: 'AWP', count: 1, weight: 6.0, description: 'High-power sniper rifle.' },
        { name: 'awp_mk2', label: 'AWP MK2', count: 1, weight: 0.5, description: 'Upgraded high-power sniper rifle.' },
        { name: 'carbine', label: 'Carbine', count: 1, weight: 3.5, description: 'Standard assault rifle.' },
        // { name: 'carbine_mk2', label: 'Carbine MK2', count: 1, weight: 3.8, description: 'Upgraded assault rifle.' },
        // { name: 'ak47', label: 'AK-47', count: 1, weight: 4.3, description: 'Reliable assault rifle.' }, 
        // { name: 'm4a1', label: 'M4A1', count: 1, weight: 3.6, description: 'Versatile assault rifle.' },
        // { name: 'famas', label: 'Famas', count: 1, weight: 3.7, description: 'Bullpup assault rifle.' },
        // { name: 'scar', label: 'SCAR', count: 1, weight: 4.0, description: 'Heavy assault rifle.' },
        // { name: 'sniper', label: 'Sniper Rifle', count: 1, weight: 5.5, description: 'Long-range precision rifle.' },
        // { name: 'sniper_mk2', label: 'Sniper Rifle MK2', count: 1, weight: 5.8, description: 'Upgraded precision rifle.' },
        // { name: 'smg', label: 'SMG', count: 1, weight: 2.5, description: 'Submachine gun.' },
        // { name: 'smg_mk2', label: 'SMG MK2', count: 1, weight: 2.8, description: 'Upgraded submachine gun.' },
        // { name: 'micro_smg', label: 'Micro SMG', count: 1, weight: 1.5, description: 'Compact submachine gun.' },
        // { name: 'pistol', label: 'Pistol', count: 1, weight: 1.0, description: 'Standard handgun.' },
        // { name: 'pistol_mk2', label: 'Pistol MK2', count: 1, weight: 1.2, description: 'Upgraded handgun.' },
        // { name: 'desert_eagle', label: 'Desert Eagle', count: 1, weight: 2.0, description: 'High-caliber handgun.' },
        // { name: 'revolver', label: 'Revolver', count: 1, weight: 1.8, description: 'Heavy six-shooter.' },
        // { name: 'shotgun', label: 'Shotgun', count: 1, weight: 4.0, description: 'Pump-action shotgun.' },
        // { name: 'shotgun_mk2', label: 'Shotgun MK2', count: 1, weight: 4.5, description: 'Upgraded shotgun.' },
        // { name: 'machine_gun', label: 'Machine Gun', count: 1, weight: 8.0, description: 'Heavy machine gun.' },

        { name: 'green_syringe', label: 'Green Syringe', count: 5, weight: 0.1, description: 'Medical stimulant.' },
        { name: 'red_syringe', label: 'Red Syringe', count: 5, weight: 0.1, description: 'Combat stimulant.' },
        { name: 'blue_syringe', label: 'Blue Syringe', count: 5, weight: 0.1, description: 'Stamina boost.' },

        // 🚗 Vehicles
        { name: 'deluxo', label: 'Deluxo', count: 1, weight: 20.0, description: 'A flying car from the future.' }
    ];

    const MOCK_CONTAINER = [
        { name: 'bandage', label: 'Bandage', count: 10, weight: 0.1, description: 'Heals minor injuries.' },
        { name: 'medkit', label: 'Medkit', count: 3, weight: 1.0, description: 'Restores full health.' },
        { name: 'kevlar', label: 'Kevlar', count: 1, weight: 2.0, description: 'Standard body armor.' },
    ];

    // ─── NUI Communication ────────────────────────────────────
    function postNUI(event, data = {}) {
        if (isTestMode) {
            console.log(`[NUI → Lua] ${event}`, data);
            // Simulate server response for test mode
            if (event === 'closeInventory') {
                closeInventory();
            }
            return Promise.resolve({ ok: true });
        }
        return fetch(`https://${resourceName}/${event}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
    }

    // ─── Image Path ───────────────────────────────────────────
    function getItemImagePath(itemName) {
        if (isTestMode) {
            return `img/items/${itemName}.png`;
        }
        return `nui://${resourceName}/html/img/items/${itemName}.png`;
    }

    // ─── Weight Calculation ───────────────────────────────────
    function calculateWeight(items) {
        return items.reduce((total, item) => {
            if (!item) return total;
            return total + (item.weight || 0) * (item.count || 1);
        }, 0);
    }

    function formatPrice(num) {
        if (!num) return '0$';
        const val = Number(num);
        if (val >= 1000000000) return (val / 1000000000).toFixed(1).replace(/\.0$/, '') + 'B$';
        if (val >= 1000000) return (val / 1000000).toFixed(1).replace(/\.0$/, '') + 'M$';
        if (val >= 1000) return (val / 1000).toFixed(1).replace(/\.0$/, '') + 'k$';
        return val + '$';
    }

    function updateWeightDisplay() {
        const bagWeight = calculateWeight(state.bagItems);
        const pct = Math.min((bagWeight / state.maxWeight) * 100, 100);

        dom.weightCurrent.textContent = bagWeight.toFixed(1);
        dom.weightMax.textContent = state.maxWeight;
        if (dom.weightBarFill) dom.weightBarFill.style.width = pct + '%';

        // Container weight
        const containerWeight = calculateWeight(state.containerItems);
        if (dom.containerWeightCurrent) {
            dom.containerWeightCurrent.textContent = containerWeight.toFixed(1);
        }
        if (dom.containerWeightMax) {
            if (state.containerMaxWeight === '∞') {
                dom.containerWeightMax.textContent = '∞';
            } else {
                dom.containerWeightMax.textContent = state.containerMaxWeight;
            }
        }
    }

    function canFitItem(itemName, toZone) {
        if (toZone !== 'bag' && toZone !== 'container') return true;

        const allItems = [...MOCK_ITEMS, ...state.bagItems, ...state.containerItems];
        const itemDef = allItems.find(i => i && i.name === itemName);
        if (!itemDef) return true;

        if (toZone === 'bag') {
            return calculateWeight(state.bagItems) + (itemDef.weight || 0) <= state.maxWeight;
        } else if (toZone === 'container') {
            if (state.containerMaxWeight === '∞') return true;
            return calculateWeight(state.containerItems) + (itemDef.weight || 0) <= state.containerMaxWeight;
        }
        return true;
    }

    function moveOneItem(itemName, fromArray, toArray) {
        const fromIdx = fromArray.findIndex(i => i && i.name === itemName);
        if (fromIdx !== -1) {
            const item = fromArray[fromIdx];

            const toIdx = toArray.findIndex(i => i && i.name === itemName);
            if (toIdx !== -1) {
                toArray[toIdx].count += 1;
            } else {
                toArray.push({ ...item, count: 1 });
            }

            item.count -= 1;
            if (item.count <= 0) {
                fromArray.splice(fromIdx, 1);
                return true; // indicates the item stack was fully depleted
            }
        }
        return false;
    }

    // ─── Render Items ─────────────────────────────────────────
    function createItemSlot(item, zone, index) {
        const slot = document.createElement('div');
        slot.className = 'item-slot' + (item ? '' : ' empty');
        slot.dataset.zone = zone;
        slot.dataset.index = index;

        if (item) {
            slot.dataset.itemName = item.name;
            if (item.id) slot.dataset.id = item.id;
            slot.innerHTML = `
                <img class="item-image" src="${getItemImagePath(item.name)}" alt="${item.label}" 
                     onerror="this.src='data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 width=%2248%22 height=%2248%22 viewBox=%220 0 24 24%22 fill=%22none%22 stroke=%22%23616161%22 stroke-width=%221.5%22><rect x=%222%22 y=%222%22 width=%2220%22 height=%2220%22 rx=%222%22/><line x1=%222%22 y1=%222%22 x2=%2222%22 y2=%2222%22/><line x1=%2222%22 y1=%222%22 x2=%222%22 y2=%2222%22/></svg>'">
                <div class="item-info">
                    <span class="item-name">${item.label}</span>
                    <div class="item-meta">
                        <span class="item-count">x${item.count}</span>
                        <span>${(item.weight * item.count).toFixed(1)}kg</span>
                    </div>
                </div>
            `;


            // Context menu
            slot.addEventListener('contextmenu', (e) => {
                e.preventDefault();
                showContextMenu(e, item, zone, index);
            });

            // Seller name for shop
            if (zone === 'shop' && item.sellerName) {
                const seller = document.createElement('div');
                seller.className = 'item-seller';
                seller.textContent = `Sold by: ${item.sellerName}`;
                slot.appendChild(seller);
            }
        }

        return slot;
    }

    function renderBag() {
        if (state.currentTab !== 'inventory' && state.currentTab !== 'shop') return;
        const frag = document.createDocumentFragment();
        for (let i = 0; i < state.bagItems.length; i++) {
            const item = state.bagItems[i];
            if (item) {
                frag.appendChild(createItemSlot(item, 'bag', i));
            }
        }
        dom.bagGrid.replaceChildren(frag);
        updateWeightDisplay();
    }
    function renderContainer() {
        const frag = document.createDocumentFragment();

        let totalVisibleSlots = 12; // 6 cols * 2 rows max display without scroll
        if (state.containerType === 'stash') {
            totalVisibleSlots = 18; // Bigger stash mode layout
            dom.containerGrid.classList.add('scroll-active'); // Always scrollable in stash
        } else {
            // If items exceed 2 lines (12 slots), make it scrollable dynamically
            if (state.containerItems.length > 12) {
                totalVisibleSlots = Math.ceil(state.containerItems.length / 6) * 6; // Fill last line
                dom.containerGrid.classList.add('scroll-active');
            } else {
                dom.containerGrid.classList.remove('scroll-active');
            }
        }

        // On affiche uniquement les items réels à la suite (Index dynamique)
        state.containerItems.forEach((item, i) => {
            if (item) {
                frag.appendChild(createItemSlot(item, 'container', i));
            }
        });

        // On remplit le reste avec des slots vides jusqu'au totalVisibleSlots minimum
        for (let i = state.containerItems.length; i < totalVisibleSlots; i++) {
            const emptySlot = document.createElement('div');
            emptySlot.className = 'item-slot empty';
            emptySlot.dataset.zone = 'container';
            emptySlot.dataset.index = i;
            frag.appendChild(emptySlot);
        }

        dom.containerGrid.replaceChildren(frag);
    }

    function renderShortkeys() {
        const frag = document.createDocumentFragment();

        for (let i = 0; i < 6; i++) {
            const item = state.shortkeyItems[i];

            // Check if shortkey item really exists in the bag (if not, it's a ghost)
            let isGhost = false;
            if (item) {
                const inBag = state.bagItems.find(b => b && b.name === item.name);
                if (!inBag) {
                    isGhost = true;
                }
            }

            const slot = document.createElement('div');
            slot.className = 'shortkey-slot' + (item && !isGhost ? ' has-item' : '') + (isGhost ? ' ghost-item' : '');
            slot.dataset.zone = 'shortkey';
            slot.dataset.index = i;

            let inner = `<span class="shortkey-number">${i + 1}</span>`;
            if (item) {
                // Set dataset.itemName even for ghosts so they can be dragged/cleared.
                slot.dataset.itemName = item.name;
                inner += `
                    <img class="item-image" src="${getItemImagePath(item.name)}" alt="${item.label}"
                         onerror="this.src='data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 width=%2232%22 height=%2232%22 viewBox=%220 0 24 24%22 fill=%22none%22 stroke=%22%23616161%22 stroke-width=%221.5%22><rect x=%222%22 y=%222%22 width=%2220%22 height=%2220%22 rx=%222%22/></svg>'">
                    ${!isGhost ? `<span class="item-name">${item.label}</span>` : ''}
                `;

                slot.innerHTML = inner;

                if (!isGhost) {
                    // Click: move item to container
                    slot.addEventListener('click', () => {
                        if (!canFitItem(item.name, 'container')) return;
                        const depleted = moveOneItem(item.name, state.bagItems, state.containerItems);
                        if (depleted) {
                            state.shortkeyItems[i] = null;
                            postNUI('setShortkey', { slot: i, item: null });
                        }
                        state.lastAction = { fromZone: 'bag', toZone: 'container' };
                        postNUI('moveItem', { fromZone: 'bag', toZone: 'container', item: item.name, count: 1, containerType: state.containerType });
                        renderAll();
                    });
                }
            } else {
                slot.innerHTML = inner;
            }

            frag.appendChild(slot);
        }
        dom.shortkeysSlots.replaceChildren(frag);
    }

    function renderShop() {
        if (state.currentTab !== 'shop') return;
        const frag = document.createDocumentFragment();

        // Filter items
        let filtered = state.shopItems;

        // Search
        if (state.shopSearchQuery && state.shopSearchQuery.trim() !== '') {
            const query = state.shopSearchQuery.toLowerCase();
            filtered = filtered.filter(it =>
                it.label.toLowerCase().includes(query) ||
                it.name.toLowerCase().includes(query)
            );
        }

        // Category Filter
        if (state.shopFilter !== 'all') {
            filtered = filtered.filter(it => {
                if (state.shopFilter === 'mysell') return it.isMine;

                const name = it.name.toUpperCase();
                switch (state.shopFilter) {
                    case 'weapon': return name.startsWith('WEAPON_');
                    case 'ammo': return name.startsWith('AMMO_');
                    case 'medical': return name.includes('MEDKIT') || name.includes('BANDAGE') || name.includes('SYRINGE') || name.includes('KEVLAR');
                    case 'other': return !name.startsWith('WEAPON_') && !name.startsWith('AMMO_') && !name.includes('MEDKIT') && !name.includes('BANDAGE') && !name.includes('SYRINGE') && !name.includes('KEVLAR');
                    default: return true;
                }
            });
        }

        if (filtered.length === 0) {
            const empty = document.createElement('div');
            empty.className = 'empty-shop-message';
            empty.textContent = (state.shopItems.length === 0) ? 'Marketplace is empty.' : 'No items matching your search.';
            frag.appendChild(empty);
        } else {
            filtered.forEach((item, i) => {
                const slot = createItemSlot(item, 'shop', i);
                if (item.id) slot.dataset.id = item.id;

                const price = document.createElement('div');
                price.className = 'item-price';
                price.textContent = formatPrice(item.price);
                slot.appendChild(price);
                frag.appendChild(slot);
            });
        }
        dom.shopGrid.replaceChildren(frag);
    }

    function renderProfile(data) {
        if (!data) return;

        // Personal Stats
        const nameEl = $('#profile-name');
        const idEl = $('#profile-id');
        if (nameEl) nameEl.textContent = data.name || state.playerName || 'Unknown';
        if (idEl) idEl.textContent = `ID: ${data.id || state.playerId || 0}`;

        const killsEl = $('#stat-kills');
        const deathsEl = $('#stat-deaths');
        const kdaEl = $('#stat-kda');
        const assistsEl = $('#stat-assists');
        const confirmedEl = $('#stat-kill-confirmed');

        if (killsEl) killsEl.textContent = data.kills || 0;
        if (deathsEl) deathsEl.textContent = data.deaths || 0;
        if (kdaEl) kdaEl.textContent = (data.kills / Math.max(1, data.deaths)).toFixed(2);
        if (assistsEl) assistsEl.textContent = data.assists || 0;
        if (confirmedEl) confirmedEl.textContent = data.kill_confirmed || 0;

        // Leaderboard
        const tbody = $('#leaderboard-body');
        if (!tbody) return;
        tbody.innerHTML = '';

        if (data.leaderboard && data.leaderboard.length > 0) {
            data.leaderboard.forEach((user, index) => {
                const tr = document.createElement('tr');
                const kda = (user.kills / Math.max(1, user.deaths)).toFixed(2);
                tr.innerHTML = `
                    <td>${index + 1}</td>
                    <td>${user.name}</td>
                    <td>${user.kills}</td>
                    <td>${kda}</td>
                `;
                tbody.appendChild(tr);
            });
        } else {
            const tr = document.createElement('tr');
            tr.innerHTML = `<td colspan="4" style="text-align:center; padding: 20px; color: var(--text-muted); font-size: 11px;">No rankings available yet.</td>`;
            tbody.appendChild(tr);
        }
    }

    function renderAll() {
        const wrapper = $('.sections-wrapper');

        // Visibility management
        dom.sectionBag.classList.toggle('hidden', state.currentTab === 'profile');
        dom.sectionProfile.classList.toggle('hidden', state.currentTab !== 'profile');

        if (state.currentTab === 'inventory') {
            wrapper.classList.remove('shop-mode');
            dom.sectionContainer.classList.remove('hidden');
            dom.sectionHotbar.classList.remove('hidden');
            dom.sectionShop.classList.add('hidden');

            renderBag();
            renderContainer();
            renderShortkeys();
        } else if (state.currentTab === 'shop') {
            wrapper.classList.add('shop-mode');
            dom.sectionContainer.classList.add('hidden');
            dom.sectionHotbar.classList.add('hidden');
            dom.sectionShop.classList.remove('hidden');

            renderBag();
            renderShop();
        } else if (state.currentTab === 'profile') {
            wrapper.classList.remove('shop-mode');
            dom.sectionContainer.classList.add('hidden');
            dom.sectionHotbar.classList.add('hidden');
            dom.sectionShop.classList.add('hidden');
        }

        if (!window.__dragInited) {
            initNativeDragAndDrop();
            window.__dragInited = true;
        }
    }

    // ─── Tooltip ──────────────────────────────────────────────
    function showTooltip(e, item) {
        dom.tooltipName.textContent = item.label;
        dom.tooltipDesc.textContent = item.description || '';
        dom.tooltipWeight.textContent = `Weight: ${(item.weight * item.count).toFixed(1)} kg`;
        dom.tooltipQty.textContent = `Qty: ${item.count}`;
        dom.tooltip.classList.remove('hidden');
        moveTooltip(e);
    }

    function moveTooltip(e) {
        const tooltip = dom.tooltip;
        let x = e.clientX + 16;
        let y = e.clientY + 12;

        // Keep on screen
        const rect = tooltip.getBoundingClientRect();
        if (x + rect.width > window.innerWidth) x = e.clientX - rect.width - 8;
        if (y + rect.height > window.innerHeight) y = e.clientY - rect.height - 8;

        tooltip.style.left = x + 'px';
        tooltip.style.top = y + 'px';
    }

    function hideTooltip() {
        dom.tooltip.classList.add('hidden');
    }

    // ─── Context Menu ─────────────────────────────────────────
    function showContextMenu(e, item, zone, index) {
        e.preventDefault();
        state.contextTarget = { item, zone, index };

        // Populate info section
        const infoName = document.getElementById('ctx-info-name');
        const infoDesc = document.getElementById('ctx-info-desc');
        const infoWeight = document.getElementById('ctx-info-weight');
        const infoQty = document.getElementById('ctx-info-qty');
        if (infoName) infoName.textContent = item.label;
        if (infoDesc) infoDesc.textContent = item.description || '';
        if (infoWeight) infoWeight.textContent = `Weight: ${(item.weight * item.count).toFixed(1)} kg`;
        if (infoQty) infoQty.textContent = `Qty: ${item.count}`;

        const menu = dom.contextMenu;

        // Hide/Show action buttons based on zone
        const actionItems = menu.querySelectorAll('.context-menu-item');
        const sellBtn = document.getElementById('ctx-sell-btn');
        const buyBtn = document.getElementById('ctx-buy-btn');
        const removeBtn = document.getElementById('ctx-remove-btn');

        if (zone === 'container') {
            actionItems.forEach(el => el.style.display = 'none');
            const divider = menu.querySelector('.ctx-divider');
            if (divider) divider.style.display = 'none';
        } else if (zone === 'shop') {
            actionItems.forEach(el => el.style.display = 'none');
            const divider = menu.querySelector('.ctx-divider');
            if (divider) divider.style.display = 'block'; // Always show divider in shop for info

            if (buyBtn) buyBtn.style.display = (!item.isMine) ? 'flex' : 'none';
            if (removeBtn) removeBtn.style.display = (item.isMine) ? 'flex' : 'none';
            if (sellBtn) sellBtn.style.display = 'none';
        } else {
            actionItems.forEach(el => {
                if (el.id !== 'ctx-remove-btn') el.style.display = 'flex';
                else el.style.display = 'none';
            });
            const divider = menu.querySelector('.ctx-divider');
            if (divider) divider.style.display = 'block';

            if (removeBtn) removeBtn.style.display = 'none';
            if (buyBtn) buyBtn.style.display = 'none';
            // Only show sell button in shop tab
            if (sellBtn) sellBtn.style.display = (state.currentTab === 'shop') ? 'flex' : 'none';
        }

        menu.classList.remove('hidden');

        let x = e.clientX;
        let y = e.clientY;
        // Adjust positioning after render
        requestAnimationFrame(() => {
            const rect = menu.getBoundingClientRect();
            if (x + rect.width > window.innerWidth) x -= rect.width;
            if (y + rect.height > window.innerHeight) y -= rect.height;
            menu.style.left = x + 'px';
            menu.style.top = y + 'px';
        });
        menu.style.left = x + 'px';
        menu.style.top = y + 'px';
    }

    function hideContextMenu() {
        dom.contextMenu.classList.add('hidden');
        state.contextTarget = null;
    }

    // ─── Modal Logic ──────────────────────────────────────────
    const sellModal = {
        overlay: $('#sell-modal'),
        qtyInput: $('#sell-qty'),
        priceInput: $('#sell-price'),
        confirmBtn: $('#sell-confirm-btn'),
        cancelBtn: $('#sell-cancel-btn'),
        cancelX: $('#sell-cancel-x'),

        open(item) {
            this.qtyInput.value = item.count;
            this.priceInput.value = 100;
            this.overlay.classList.remove('hidden');
            this.qtyInput.focus();
        },

        close() {
            this.overlay.classList.add('hidden');
        }
    };

    sellModal.confirmBtn.addEventListener('click', () => {
        if (!state.contextTarget) return;
        const { item } = state.contextTarget;

        const qty = parseInt(sellModal.qtyInput.value);
        const price = parseInt(sellModal.priceInput.value);

        if (isNaN(qty) || qty <= 0 || qty > item.count) {
            postNUI('notifyError', { message: "~r~Quantité invalide." });
            return;
        }

        if (isNaN(price) || price <= 0) {
            postNUI('notifyError', { message: "~r~Invalid price." });
            return;
        }

        if (price > 999999999) {
            postNUI('notifyError', { message: "~r~Price too high (max 999M$)." });
            return;
        }

        postNUI('sellItem', { item: item.name, label: item.label, count: qty, price: price });
        sellModal.close();
        hideContextMenu();
    });

    [sellModal.cancelBtn, sellModal.cancelX].forEach(btn => {
        btn.addEventListener('click', () => sellModal.close());
    });

    // Context menu actions
    dom.contextMenu.addEventListener('click', (e) => {
        const actionEl = e.target.closest('.context-menu-item');
        if (!actionEl || !state.contextTarget) return;

        const action = actionEl.dataset.action;
        const { item, zone, index } = state.contextTarget;

        switch (action) {
            case 'use':
                const iName = item.name.toUpperCase();
                const isConsumable = iName.includes('CONSUMABLE') || iName.includes('EQUIPMENT') || iName.includes('SYRINGE') || iName.includes('MEDKIT') || iName.includes('BANDAGE') || iName.includes('KEVLAR');
                const isAmmo = iName.startsWith('AMMO_');

                if (isConsumable || isAmmo) {
                    postNUI('useItem', { item: item.name, slot: index, zone, containerType: state.containerType, isAmmo: isAmmo });
                } else {
                    postNUI('notifyError', { message: "~r~Cet objet ne peut pas être utilisé de cette manière." });
                }

                if (isTestMode) {
                    console.log(`✅ Used item: ${item.label}`);
                }
                break;
            case 'drop':
                postNUI('dropItem', { item: item.name, slot: index, zone, count: item.count });
                if (isTestMode) {
                    // Remove from state
                    if (zone === 'bag') {
                        state.bagItems.splice(index, 1);
                    } else if (zone === 'container') {
                        state.containerItems.splice(index, 1);
                    }
                    renderAll();
                    console.log(`🗑️ Dropped item: ${item.label}`);
                }
                break;
            case 'sell':
                if (state.currentTab !== 'shop') return;
                sellModal.open(item);
                // hideContextMenu follows later, or inside sellModal logic
                return; // Early return because we handle it in modal confirm
            case 'buy':
                if (zone !== 'shop') return;
                postNUI('buyItem', { id: item.id }).then(resp => {
                    if (resp && resp.success) {
                        // Refresh shop items after purchase
                        postNUI('getShopItems');
                    }
                });
                break;
            case 'remove':
                if (zone !== 'shop') return;
                postNUI('removeItem', { id: item.id }).then(resp => {
                    if (resp && resp.success) {
                        postNUI('getShopItems');
                    }
                });
                break;
            case 'give':
                postNUI('giveItem', { item: item.name, slot: index, zone, count: item.count });
                if (isTestMode) {
                    console.log(`🤝 Gave item: ${item.label}`);
                }
                break;
        }

        hideContextMenu();
    });

    // ─── Native Drag & Drop ──────────────────────────────────

    function getItemsFromGrid(grid) {
        const items = [];
        grid.querySelectorAll('.item-slot').forEach(slot => {
            if (slot.classList.contains('empty')) {
                items.push(null);
            } else {
                const name = slot.dataset.itemName;
                // Find in state
                const found = [...state.bagItems, ...state.containerItems, ...state.shortkeyItems.filter(Boolean)]
                    .find(it => it && it.name === name);
                items.push(found ? { ...found } : null);
            }
        });
        return items;
    }

    // ─── Drag-Over Highlight Helper ──────────────────────────
    function clearDragOver() {
        document.querySelectorAll('.shortkey-slot.drag-over').forEach(el => el.classList.remove('drag-over'));
    }

    let draggedItemInfo = null;
    let isDragging = false;
    let clickTimeout = null;

    function _cleanupGlobalDrag() {
        isDragging = false;
        draggedItemInfo = null;

        if (_globalDragClone) {
            _globalDragClone.remove();
            _globalDragClone = null;
        }
        if (_globalMouseHandler) {
            document.removeEventListener('mousemove', _globalMouseHandler);
            _globalMouseHandler = null;
        }

        clearDragOver();

        // Enlève l'effet "fantôme" sur tous les slots
        document.querySelectorAll('.sortable-ghost').forEach(el => el.classList.remove('sortable-ghost'));
    }

    // Créer l'image invisible UNE SEULE FOIS en dehors de la fonction pour que FiveM ait le temps de la charger
    const emptyDragImage = new Image();
    emptyDragImage.src = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

    function _handleGlobalDragStart(dragEl, e) {
        const rect = dragEl.getBoundingClientRect();
        const offsetX = e.clientX - rect.left;
        const offsetY = e.clientY - rect.top;

        // On utilise l'image déjà chargée, le moteur CEF ne bloquera plus le drag
        e.dataTransfer.setDragImage(emptyDragImage, 0, 0);

        _globalDragClone = dragEl.cloneNode(true);
        _globalDragClone.className = 'global-drag-preview';
        _globalDragClone.style.width = rect.width + 'px';
        _globalDragClone.style.height = rect.height + 'px';
        _globalDragClone.style.left = rect.left + 'px';
        _globalDragClone.style.top = rect.top + 'px';

        // SÉCURITÉ : Indispensable pour ne pas bloquer le drop natif
        _globalDragClone.style.pointerEvents = 'none';

        document.body.appendChild(_globalDragClone);

        _globalMouseHandler = (moveEvt) => {
            // Sécurité : CEF renvoie parfois 0,0 en fin de drag, ce qui fait téléporter l'item
            if (_globalDragClone && moveEvt.clientX > 0) {
                _globalDragClone.style.left = (moveEvt.clientX - offsetX) + 'px';
                _globalDragClone.style.top = (moveEvt.clientY - offsetY) + 'px';
            }
        };
        document.addEventListener('dragover', _globalMouseHandler);
    }

    function initNativeDragAndDrop() {
        // --- 1. MOUSEDOWN (Début de l'interaction) ---
        dom.container.addEventListener('mousedown', (e) => {
            // Uniquement clic gauche
            if (e.button !== 0) return;

            const slot = e.target.closest('.item-slot, .shortkey-slot');
            if (!slot || !slot.dataset.itemName) return;

            // Délai court pour différencier un Drag d'un simple Clic
            clickTimeout = setTimeout(() => {
                // Initialize drag state but don't set isDragging = true until mousemove
                isDragging = false;

                draggedItemInfo = {
                    itemName: slot.dataset.itemName,
                    fromZone: slot.dataset.zone,
                    fromIndex: parseInt(slot.dataset.index),
                    element: slot
                };

                const rect = slot.getBoundingClientRect();
                const offsetX = e.clientX - rect.left;
                const offsetY = e.clientY - rect.top;

                // Création de notre propre clone visuel
                _globalDragClone = slot.cloneNode(true);
                _globalDragClone.className = 'global-drag-preview';
                _globalDragClone.style.width = rect.width + 'px';
                _globalDragClone.style.height = rect.height + 'px';
                _globalDragClone.style.left = (e.clientX - offsetX) + 'px';
                _globalDragClone.style.top = (e.clientY - offsetY) + 'px';

                // Indispensable pour que le mouseup détecte la zone en dessous
                _globalDragClone.style.pointerEvents = 'none';
                _globalDragClone.style.display = 'none'; // Keep hidden until we actually start dragging

                document.body.appendChild(_globalDragClone);

                // Applique le style fantôme au slot d'origine
                slot.classList.add('sortable-ghost');

                // --- 2. MOUSEMOVE (Mouvement du clone) ---
                _globalMouseHandler = (moveEvt) => {
                    // Start dragging only when we move the mouse a little bit
                    if (Math.abs(moveEvt.clientX - e.clientX) > 3 || Math.abs(moveEvt.clientY - e.clientY) > 3) {
                        isDragging = true;
                    }

                    if (!isDragging || !_globalDragClone) return;

                    _globalDragClone.style.display = 'flex';
                    _globalDragClone.style.left = (moveEvt.clientX - offsetX) + 'px';
                    _globalDragClone.style.top = (moveEvt.clientY - offsetY) + 'px';

                    // Cache le clone brièvement pour trouver ce qu'il y a en dessous
                    _globalDragClone.style.display = 'none';
                    const elemBelow = document.elementFromPoint(moveEvt.clientX, moveEvt.clientY);
                    _globalDragClone.style.display = 'flex';

                    clearDragOver();
                    if (elemBelow) {
                        const slotBelow = elemBelow.closest('.item-slot, .shortkey-slot');
                        if (slotBelow && (slotBelow.dataset.zone !== draggedItemInfo.fromZone || parseInt(slotBelow.dataset.index) !== draggedItemInfo.fromIndex)) {
                            slotBelow.classList.add('drag-over');
                        }
                    }
                };

                document.addEventListener('mousemove', _globalMouseHandler);
            }, 0); // 0ms delay as user requested
        });

        // Si on relâche la souris avant les 150ms, c'est un clic normal, on annule le drag
        dom.container.addEventListener('mouseup', () => {
            if (clickTimeout) clearTimeout(clickTimeout);
        });

        // --- 3. MOUSEUP (Le Drop) ---
        document.addEventListener('mouseup', (e) => {
            if (!draggedItemInfo) return;

            // If we didn't drag, it was a click!
            if (!isDragging) {
                const zone = draggedItemInfo.fromZone;
                const itemName = draggedItemInfo.itemName;

                if (zone === 'bag') {
                    if (canFitItem(itemName, 'container')) {
                        const depleted = moveOneItem(itemName, state.bagItems, state.containerItems);
                        if (depleted) {
                            const skIdx = state.shortkeyItems.findIndex(i => i && i.name === itemName);
                            if (skIdx !== -1) {
                                state.shortkeyItems[skIdx] = null;
                                postNUI('setShortkey', { slot: skIdx, item: null });
                            }
                        }
                        postNUI('moveItem', { fromZone: 'bag', toZone: 'container', item: itemName, count: 1, containerType: state.containerType });
                    }
                } else if (zone === 'container') {
                    if (canFitItem(itemName, 'bag')) {
                        moveOneItem(itemName, state.containerItems, state.bagItems);
                        postNUI('moveItem', { fromZone: 'container', toZone: 'bag', item: itemName, count: 1, containerType: state.containerType });
                    }
                }

                _cleanupGlobalDrag();
                renderAll();
                return;
            }

            if (_globalDragClone) _globalDragClone.style.display = 'none';
            const elemBelow = document.elementFromPoint(e.clientX, e.clientY);

            let targetSlot = elemBelow ? elemBelow.closest('.item-slot, .shortkey-slot') : null;
            let toZone = null;
            let toIndex = null;

            if (targetSlot) {
                toZone = targetSlot.dataset.zone;
                toIndex = parseInt(targetSlot.dataset.index);
            } else if (elemBelow) {
                const grid = elemBelow.closest('.item-grid, .hotbar-slots');
                if (grid) {
                    toZone = grid.id === 'bag-grid' ? 'bag' : (grid.id === 'container-grid' ? 'container' : 'shortkey');
                    toIndex = toZone === 'bag' ? state.bagItems.length : (toZone === 'container' ? state.containerItems.length : -1);
                }
            }

            const fromZone = draggedItemInfo.fromZone;
            const fromIndex = draggedItemInfo.fromIndex;
            const itemName = draggedItemInfo.itemName;

            if (!toZone || (fromZone === toZone && fromIndex === toIndex) || !canFitItem(itemName, toZone)) {
                _cleanupGlobalDrag();
                renderAll();
                return;
            }

            // --- TRANSFER LOGIC ---
            if (fromZone === toZone) {
                if (fromZone === 'shortkey') {
                    const targetItem = state.shortkeyItems[toIndex];
                    state.shortkeyItems[toIndex] = state.shortkeyItems[fromIndex];
                    state.shortkeyItems[fromIndex] = targetItem;
                    postNUI('setShortkey', { slot: toIndex, item: state.shortkeyItems[toIndex] ? state.shortkeyItems[toIndex].name : null });
                    postNUI('setShortkey', { slot: fromIndex, item: state.shortkeyItems[fromIndex] ? state.shortkeyItems[fromIndex].name : null });
                } else if (fromZone === 'bag') {
                    const item = state.bagItems.splice(fromIndex, 1)[0];
                    state.bagItems.splice(toIndex, 0, item);
                } else if (fromZone === 'container') {
                    const item = state.containerItems.splice(fromIndex, 1)[0];
                    state.containerItems.splice(toIndex, 0, item);
                }
            } else {
                if ((fromZone === 'bag' || fromZone === 'shortkey') && toZone === 'container') {
                    const depleted = moveOneItem(itemName, state.bagItems, state.containerItems);
                    if (depleted && fromZone === 'shortkey') {
                        state.shortkeyItems[fromIndex] = null;
                        postNUI('setShortkey', { slot: fromIndex, item: null });
                    }
                    postNUI('moveItem', { fromZone: 'bag', toZone: 'container', item: itemName, count: 1, containerType: state.containerType });
                }
                else if (fromZone === 'container' && toZone === 'bag') {
                    moveOneItem(itemName, state.containerItems, state.bagItems);
                    postNUI('moveItem', { fromZone: 'container', toZone: 'bag', item: itemName, count: 1, containerType: state.containerType });
                }
                else if (toZone === 'shortkey') {
                    // Registration only: just set the shortcut (works even if in container)
                    const allSourceItems = [...state.bagItems, ...state.containerItems];
                    const itemData = allSourceItems.find(i => i && i.name === itemName);
                    state.shortkeyItems[toIndex] = itemData ? { ...itemData } : { name: itemName, count: 1 };
                    postNUI('setShortkey', { slot: toIndex, item: itemName });
                }
                else if (fromZone === 'shortkey') {
                    state.shortkeyItems[fromIndex] = null;
                    postNUI('setShortkey', { slot: fromIndex, item: null });
                }
            }

            _cleanupGlobalDrag();
            renderAll();
        });
    }

    // ─── Open / Close ─────────────────────────────────────────
    function openInventory(data) {
        if (data) {
            state.bagItems = (data.inventory || []).filter(i => i && i.count > 0);
            state.containerItems = data.container || [];
            state.maxWeight = data.maxWeight;
            state.containerType = data.containerType || 'protected';

            // Set max weight and label based on container type
            if (state.containerType === 'stash') {
                state.containerMaxWeight = '∞';
                if (dom.containerLabel) dom.containerLabel.textContent = data.containerLabel || 'MY CONTAINER';
            } else {
                state.containerMaxWeight = data.containerMaxWeight || 200.0;
                if (dom.containerLabel) dom.containerLabel.textContent = 'PROTECTED CONTAINER';
            }

            if (data.shortkeys && Array.isArray(data.shortkeys)) {
                // Shortkeys are an array of strings (item names) or false/null
                state.shortkeyItems = data.shortkeys.map(sk => {
                    if (!sk) return null;
                    const allItems = [...MOCK_ITEMS, ...MOCK_CONTAINER, ...state.bagItems, ...state.containerItems];
                    const found = allItems.find(i => i && i.name === sk);
                    return found ? { ...found } : { name: sk, label: sk.replace(/_/g, ' '), count: 0, weight: 0 };
                });
            }

            const wrapper = document.querySelector('.sections-wrapper');
            if (state.containerType === 'stash') {
                wrapper.classList.add('stash-mode');
            } else {
                wrapper.classList.remove('stash-mode');
            }

            if (data.playerName) dom.playerName.textContent = data.playerName;
            if (data.playerId) dom.playerId.textContent = 'ID: ' + data.playerId;
            if (data.money !== undefined) {
                dom.money.textContent = data.money.toLocaleString('en-US');
            }

            state.autoReload = data.autoReload || false;
            // Hide ammo filter if autoReload is true
            const ammoFilter = document.querySelector('.filter-btn[data-filter="ammo"]');
            if (ammoFilter) {
                if (state.autoReload) {
                    ammoFilter.classList.add('hidden');
                } else {
                    ammoFilter.classList.remove('hidden');
                }
            }
        }

        state.isOpen = true;
        dom.container.classList.remove('hidden');
        renderAll();
    }

    function closeInventory() {
        state.isOpen = false;
        state.lastAction = null;
        dom.container.classList.add('hidden');
        hideContextMenu();
        hideTooltip();
        postNUI('closeInventory');
    }

    // ─── Event Listeners ──────────────────────────────────────

    // Sidebar Tabs
    dom.sidebarItems.forEach(item => {
        item.addEventListener('click', () => {
            const tab = item.dataset.tab;
            if (tab === 'settings') return;

            state.currentTab = tab;

            // UI Update (Sidebar active state)
            dom.sidebarItems.forEach(i => i.classList.remove('active'));
            item.classList.add('active');

            if (tab === 'shop') {
                postNUI('getShopItems');
            } else if (tab === 'profile') {
                postNUI('getProfileData');
            }

            renderAll();
        });
    });

    // NUI messages from Lua
    window.addEventListener('message', (event) => {
        const data = event.data;

        switch (data.action) {
            case 'openInventory':
                openInventory(data);
                break;
            case 'closeInventory':
                closeInventory();
                break;
            case 'updateInventory':
                state.bagItems = (data.inventory || []).filter(i => i && i.count > 0);
                if (state.containerType === 'stash') {
                    if (data.container) state.containerItems = data.container;
                } else {
                    if (data.container) state.containerItems = data.container;
                }
                renderAll();
                break;
            case 'updateShop':
                state.shopItems = data.shop || [];
                renderAll();
                break;
            case 'updateProfile':
                renderProfile(data.data);
                break;
        }
    });

    // ESC or TAB to close
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && state.isOpen) {
            e.preventDefault();
            closeInventory();
        } else if (e.key === 'Tab' && state.isOpen) {
            e.preventDefault();
            if (state.currentTab === 'shop' || state.currentTab === 'profile') {
                // Find and click the inventory sidebar item
                const invTab = Array.from(dom.sidebarItems).find(i => i.dataset.tab === 'inventory');
                if (invTab) invTab.click();
            } else {
                closeInventory();
            }
        }
    });

    // --- FORCE FIVEM A ACCEPTER LE DRAG PARTOUT ---

    // 1. Autoriser le drag uniquement sur nos slots
    document.addEventListener('dragstart', (e) => {
        if (!e.target.closest('.item-slot') && !e.target.closest('.shortkey-slot')) {
            e.preventDefault();
        }
    });

    // 2. EMPECHER LE ROND BARRÉ DE FIVEM (Crucial)
    // On doit dire au document entier que le "drop" est potentiellement autorisé
    document.addEventListener('dragover', (e) => {
        e.preventDefault();
    });

    // 3. Sécurité supplémentaire pour nettoyer si on lâche hors fenêtre
    document.addEventListener('drop', (e) => {
        // On ne gère le drop global que si on est en dehors de l'inventaire
        if (!e.target.closest('#inventory-container')) {
            e.preventDefault();
            _cleanupGlobalDrag();
        }
    });

    // Click outside to close context menu
    document.addEventListener('click', (e) => {
        if (!dom.contextMenu.contains(e.target) && !sellModal.overlay.contains(e.target)) {
            hideContextMenu();
        }
    });

    // Shop search & filters
    const shopSearch = $('#shop-search');
    if (shopSearch) {
        shopSearch.addEventListener('input', (e) => {
            state.shopSearchQuery = e.target.value;
            renderShop();
        });
    }

    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            state.shopFilter = btn.dataset.filter;
            renderShop();
        });
    });



    // ─── Test Mode Bootstrap ──────────────────────────────────
    if (isTestMode) {
        console.log('%c🎮 AZ Inventory – Test Mode', 'color: #e53935; font-size: 16px; font-weight: bold;');
        console.log('%cPress [TAB] to toggle inventory', 'color: #9e9e9e;');

        // TAB key toggle
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Tab') {
                e.preventDefault();
                if (state.isOpen) {
                    closeInventory();
                } else {
                    openInventory({
                        inventory: MOCK_ITEMS,
                        container: MOCK_CONTAINER,
                        maxWeight: 1000,
                        playerName: 'John Doe',
                        playerId: 42,
                    });
                }
            }
        });

        // Background for test mode
        document.body.style.background = 'linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%)';
        document.body.style.backgroundSize = 'cover';
        document.body.style.minHeight = '100vh';
    }

    // Expose for external use + test commands
    window.AZInventory = {
        open: openInventory,
        close: closeInventory,
        state: state,

        // ─── Console Test Commands ───────────────────────
        removeAll() {
            state.bagItems = [];
            state.containerItems = [];
            state.shortkeyItems = [null, null, null, null, null, null];
            renderAll();
            console.log('%c🗑️ All items removed', 'color: #e53935');
        },

        addItem(name, count = 1, weight = 0.5, label, description) {
            label = label || name.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
            description = description || '';
            const existing = state.bagItems.find(i => i && i.name === name);
            if (existing) {
                existing.count += count;
            } else {
                state.bagItems.push({ name, label, count, weight, description });
            }
            renderAll();
            console.log(`%c✅ Added ${count}x ${label} to bag`, 'color: #43a047');
        },

        removeItem(name) {
            const idx = state.bagItems.findIndex(i => i && i.name === name);
            if (idx !== -1) {
                const removed = state.bagItems.splice(idx, 1)[0];
                // Also remove from shortkeys if present
                state.shortkeyItems = state.shortkeyItems.map(s => (s && s.name === name) ? null : s);
                renderAll();
                console.log(`%c🗑️ Removed ${removed.label} from bag`, 'color: #e53935');
            } else {
                console.log(`%c⚠️ Item "${name}" not found in bag`, 'color: #ff9800');
            }
        },

        listItems() {
            console.log('%c📦 Bag Items:', 'color: #2196f3; font-weight: bold');
            state.bagItems.forEach(i => console.log(`  ${i.name} x${i.count} (${i.weight}kg)`));
            console.log('%c🔒 Container Items:', 'color: #9c27b0; font-weight: bold');
            state.containerItems.forEach(i => console.log(`  ${i.name} x${i.count} (${i.weight}kg)`));
            console.log('%c⌨️ Shortkeys:', 'color: #ff9800; font-weight: bold');
            state.shortkeyItems.forEach((i, idx) => console.log(`  [${idx + 1}] ${i ? i.name : '(empty)'}`));
        },
    };
})();
