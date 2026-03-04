/* ============================================================
   ESX Inventory – GLife Extinction Style
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
        containerMaxWeight: 30,
        selectedSlot: null,
        contextTarget: null,
        lastAction: null,
    };

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
        contextMenu: $('#context-menu'),
        tooltip: $('#item-tooltip'),
        tooltipName: $('#tooltip-name'),
        tooltipDesc: $('#tooltip-desc'),
        tooltipWeight: $('#tooltip-weight'),
        tooltipQty: $('#tooltip-qty'),
        playerName: $('#player-name'),
        playerId: $('#player-id'),
    };

    // ─── Test Mode Detection ──────────────────────────────────
    const isTestMode = typeof GetParentResourceName === 'undefined';
    const resourceName = isTestMode ? 'esx_inventory' : GetParentResourceName();

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
            dom.containerWeightMax.textContent = state.containerMaxWeight;
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

            // Click to quick move (repeat last drag action)
            slot.addEventListener('click', () => {
                if (state.lastAction && state.lastAction.fromZone === zone) {
                    const toZone = state.lastAction.toZone;

                    if (zone === 'bag' && toZone === 'container') {
                        if (!canFitItem(item.name, 'container')) return;

                        const depleted = moveOneItem(item.name, state.bagItems, state.containerItems);
                        if (depleted) {
                            const skIdx = state.shortkeyItems.findIndex(i => i && i.name === item.name);
                            if (skIdx !== -1) state.shortkeyItems[skIdx] = null;
                        }
                        postNUI('moveItem', { fromZone: 'bag', toZone: 'container', item: item.name, count: 1 });
                        renderAll();
                    } else if (zone === 'container' && toZone === 'bag') {
                        if (!canFitItem(item.name, 'bag')) return;

                        moveOneItem(item.name, state.containerItems, state.bagItems);
                        postNUI('moveItem', { fromZone: 'container', toZone: 'bag', item: item.name, count: 1 });
                        renderAll();
                    }
                }
            });
        }

        return slot;
    }

    function renderBag() {
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
        const totalSlots = 12;
        for (let i = 0; i < totalSlots; i++) {
            const item = state.containerItems[i] || null;
            frag.appendChild(createItemSlot(item, 'container', i));
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
            if (item && !isGhost) {
                // Only set dataset.itemName for REAL (non-ghost) items.
                // Ghost slots must look empty to SortableJS so they can always be overwritten.
                slot.dataset.itemName = item.name;
                inner += `
                    <img class="item-image" src="${getItemImagePath(item.name)}" alt="${item.label}"
                         onerror="this.src='data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 width=%2232%22 height=%2232%22 viewBox=%220 0 24 24%22 fill=%22none%22 stroke=%22%23616161%22 stroke-width=%221.5%22><rect x=%222%22 y=%222%22 width=%2220%22 height=%2220%22 rx=%222%22/></svg>'">
                    <span class="item-name">${item.label}</span>
                `;

                slot.innerHTML = inner;

                // Click: move item to container
                slot.addEventListener('click', () => {
                    if (!canFitItem(item.name, 'container')) return;
                    const depleted = moveOneItem(item.name, state.bagItems, state.containerItems);
                    if (depleted) {
                        state.shortkeyItems[i] = null;
                        postNUI('setShortkey', { slot: i, item: null });
                    }
                    state.lastAction = { fromZone: 'bag', toZone: 'container' };
                    postNUI('moveItem', { fromZone: 'bag', toZone: 'container', item: item.name, count: 1 });
                    renderAll();
                });
            } else {
                slot.innerHTML = inner;
            }

            frag.appendChild(slot);
        }
        dom.shortkeysSlots.replaceChildren(frag);
    }

    function renderAll() {
        renderBag();
        renderContainer();
        renderShortkeys();
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

    // Context menu actions
    dom.contextMenu.addEventListener('click', (e) => {
        const actionEl = e.target.closest('.context-menu-item');
        if (!actionEl || !state.contextTarget) return;

        const action = actionEl.dataset.action;
        const { item, zone, index } = state.contextTarget;

        switch (action) {
            case 'use':
                postNUI('useItem', { item: item.name, slot: index, zone });
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
            case 'give':
                postNUI('giveItem', { item: item.name, slot: index, zone, count: item.count });
                if (isTestMode) {
                    console.log(`🤝 Gave item: ${item.label}`);
                }
                break;
        }

        hideContextMenu();
    });

    // ─── SortableJS ───────────────────────────────────────────
    let bagSortable, containerSortable, shortkeySortable;

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

    function initSortable() {
        if (bagSortable) bagSortable.destroy();
        if (containerSortable) containerSortable.destroy();

        const sortableOpts = {
            group: { name: 'inventory', pull: true, put: true },
            animation: 200,
            ghostClass: 'sortable-ghost',
            chosenClass: 'sortable-chosen',
            dragClass: 'sortable-drag',
            forceFallback: true,
            filter: '.empty',
            onAdd: function (evt) {
                const droppedEl = evt.item;
                const itemName = droppedEl.dataset.itemName;
                const toZone = evt.to.id === 'bag-grid' ? 'bag' : 'container';
                let fromZone = evt.from.id === 'bag-grid' ? 'bag' : evt.from.id === 'container-grid' ? 'container' : 'shortkeys';

                droppedEl.style.display = 'none'; // Cache l'élément cloné par Sortable

                if (!itemName || !canFitItem(itemName, toZone)) {
                    setTimeout(() => { renderAll(); initSortable(); }, 10);
                    return;
                }

                // Logique de transfert (Bag <-> Container)
                if (fromZone === 'shortkeys' || fromZone === 'bag') {
                    if (toZone === 'container') {
                        const depleted = moveOneItem(itemName, state.bagItems, state.containerItems);
                        if (depleted) {
                            const skIdx = state.shortkeyItems.findIndex(i => i && i.name === itemName);
                            if (skIdx !== -1) {
                                state.shortkeyItems[skIdx] = null;
                                postNUI('setShortkey', { slot: skIdx, item: null });
                            }
                        }
                        postNUI('moveItem', { fromZone: 'bag', toZone: 'container', item: itemName, count: 1 });
                    }
                } else if (fromZone === 'container' && toZone === 'bag') {
                    moveOneItem(itemName, state.containerItems, state.bagItems);
                    postNUI('moveItem', { fromZone: 'container', toZone: 'bag', item: itemName, count: 1 });
                }

                setTimeout(() => {
                    renderAll();
                    initSortable(); // 🟢 On relance les instances APRES le rendu
                }, 10);
            },
            onMove: function (evt) {
                clearDragOver();
                if (evt.to === dom.shortkeysSlots && evt.related) {
                    const slot = evt.related.closest('.shortkey-slot') || evt.related;
                    if (slot && slot.classList.contains('shortkey-slot')) {
                        slot.classList.add('drag-over');
                    }
                }
            },
            onEnd: function (evt) {
                clearDragOver();
                handleDragEnd(evt);
            }
        };

        bagSortable = new Sortable(dom.bagGrid, sortableOpts);
        containerSortable = new Sortable(dom.containerGrid, sortableOpts);
        initSortableShortkeys(); // Initialise la hotbar
    }

    function initSortableShortkeys() {
        // 1. On détruit proprement l'ancienne instance avant d'en créer une nouvelle
        if (shortkeySortable) {
            shortkeySortable.destroy();
            shortkeySortable = null;
        }

        shortkeySortable = new Sortable(dom.shortkeysSlots, {
            group: {
                name: 'inventory',
                pull: true,
                put: true,
            },
            animation: 0,
            sort: false,
            ghostClass: 'sortable-ghost',
            chosenClass: 'sortable-chosen',
            dragClass: 'sortable-drag',
            forceFallback: false,
            onStart: function (evt) {
                // Création du dummy pour garder la structure à 6 colonnes
                const dummy = document.createElement('div');
                dummy.className = 'shortkey-slot';
                dummy.id = 'drag-dummy-slot';
                dummy.innerHTML = `<span class="shortkey-number">${evt.oldIndex + 1}</span>`;
                dom.shortkeysSlots.insertBefore(dummy, dom.shortkeysSlots.children[evt.oldIndex]);
            },
            onAdd: function (evt) {
                const droppedEl = evt.item;
                const itemName = droppedEl.dataset.itemName;
                let targetIndex = evt.newIndex;

                // Calcul précis de l'index cible (pour éviter les décalages FiveM/CEF)
                if (evt.originalEvent) {
                    const e = evt.originalEvent;
                    const cX = e.clientX || (e.changedTouches ? e.changedTouches[0].clientX : 0);
                    const cY = e.clientY || (e.changedTouches ? e.changedTouches[0].clientY : 0);

                    droppedEl.style.display = 'none'; // Cache temporairement pour voir dessous
                    const elemBelow = document.elementFromPoint(cX, cY);

                    if (elemBelow) {
                        const slotBelow = elemBelow.closest('.shortkey-slot');
                        if (slotBelow && slotBelow.id !== 'drag-dummy-slot') {
                            targetIndex = parseInt(slotBelow.dataset.index);
                        }
                    }
                }

                // Sécurité sur l'index
                if (targetIndex === undefined || targetIndex >= state.shortkeyItems.length) {
                    targetIndex = evt.newIndex;
                }

                // 2. IMPORTANT : On cache l'élément cloné par Sortable car renderAll va créer le vrai
                droppedEl.style.display = 'none';

                if (itemName) {
                    // On cherche les infos de l'item dans le sac ou le coffre
                    const allSourceItems = [...state.bagItems, ...state.containerItems];
                    const itemData = allSourceItems.find(i => i && i.name === itemName);

                    // Mise à jour du state
                    state.shortkeyItems[targetIndex] = itemData
                        ? { ...itemData }
                        : { name: itemName, label: itemName.replace(/_/g, ' '), count: 1, weight: 0 };

                    // Notification au serveur/client Lua
                    postNUI('setShortkey', { slot: targetIndex, item: itemName });
                }

                clearDragOver();

                // 3. On diffère le rendu pour laisser SortableJS finir son cycle interne
                setTimeout(() => {
                    renderAll();
                    // On ne rappelle pas initSortable ici car renderAll le fait déjà normalement
                }, 20);
            },
            onMove: function (evt) {
                clearDragOver();
                if (evt.related) {
                    const slot = evt.related.closest('.shortkey-slot');
                    if (slot) slot.classList.add('drag-over');
                }
            },
            onEnd: function (evt) {
                clearDragOver();
                const dummy = document.getElementById('drag-dummy-slot');
                if (dummy) dummy.remove();

                // Si on a simplement déplacé à l'intérieur ou sorti l'item
                setTimeout(() => {
                    renderAll();
                }, 20);
            },
        });
    }

    function handleDragEnd(evt) {
        // Only handle same-zone reordering
        if (evt.from === evt.to) {
            rebuildStateFromDOM();
            postNUI('moveItem', {
                fromZone: evt.from.id.replace('-grid', '').replace('-slots', ''),
                toZone: evt.to.id.replace('-grid', '').replace('-slots', ''),
                fromSlot: evt.oldIndex,
                toSlot: evt.newIndex,
            });
        }

        setTimeout(() => {
            renderAll();
        }, 10);
    }

    function rebuildStateFromDOM() {
        // We must preserve existing item definitions
        const sourceItems = [...state.bagItems, ...state.containerItems];

        state.bagItems = [];
        dom.bagGrid.querySelectorAll('.item-slot').forEach(slot => {
            if (!slot.classList.contains('empty') && slot.dataset.itemName) {
                const itemName = slot.dataset.itemName;
                const found = sourceItems.find(i => i && i.name === itemName);
                if (found) state.bagItems.push({ ...found });
            }
        });

        state.containerItems = [];
        dom.containerGrid.querySelectorAll('.item-slot').forEach(slot => {
            if (!slot.classList.contains('empty') && slot.dataset.itemName) {
                const itemName = slot.dataset.itemName;
                const found = sourceItems.find(i => i && i.name === itemName);
                if (found) state.containerItems.push({ ...found });
            }
        });

        const newShortkeys = [null, null, null, null, null, null];
        dom.shortkeysSlots.querySelectorAll('.shortkey-slot').forEach((slot, idx) => {
            if (slot.dataset.itemName) {
                const itemName = slot.dataset.itemName;
                const found = sourceItems.find(i => i && i.name === itemName);
                if (found && idx < 6) newShortkeys[idx] = { ...found };
            }
        });
        state.shortkeyItems = newShortkeys;
    }

    // ─── Open / Close ─────────────────────────────────────────
    function openInventory(data) {
        if (data) {
            state.bagItems = (data.inventory || []).filter(i => i && i.count > 0);
            state.containerItems = data.container || [];
            state.maxWeight = data.maxWeight || 1000;
            state.containerMaxWeight = data.containerMaxWeight || 30;

            if (data.shortkeys && Array.isArray(data.shortkeys)) {
                // Shortkeys are an array of strings (item names) or false/null
                state.shortkeyItems = data.shortkeys.map(sk => {
                    if (!sk) return null;
                    const allItems = [...MOCK_ITEMS, ...MOCK_CONTAINER, ...state.bagItems, ...state.containerItems];
                    const found = allItems.find(i => i && i.name === sk);
                    return found ? { ...found } : { name: sk, label: sk.replace(/_/g, ' '), count: 0, weight: 0 };
                });
            }

            if (data.playerName) dom.playerName.textContent = data.playerName;
            if (data.playerId) dom.playerId.textContent = 'ID: ' + data.playerId;
        }

        state.isOpen = true;
        dom.container.classList.remove('hidden');
        renderAll();

        // FiveM CEF may not have fully established input handling right after NUI focus.
        // We reinit SortableJS on the first mouseenter — guaranteed to be before any drag,
        // and guaranteed to have a complete layout. The listener auto-removes after one fire.
        dom.container.addEventListener('mouseenter', function _reinitOnFirstEnter() {
            dom.container.removeEventListener('mouseenter', _reinitOnFirstEnter);
            initSortable();
        });
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
                renderBag();
                break;
        }
    });

    // ESC or TAB to close
    document.addEventListener('keydown', (e) => {
        if ((e.key === 'Escape' || e.key === 'Tab') && state.isOpen) {
            e.preventDefault();
            closeInventory();
        }
    });

    // Prevent random image drags from triggering native browser "not-allowed" icon
    document.addEventListener('dragstart', (e) => {
        e.preventDefault();
    });

    // Click outside to close context menu
    document.addEventListener('click', (e) => {
        if (!dom.contextMenu.contains(e.target)) {
            hideContextMenu();
        }
    });

    // ─── Test Mode Bootstrap ──────────────────────────────────
    if (isTestMode) {
        console.log('%c🎮 ESX Inventory – Test Mode', 'color: #e53935; font-size: 16px; font-weight: bold;');
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
    window.ESXInventory = {
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
