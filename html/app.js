'use strict';

// ─── Estado ──────────────────────────────────────────────────────────────────
let state = {
    playerData:     null,
    calls:          [],
    zones:          {},
    levels:         {},
    rentOptions:    [],
    buyOptions:     [],
    ownedTaxis:     [],
    hasRentedTruck: false,
    activeJob:      null,
    selectedCall:   null,
    currentTab:     'dashboard',
    filterZone:     'all',
    genInterval:    30,
    isItem:         false,
};

// ─── Accent color (mri:color convar) ─────────────────────────────────────────
function applyAccentColor(hex) {
    if (!hex || !/^#[0-9a-fA-F]{6}$/.test(hex)) return;
    const r = parseInt(hex.slice(1,3),16)/255;
    const g = parseInt(hex.slice(3,5),16)/255;
    const b = parseInt(hex.slice(5,7),16)/255;
    const max = Math.max(r,g,b), min = Math.min(r,g,b);
    let h=0, s=0, l=(max+min)/2;
    if (max !== min) {
        const d = max-min;
        s = l > 0.5 ? d/(2-max-min) : d/(max+min);
        switch(max) {
            case r: h = ((g-b)/d + (g<b?6:0))/6; break;
            case g: h = ((b-r)/d + 2)/6; break;
            case b: h = ((r-g)/d + 4)/6; break;
        }
    }
    const hsl = `${Math.round(h*360)} ${Math.round(s*100)}% ${Math.round(l*100)}%`;
    document.documentElement.style.setProperty('--primary', hsl);
    document.documentElement.style.setProperty('--color-primary', hex);
    document.documentElement.style.setProperty('--ring', hsl);
}

// ─── NUI helpers ─────────────────────────────────────────────────────────────
function nuiPost(action, data = {}) {
    const resourceName = window.GetParentResourceName ? GetParentResourceName() : 'mri_qtaxi';
    return fetch(`https://${resourceName}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    });
}

// ─── Tabs ─────────────────────────────────────────────────────────────────────

function switchTab(tab) {
    state.currentTab = tab;
    document.querySelectorAll('.tab-section').forEach(s => s.classList.add('hidden'));
    document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
    document.getElementById(`tab-${tab}`)?.classList.remove('hidden');
    document.querySelector(`[data-tab="${tab}"]`)?.classList.add('active');

    if (tab === 'history') renderHistory();
    if (tab === 'rent')    renderRentSection();
    if (tab === 'buy')     renderBuySection();
    if (tab === 'garage')  renderGarageSection();
    if (tab === 'ranking') renderRanking();

    if (tab === 'routes') {
        renderCalls();
        const textEl = document.getElementById('next-update-text');
        if (textEl) {
            if (state.genInterval >= 60) {
                textEl.textContent = `Novas corridas a cada ${Math.floor(state.genInterval / 60)} min`;
            } else {
                textEl.textContent = `Novas corridas a cada ${state.genInterval} seg`;
            }
        }
    }
}

// ─── Dashboard ───────────────────────────────────────────────────────────────
function renderDashboard() {
    const d = state.playerData;
    if (!d) return;

    const level     = d.level     || 1;
    const levelData = state.levels[level] || { label: 'Iniciante', multiplier: 1.0, color: '#9ca3af' };
    const xp        = d.xp        || 0;
    const progress  = d.xpProgress || 0;
    const xpNext    = d.xpToNextLevel || 0;

    // Top Rank Banner
    const topRankBanner = document.getElementById('top-rank-banner');
    if (topRankBanner) {
        if (d.rank && d.rankBuff && d.rank <= 3) {
            topRankBanner.classList.remove('hidden');
            document.getElementById('top-rank-pos').textContent = d.rank;
            document.getElementById('top-rank-buff').textContent = `+${Math.round((d.rankBuff - 1) * 100)}%`;
        } else {
            topRankBanner.classList.add('hidden');
        }
    }

    // Sidebar
    document.getElementById('sidebar-level-badge').textContent = `Nv. ${level}`;
    document.getElementById('sidebar-level-title').textContent = levelData.label;
    const xpFill = document.getElementById('sidebar-xp-fill');
    const xpText = document.getElementById('sidebar-xp-text');
    if (xpFill) xpFill.style.width = `${progress}%`;
    if (xpText) xpText.textContent = level < 10
        ? `${xp.toLocaleString('pt-BR')} / ${xpNext.toLocaleString('pt-BR')} XP`
        : 'Nível Máximo';

    // Profile card
    const profileLvl = document.getElementById('profile-level-num');
    profileLvl.textContent = level;
    profileLvl.style.color = levelData.color;
    document.getElementById('profile-level-label').textContent = levelData.label;
    document.getElementById('profile-xp').textContent = xp.toLocaleString('pt-BR');
    document.getElementById('profile-xp-next').textContent = xpNext.toLocaleString('pt-BR');
    document.getElementById('xp-fill').style.width = `${progress}%`;

    // Stats
    document.getElementById('stat-deliveries').textContent = d.total_deliveries || 0;
    document.getElementById('stat-earned').textContent     = formatMoney(d.total_earned || 0);
    document.getElementById('stat-xp').textContent         = (xp).toLocaleString('pt-BR');
    document.getElementById('stat-mult').textContent       = `x${levelData.multiplier.toFixed(1)}`;

    renderLevels(level);
    renderActiveJob();
}

function renderLevels(currentLevel) {
    const grid = document.getElementById('levels-grid');
    grid.innerHTML = '';
    Object.entries(state.levels).forEach(([lvl, data]) => {
        const l    = parseInt(lvl);
        const el   = document.createElement('div');
        el.className = 'level-item' + (l === currentLevel ? ' current' : l > currentLevel ? ' unlocked' : '');
        el.style.borderColor = l <= currentLevel ? data.color : '';
        el.innerHTML = `
            <div class="level-num" style="color:${data.color}">${l}</div>
            <div class="level-name">${data.label}</div>
            <div class="level-xp">${l > 1 ? (state.levels[l].xp / 1000).toFixed(1) + 'k XP' : '0 XP'}</div>
            <div class="level-mult">x${data.multiplier.toFixed(2)}</div>
        `;
        grid.appendChild(el);
    });
}

function renderActiveJob() {
    const card = document.getElementById('active-job-card');
    if (!state.activeJob) { card.classList.add('hidden'); return; }
    card.classList.remove('hidden');

    const call = state.calls.find(r => r.id === state.activeJob.callId);
    const label = call ? call.label : `Chamada ${state.activeJob.callId}`;
    document.getElementById('active-job-info').textContent = `Em andamento: ${label}`;
}

// ─── Garagem / Aluguel ─────────────────────────────────────────────────────────
function applyRentState(hasRentedTruck) {
    state.hasRentedTruck = hasRentedTruck;

    const card      = document.getElementById('return-card');
    const returnBtn = document.getElementById('btn-return-truck');
    const desc      = document.getElementById('return-card-desc');

    if (hasRentedTruck) {
        card.classList.add('has-truck');
        returnBtn.disabled = false;
        desc.textContent = 'Você possui um táxi em uso. Clique para devolvê-lo/guardá-lo.';
    } else {
        card.classList.remove('has-truck');
        returnBtn.disabled = true;
        desc.textContent = 'Nenhum táxi em uso no momento.';
    }

    document.querySelectorAll('.rent-btn').forEach(btn => {
        btn.disabled = hasRentedTruck;
        btn.style.opacity = hasRentedTruck ? '0.35' : '';
    });

    const banner = document.getElementById('no-truck-banner');
    if (banner) banner.classList.toggle('hidden', hasRentedTruck);
}

function renderRentSection() {
    const listRent = document.getElementById('rent-trucks-list');
    
    listRent.innerHTML = '';
    listRent.style.display = 'grid';
    listRent.style.gridTemplateColumns = 'repeat(auto-fill, minmax(280px, 1fr))';
    listRent.style.gap = '15px';

    // Render Rent Options
    state.rentOptions.forEach(opt => {
        const el = document.createElement('div');
        el.className = 'rent-card';
        el.style.flexDirection = 'column';
        el.style.alignItems = 'stretch';
        el.style.padding = '15px';
        
        el.innerHTML = `
            <div style="height: 140px; background: url('${opt.image || ''}') center/contain no-repeat; margin-bottom: 15px; border-radius: 8px; background-color: rgba(255,255,255,0.02);"></div>
            <div class="rent-info" style="margin-bottom: 15px;">
                <div class="rent-name" style="font-size: 16px;">${opt.label}</div>
                <div class="rent-desc" style="font-size: 13px;">${opt.desc}</div>
            </div>
            <button class="btn-primary rent-btn" style="width: 100%; padding: 10px;" data-id="${opt.id}">
                R$ ${opt.price.toLocaleString('pt-BR')}
            </button>
        `;
        el.querySelector('.rent-btn').addEventListener('click', () => {
            nuiPost('rentTaxi', { id: opt.id, price: opt.price, duration: opt.duration });
        });
        listRent.appendChild(el);
    });

    applyRentState(state.hasRentedTruck);
}

function renderGarageSection() {
    const listOwned = document.getElementById('owned-trucks-list');
    
    listOwned.innerHTML = '';
    listOwned.style.display = 'grid';
    listOwned.style.gridTemplateColumns = 'repeat(auto-fill, minmax(280px, 1fr))';
    listOwned.style.gap = '15px';

    // Render Owned Options
    if (state.ownedTaxis.length === 0) {
        listOwned.style.display = 'block';
        listOwned.innerHTML = '<div class="empty-state" style="font-size: 13px;">Você não possui nenhum táxi próprio.</div>';
    } else {
        state.ownedTaxis.forEach(model => {
            const opt = state.buyOptions.find(o => o.model === model) || { label: model, desc: 'Seu veículo', image: 'https://docs.fivem.net/vehicles/taxi.webp' };
            const el = document.createElement('div');
            el.className = 'rent-card';
            el.style.flexDirection = 'column';
            el.style.alignItems = 'stretch';
            el.style.padding = '15px';

            el.innerHTML = `
                <div style="height: 140px; background: url('${opt.image || ''}') center/contain no-repeat; margin-bottom: 15px; border-radius: 8px; background-color: rgba(255,255,255,0.02);"></div>
                <div class="rent-info" style="margin-bottom: 15px;">
                    <div class="rent-name" style="font-size: 16px;">${opt.label}</div>
                    <div class="rent-desc" style="font-size: 13px;">Veículo Próprio</div>
                </div>
                <button class="btn-primary rent-btn" style="width: 100%; padding: 10px;">
                    Retirar Veículo
                </button>
            `;
            el.querySelector('.rent-btn').addEventListener('click', () => {
                nuiPost('useOwnedTaxi', { model: model });
            });
            listOwned.appendChild(el);
        });
    }
}

function renderBuySection() {
    const listBuy = document.getElementById('buy-trucks-list');
    listBuy.innerHTML = '';
    listBuy.style.display = 'grid';
    listBuy.style.gridTemplateColumns = 'repeat(auto-fill, minmax(280px, 1fr))';
    listBuy.style.gap = '15px';

    state.buyOptions.forEach(opt => {
        const isOwned = state.ownedTaxis.includes(opt.model);
        const el = document.createElement('div');
        el.className = 'rent-card';
        el.style.flexDirection = 'column';
        el.style.alignItems = 'stretch';
        el.style.padding = '15px';
        
        el.innerHTML = `
            <div style="height: 140px; background: url('${opt.image || ''}') center/contain no-repeat; margin-bottom: 15px; border-radius: 8px; background-color: rgba(255,255,255,0.02);"></div>
            <div class="rent-info" style="margin-bottom: 15px;">
                <div class="rent-name" style="font-size: 16px;">${opt.label}</div>
                <div class="rent-desc" style="font-size: 13px;">${opt.desc}</div>
            </div>
            <button class="btn-secondary rent-btn" style="width: 100%; padding: 10px;" ${isOwned ? 'disabled style="opacity:0.5"' : ''}>
                ${isOwned ? 'Já Possui' : 'Comprar R$ ' + opt.price.toLocaleString('pt-BR')}
            </button>
        `;
        if(!isOwned) {
            el.querySelector('.rent-btn').addEventListener('click', () => {
                nuiPost('buyTaxi', { model: opt.model, price: opt.price });
            });
        }
        listBuy.appendChild(el);
    });
}

function renderFilterZones() {
    const bar = document.getElementById('zones-filter-bar');
    // Keep 'all' and the right group (countdown + random)
    const btnAll = bar.querySelector('[data-zone="all"]');
    const rightGroup = bar.querySelector('.filter-right-group');
    bar.innerHTML = '';
    bar.appendChild(btnAll);

    Object.entries(state.zones).forEach(([key, zone]) => {
        const btn = document.createElement('button');
        btn.className = 'filter-btn';
        if (state.filterZone === key) btn.classList.add('active');
        btn.dataset.zone = key;
        btn.textContent = zone.label;
        btn.addEventListener('click', () => {
            document.querySelectorAll('#zones-filter-bar .filter-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            state.filterZone = key;
            renderCalls();
        });
        bar.appendChild(btn);
    });
    
    btnAll.addEventListener('click', () => {
        document.querySelectorAll('#zones-filter-bar .filter-btn').forEach(b => b.classList.remove('active'));
        btnAll.classList.add('active');
        state.filterZone = 'all';
        renderCalls();
    });

    if (rightGroup) bar.appendChild(rightGroup);
}

// ─── Chamadas ─────────────────────────────────────────────────────────────────
function renderCalls() {
    const list   = document.getElementById('route-list');
    const filter = state.filterZone;
    list.innerHTML = '';

    const playerLevel = (state.playerData && state.playerData.level) || 1;

    state.calls
        .filter(c => filter === 'all' || c.zone === filter)
        .forEach(call => {
            const zone       = state.zones[call.zone] || {};
            const isLocked   = playerLevel < (call.minLevel || 1);
            const payRange   = `R$ ${(call.basePay).toLocaleString('pt-BR')} – ${(Math.floor(call.basePay * 1.5)).toLocaleString('pt-BR')}`;

            const card = document.createElement('div');
            card.className = 'route-card' + (isLocked ? ' locked' : '');

            card.innerHTML = `
                <div class="route-company-tag" style="background:${zone.color || '#555'}22;color:${zone.color || '#aaa'};border:1px solid ${zone.color || '#555'}55">
                    ${zone.label || call.zone}
                </div>
                <div class="route-info">
                    <div class="route-name">${call.label}</div>
                    <div class="route-meta">
                        <span>Distância: ${call.distance}</span>
                        ${isLocked ? `<span style="color:#f87171;display:inline-flex;align-items:center;gap:3px"><svg class="icon icon-xs" aria-hidden="true"><use href="#icon-lock"/></svg> Nível ${call.minLevel}</span>` : ''}
                    </div>
                </div>
                <div class="route-right">
                    <div class="route-pay">${payRange}</div>
                    <div class="route-xp">+${call.baseXP} XP base</div>
                </div>
            `;

            if (!isLocked) {
                card.addEventListener('click', () => {
                    if (!state.hasRentedTruck) {
                        if (state.isItem) {
                            nuiPost('notify', { title: 'Sem Táxi', description: 'Vá a central de taxistas para pegar um veículo.', type: 'warning' });
                        } else {
                            switchTab('rent');
                        }
                        return;
                    }
                    openCallModal(call);
                });
            }
            list.appendChild(card);
        });

    if (list.children.length === 0) {
        list.innerHTML = '<div class="empty-state">Nenhuma chamada disponível para este filtro.</div>';
    }
}

// ─── Modal de Chamada ─────────────────────────────────────────────────────────
function openCallModal(call) {
    state.selectedCall = call;

    document.getElementById('modal-route-name').textContent = call.label;
    
    const list = document.getElementById('cargo-list');
    list.innerHTML = `
        <div style="font-size: 13px; color: var(--text-muted); text-align: center; margin: 10px 0;">
            Você será direcionado para o local de coleta de passageiro(s) na zona <b>${state.zones[call.zone]?.label || call.zone}</b>.
        </div>
    `;

    document.getElementById('modal-start').disabled = false;
    document.getElementById('cargo-modal').classList.remove('hidden');
}

function closeCallModal() {
    document.getElementById('cargo-modal').classList.add('hidden');
    state.selectedCall = null;
}

// ─── Histórico ───────────────────────────────────────────────────────────────
function renderHistory() {
    const list    = document.getElementById('history-list');
    const history = (state.playerData && state.playerData.history) || [];
    list.innerHTML = '';

    if (!history.length) {
        list.innerHTML = '<div class="empty-state">Nenhuma corrida registrada ainda.</div>';
        return;
    }

    history.forEach(entry => {
        const condColor = entry.condition >= 80 ? '#2ea043' : entry.condition >= 50 ? '#f59e0b' : '#da3633';
        const el = document.createElement('div');
        el.className = 'history-item';
        el.innerHTML = `
            <div class="history-icon"><svg class="icon" aria-hidden="true"><use href="#icon-package"/></svg></div>
            <div class="history-info">
                <div class="history-route">${entry.call || '—'}</div>
                <div class="history-cargo">Satisfação: <span style="color:${condColor}">${entry.condition || 0}%</span></div>
            </div>
            <div class="history-right">
                <div class="history-pay">+R$ ${(entry.pay || 0).toLocaleString('pt-BR')}</div>
                <div class="history-xp">+${entry.xp || 0} XP</div>
                <div class="history-date">${entry.date || ''}</div>
            </div>
        `;
        list.appendChild(el);
    });
}

// ─── Ranking ─────────────────────────────────────────────────────────────────
let currentRankingCategory = 'xp';

async function renderRanking() {
    const list = document.getElementById('ranking-list');
    list.innerHTML = '<div class="empty-state">Carregando ranking...</div>';

    try {
        const res = await nuiPost('getRanking', { category: currentRankingCategory });
        const ranking = await res.json();

        list.innerHTML = '';

        if (!ranking || !ranking.length) {
            list.innerHTML = '<div class="empty-state">Nenhum dado encontrado no ranking.</div>';
            return;
        }

        ranking.forEach((player, index) => {
            let metricHtml = '';
            
            if (currentRankingCategory === 'xp') {
                metricHtml = `
                    <div class="ranking-right">
                        <div class="ranking-level" style="font-size: 14px;">${player.xp} XP</div>
                    </div>`;
            } else if (currentRankingCategory === 'level') {
                metricHtml = `
                    <div class="ranking-right">
                        <div class="ranking-level" style="font-size: 14px;">Nível ${player.level}</div>
                    </div>`;
            } else if (currentRankingCategory === 'deliveries') {
                metricHtml = `
                    <div class="ranking-right">
                        <div class="ranking-level" style="font-size: 14px;">${player.total_deliveries} Corridas</div>
                    </div>`;
            }

            const el = document.createElement('div');
            el.className = 'ranking-item';
            el.innerHTML = `
                <div class="ranking-pos">#${index + 1}</div>
                <div class="ranking-icon"><svg class="icon" aria-hidden="true"><use href="#icon-trophy"/></svg></div>
                <div class="ranking-info">
                    <div class="ranking-name">${player.name}</div>
                </div>
                ${metricHtml}
            `;
            list.appendChild(el);
        });
    } catch (e) {
        list.innerHTML = '<div class="empty-state">Erro ao carregar o ranking.</div>';
    }
}

// ─── HUD ─────────────────────────────────────────────────────────────────────
function showHUD(data) {
    const hud = document.getElementById('job-hud');
    hud.classList.remove('hidden');
    document.getElementById('hud-route').textContent = data.route || '—';
    
    if (data.cargo) {
        document.getElementById('hud-cargo').textContent = data.cargo;
        const cargoLine = document.querySelector('.hud-cargo-line');
        const sep = document.querySelector('.hud-sep');
        if (data.cargo === 'Nenhum') {
            if(cargoLine) cargoLine.style.display = 'none';
            if(sep) sep.style.display = 'none';
        } else {
            if(cargoLine) cargoLine.style.display = 'inline-flex';
            if(sep) sep.style.display = 'inline-block';
        }
    }
    
    updateHUD(data);
}

function updateHUD(data) {
    const cond    = data.condition ?? 100;
    const bar     = document.getElementById('hud-condition-bar');
    const valEl   = document.getElementById('hud-condition-val');
    const timeEl  = document.getElementById('hud-time');
    const rentEl  = document.getElementById('hud-rental-time');

    if(bar) {
        bar.style.width = `${cond}%`;
        bar.style.background = cond >= 70 ? 'var(--color-primary)'
                             : cond >= 40 ? '#fbbf24'
                             :              '#f87171';
    }

    if(valEl) {
        valEl.style.color = cond >= 70 ? 'var(--color-fg)'
                          : cond >= 40 ? '#fbbf24'
                          :              '#f87171';
        valEl.textContent = `${Math.floor(cond)}%`;
    }

    if(timeEl) timeEl.textContent = data.timeLeft || '--:--';
    if(rentEl) rentEl.textContent = `Aluguel: ${data.rentalTimeLeft || '--:--'}`;

    if (data.cargo) {
        document.getElementById('hud-cargo').textContent = data.cargo;
        const cargoLine = document.querySelector('.hud-cargo-line');
        const sep = document.querySelector('.hud-sep');
        if (data.cargo === 'Nenhum') {
            if(cargoLine) cargoLine.style.display = 'none';
            if(sep) sep.style.display = 'none';
        } else {
            if(cargoLine) cargoLine.style.display = 'inline-flex';
            if(sep) sep.style.display = 'inline-block';
        }
    }
}

function hideHUD() {
    document.getElementById('job-hud').classList.add('hidden');
}

// ─── Formatação ───────────────────────────────────────────────────────────────
function formatMoney(val) {
    return 'R$ ' + Number(val).toLocaleString('pt-BR');
}

// ─── Mensagens do Lua ────────────────────────────────────────────────────────
window.addEventListener('message', e => {
    const { type, ...data } = e.data;

    if (type === 'show') {
        state.isItem      = data.isItem || false;
        state.playerData  = data.playerData;
        state.calls       = data.calls       || [];
        state.genInterval = data.genInterval || 30;
        state.zones       = data.zones       || {};
        state.levels      = data.levels      || {};
        state.rentOptions = data.rentOptions || [];
        state.buyOptions  = data.buyOptions  || [];
        state.ownedTaxis  = data.ownedTaxis  || [];
        state.hasRentedTruck = data.hasRentedTruck || false;
        state.activeJob      = data.activeJob      || null;

        if (data.accentColor) applyAccentColor(data.accentColor);

        const btnRent = document.querySelector('[data-tab="rent"]');
        const btnBuy = document.querySelector('[data-tab="buy"]');
        const btnGarage = document.querySelector('[data-tab="garage"]');
        const btnGoRent = document.getElementById('btn-go-rent');
        
        if (state.isItem) {
            if (btnRent) btnRent.style.display = 'none';
            if (btnBuy) btnBuy.style.display = 'none';
            if (btnGarage) btnGarage.style.display = 'none';
            if (btnGoRent) btnGoRent.textContent = 'Marcar no GPS';
        } else {
            if (btnRent) btnRent.style.display = '';
            if (btnBuy) btnBuy.style.display = '';
            if (btnGarage) btnGarage.style.display = '';
            if (btnGoRent) btnGoRent.textContent = 'Ir para Garagem';
        }

        renderFilterZones();
        applyRentState(state.hasRentedTruck);
        document.getElementById('app').classList.remove('hidden');
        switchTab('dashboard');
        renderDashboard();
        renderCalls();
        return;
    }

    if (type === 'hide') {
        document.getElementById('app').classList.add('hidden');
        closeCallModal();
        return;
    }

    if (type === 'updateCalls') {
        state.calls = data.calls || [];
        if (state.currentTab === 'routes') {
            renderCalls();
        }
        return;
    }

    if (type === 'showHUD')   { showHUD(data);   return; }
    if (type === 'updateHUD') { updateHUD(data);  return; }
    if (type === 'hideHUD')   { hideHUD();        return; }

    if (type === 'updatePlayer') {
        state.playerData = data;
        state.ownedTaxis = data.ownedTaxis || state.ownedTaxis;
        if (state.currentTab === 'dashboard') renderDashboard();
        if (state.currentTab === 'rent') renderRentSection();
        if (state.currentTab === 'buy') renderBuySection();
        if (state.currentTab === 'garage') renderGarageSection();
        return;
    }

    if (type === 'updateRentState') {
        applyRentState(data.hasRentedTruck);
        return;
    }

    if (type === 'playTTS') {
        if ('speechSynthesis' in window) {
            const utter = new SpeechSynthesisUtterance(data.text);
            utter.lang = 'pt-BR';
            utter.pitch = data.gender === 'female' ? 1.5 : 0.8;
            utter.rate = 1.1;
            window.speechSynthesis.speak(utter);
        }
        return;
    }

    if (type === 'playAudio') {
        if (data.audio) {
            const audio = new Audio(data.audio);
            audio.volume = 0.8;
            audio.play().catch(e => console.error("Erro ao reproduzir áudio:", e));
        }
        return;
    }
});

// ─── Event Listeners ─────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {

    const themeToggle = document.getElementById('theme-toggle');
    const savedTheme  = localStorage.getItem('mri_taxi_theme') || 'dark';
    document.documentElement.setAttribute('data-theme', savedTheme);
    themeToggle.addEventListener('click', () => {
        const next = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
        document.documentElement.setAttribute('data-theme', next);
        localStorage.setItem('mri_taxi_theme', next);
    });

    document.querySelectorAll('.nav-btn').forEach(btn => {
        btn.addEventListener('click', () => switchTab(btn.dataset.tab));
    });

    document.getElementById('close-btn').addEventListener('click', () => {
        nuiPost('closeMenu');
    });

    document.getElementById('overlay').addEventListener('click', () => {
        nuiPost('closeMenu');
    });

    document.querySelectorAll('.ranking-filter-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.ranking-filter-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            currentRankingCategory = btn.dataset.ranking;
            renderRanking();
        });
    });

    // Botão aleatório removido

    document.getElementById('modal-cancel').addEventListener('click', closeCallModal);

    document.getElementById('modal-start').addEventListener('click', () => {
        if (!state.selectedCall) return;
        const callId  = state.selectedCall.id;
        closeCallModal();
        nuiPost('startJob', { callId });
    });

    document.getElementById('btn-return-truck').addEventListener('click', () => {
        nuiPost('returnTaxi');
    });

    document.getElementById('btn-go-rent').addEventListener('click', () => {
        if (state.isItem) {
            nuiPost('waypointCentral');
        } else {
            switchTab('rent');
        }
    });

    document.getElementById('btn-cancel-job-dash').addEventListener('click', () => {
        nuiPost('cancelJob');
    });

    document.addEventListener('keydown', e => {
        if (e.key === 'Escape') nuiPost('closeMenu');
    });
});


