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
                        postNUI('moveItem', { fromZone: 'bag', toZone: 'container', item: item.name, count: 1, containerType: state.containerType });
                        renderAll();
                    } else if (zone === 'container' && toZone === 'bag') {
                        if (!canFitItem(item.name, 'bag')) return;

                        moveOneItem(item.name, state.containerItems, state.bagItems);
                        postNUI('moveItem', { fromZone: 'container', toZone: 'bag', item: item.name, count: 1, containerType: state.containerType });
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
        const totalVisibleSlots = 18; // 6 rows of 3 in stash mode

        // On affiche uniquement les items réels à la suite (Index dynamique)
        state.containerItems.forEach((item, i) => {
            if (item) {
                frag.appendChild(createItemSlot(item, 'container', i));
            }
        });

        // On remplit le reste avec des slots vides
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
                    postNUI('moveItem', { fromZone: 'bag', toZone: 'container', item: item.name, count: 1, containerType: state.containerType });
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
        if (!window.__dragInited) {
            initNativeDragAndDrop();
            window.__dragInited = true;
        }

        // Initialize weapon previews();
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
                postNUI('useItem', { item: item.name, slot: index, zone, containerType: state.containerType });
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
                isDragging = true;

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

                document.body.appendChild(_globalDragClone);

                // Applique le style fantôme au slot d'origine
                slot.classList.add('sortable-ghost');

                // --- 2. MOUSEMOVE (Mouvement du clone) ---
                _globalMouseHandler = (moveEvt) => {
                    if (!isDragging || !_globalDragClone) return;

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
            }, 0); // 150ms delay
        });

        // Si on relâche la souris avant les 150ms, c'est un clic normal, on annule le drag
        dom.container.addEventListener('mouseup', () => {
            if (clickTimeout) clearTimeout(clickTimeout);
        });

        // --- 3. MOUSEUP (Le Drop) ---
        document.addEventListener('mouseup', (e) => {
            if (!isDragging || !draggedItemInfo) return;

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
        }
    });

    // ESC or TAB to close
    document.addEventListener('keydown', (e) => {
        if ((e.key === 'Escape' || e.key === 'Tab') && state.isOpen) {
            e.preventDefault();
            closeInventory();
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
        if (!dom.contextMenu.contains(e.target)) {
            hideContextMenu();
        }
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
