'use strict';

// === GAME CONFIGURATION ===
const WORLD_WIDTH = 1024;
const WORLD_HEIGHT = 512;
const PLAYER_SIZE = 32;
const BULLET_SIZE = 8;
const BULLET_SPEED = 280;
const BULLET_DAMAGE = 20;
const BULLET_LIFETIME_MS = 3000;
const PLAYER_SPEED = 120;
const HEALTH_ITEM_SIZE = 20;
const HEALTH_ITEM_HEAL = 30;
const HEALTH_ITEM_SPAWN_INTERVAL_MS = 15000;
const MAX_HEALTH = 100;
const WAITING_DURATION_MS = 30000;
const SHOOT_COOLDOWN_MS = 600;
const TARGET_FPS_FALLBACK = 60;
const WALL_COUNT = 8;

// === POKEMON DATA (up to 10 players) ===
// element is used by the client to colour the projectile
const POKEMON_DATA = {
    axew:       { name: 'Axew',       color: '#709C64', element: 'dragon'   },
    buizel:     { name: 'Buizel',     color: '#E8A33A', element: 'water'    },
    chimchar:   { name: 'Chimchar',   color: '#E67E22', element: 'fire'     },
    misdreavus: { name: 'Misdreavus', color: '#4E5B70', element: 'ghost'    },
    pikachu:    { name: 'Pikachu',    color: '#F4D03F', element: 'electric' },
    riolu:      { name: 'Riolu',      color: '#2471A3', element: 'fighting' },
    rockruff:   { name: 'Rockruff',   color: '#B6A181', element: 'rock'     },
    rowlet:     { name: 'Rowlet',     color: '#27AE60', element: 'grass'    },
    snorunt:    { name: 'Snorunt',    color: '#E0E0E0', element: 'ice'      },
    trapinch:   { name: 'Trapinch',   color: '#D35400', element: 'ground'   },
};

const POKEMON_IDS = Object.keys(POKEMON_DATA);

// Colour of each bullet element
const ELEMENT_COLORS = {
    dragon:   '#7038F8',
    water:    '#3498DB',
    fire:     '#E74C3C',
    ghost:    '#705898',
    electric: '#F4D03F',
    fighting: '#C03028',
    rock:     '#B8A038',
    grass:    '#2ECC71',
    ice:      '#98D8D8',
    ground:   '#E0C068',
};

class GameLogic {
    constructor() {
        this.players = new Map();
        this.bullets = [];
        this.healthItems = [];
        this.walls = [];
        this.nextBulletId = 0;
        this.nextItemId = 0;
        this.nextJoinOrder = 0;
        this.phase = 'waiting'; // waiting, playing, finished
        this.lobbyEndsAt = null;
        this.winnerId = '';
        this.winnerName = '';
        this.lastHealthSpawn = Date.now();
        this.initialStateDirty = true;

        this.generateWalls();
    }

    generateWalls() {
        this.walls = [
            // Stones 0 (layer 000)
            { x: 320, y: 80, w: 32, h: 80 },
            // Stones10 (layer 001)
            { x: 640, y: 304, w: 80, h: 32 },
            // AGUA2 (layer 002)
            { x: 48, y: 64, w: 192, h: 112 },
            // AGUA3 (layer 003)
            { x: 48, y: 161, w: 288, h: 112 },
            // CASA (layer 004)
            { x: 639, y: 204, w: 240, h: 80 },
            // CASA (layer 005)
            { x: 402, y: 34, w: 112, h: 128 },
            // CASA2 (layer 006)
            { x: 816, y: -1, w: 96, h: 128 },
            // STONE1 (layer 007)
            { x: 528, y: 400, w: 32, h: 80 },
            // Stones 2 (layer 008)
            { x: 656, y: 80, w: 80, h: 32 },
            // Stones 3 (layer 009)
            { x: 48, y: 400, w: 80, h: 32 },
            // Rocas derecha (layer 011 - Path)
            { x: 832, y: 272, w: 160, h: 80 },
        ];
    }

    addClient(id) {
        const spawn = this.getSpawnPosition(this.players.size);
        const defaultPokemon = POKEMON_IDS[this.nextJoinOrder % POKEMON_IDS.length];
        const pokeData = POKEMON_DATA[defaultPokemon];

        const player = {
            id,
            name: `Jugador ${this.players.size + 1}`,
            x: spawn.x,
            y: spawn.y,
            width: PLAYER_SIZE,
            height: PLAYER_SIZE,
            health: MAX_HEALTH,
            maxHealth: MAX_HEALTH,
            alive: true,
            direction: 'down',   // Pokémon always face a direction (default down)
            facing: 'down',      // Last non-none direction (for shooting)
            score: 0,
            kills: 0,
            joinOrder: this.nextJoinOrder++,
            pokemonId: defaultPokemon,
            color: pokeData.color,
            element: pokeData.element,
            lastShot: 0,
        };
        this.players.set(id, player);
        this.initialStateDirty = true;

        if (this.players.size === 1) {
            this.startWaitingRoom();
        }

        return player;
    }

    removeClient(id) {
        this.players.delete(id);
        this.initialStateDirty = true;
        if (this.players.size <= 0) {
            this.resetMatch();
            this.nextJoinOrder = 0;
        }
    }

    handleMessage(id, msg) {
        try {
            const obj = JSON.parse(msg);
            if (!obj || !obj.type) return false;

            const player = this.players.get(id);
            if (!player) return false;

            switch (obj.type) {
                case 'register': {
                    const name = (obj.playerName || '').trim().substring(0, 20);
                    if (name && name !== player.name) {
                        player.name = name;
                        this.initialStateDirty = true;
                        return true;
                    }
                    break;
                }

                case 'selectPokemon': {
                    // Only allow in waiting phase
                    if (this.phase !== 'waiting') break;
                    const pokemonId = (obj.pokemonId || '').trim();
                    if (!POKEMON_DATA[pokemonId]) break;

                    // Check no other alive player has this pokemon
                    let taken = false;
                    for (const [pid, p] of this.players) {
                        if (pid !== id && p.pokemonId === pokemonId) {
                            taken = true;
                            break;
                        }
                    }
                    if (taken) break;

                    const pokeData = POKEMON_DATA[pokemonId];
                    player.pokemonId = pokemonId;
                    player.color = pokeData.color;
                    player.element = pokeData.element;
                    this.initialStateDirty = true;
                    return true;
                }

                case 'direction':
                    player.direction = obj.value || 'none';
                    // Keep track of last real direction for shooting
                    if (obj.value && obj.value !== 'none') {
                        player.facing = obj.value;
                    }
                    break;

                case 'shoot':
                    if (player.alive && this.phase === 'playing') {
                        this.playerShoot(player);
                    }
                    break;

                case 'restartMatch':
                    if (this.phase === 'finished') {
                        this.restartToWaitingRoom();
                        return true;
                    }
                    break;
            }
        } catch (_) {}
        return false;
    }

    playerShoot(player) {
        const now = Date.now();
        if (now - player.lastShot < SHOOT_COOLDOWN_MS) return;
        player.lastShot = now;

        const centerX = player.x + player.width / 2;
        const centerY = player.y + player.height / 2;

        // Direction the Pokémon is facing determines bullet trajectory
        const facing = player.facing || 'down';
        const dirVectors = {
            up:        { vx: 0,     vy: -1 },
            down:      { vx: 0,     vy:  1 },
            left:      { vx: -1,    vy:  0 },
            right:     { vx: 1,     vy:  0 },
            upLeft:    { vx: -0.707, vy: -0.707 },
            upRight:   { vx:  0.707, vy: -0.707 },
            downLeft:  { vx: -0.707, vy:  0.707 },
            downRight: { vx:  0.707, vy:  0.707 },
        };

        const dir = dirVectors[facing] || dirVectors['down'];
        const spawnDist = player.width / 2 + BULLET_SIZE;

        this.bullets.push({
            id: this.nextBulletId++,
            ownerId: player.id,
            x: centerX + dir.vx * spawnDist,
            y: centerY + dir.vy * spawnDist,
            vx: dir.vx * BULLET_SPEED,
            vy: dir.vy * BULLET_SPEED,
            size: BULLET_SIZE,
            createdAt: now,
            damage: BULLET_DAMAGE,
            element: player.element,
        });
    }

    updateGame(fps) {
        if (this.players.size <= 0) return;

        const safeFps = Math.max(1, fps || TARGET_FPS_FALLBACK);
        const dt = 1 / safeFps;

        // === WAITING PHASE ===
        if (this.phase === 'waiting') {
            if (this.lobbyEndsAt == null) this.startWaitingRoom();
            if (this.lobbyEndsAt != null && Date.now() >= this.lobbyEndsAt) {
                this.startMatch();
            }
            return;
        }

        if (this.phase !== 'playing') return;

        // === MOVE PLAYERS ===
        for (const player of this.players.values()) {
            if (!player.alive) continue;

            let dx = 0, dy = 0;
            switch (player.direction) {
                case 'up':        dy = -1;     break;
                case 'down':      dy =  1;     break;
                case 'left':      dx = -1;     break;
                case 'right':     dx =  1;     break;
                case 'upLeft':    dx = -0.707; dy = -0.707; break;
                case 'upRight':   dx =  0.707; dy = -0.707; break;
                case 'downLeft':  dx = -0.707; dy =  0.707; break;
                case 'downRight': dx =  0.707; dy =  0.707; break;
            }

            const newX = player.x + dx * PLAYER_SPEED * dt;
            const newY = player.y + dy * PLAYER_SPEED * dt;

            if (!this.collidesWithWall(newX, player.y, player.width, player.height)) {
                player.x = Math.max(0, Math.min(WORLD_WIDTH - player.width, newX));
            }
            if (!this.collidesWithWall(player.x, newY, player.width, player.height)) {
                player.y = Math.max(0, Math.min(WORLD_HEIGHT - player.height, newY));
            }
        }

        // === MOVE BULLETS ===
        const now = Date.now();
        this.bullets = this.bullets.filter(bullet => {
            bullet.x += bullet.vx * dt;
            bullet.y += bullet.vy * dt;

            if (bullet.x < -10 || bullet.x > WORLD_WIDTH + 10 ||
                bullet.y < -10 || bullet.y > WORLD_HEIGHT + 10 ||
                now - bullet.createdAt > BULLET_LIFETIME_MS) {
                return false;
            }

            if (this.collidesWithWall(bullet.x - bullet.size/2, bullet.y - bullet.size/2, bullet.size, bullet.size)) {
                return false;
            }

            for (const player of this.players.values()) {
                if (!player.alive) continue;
                if (player.id === bullet.ownerId) continue;

                if (this.rectsOverlap(
                    bullet.x - bullet.size/2, bullet.y - bullet.size/2, bullet.size, bullet.size,
                    player.x, player.y, player.width, player.height
                )) {
                    player.health -= bullet.damage;
                    if (player.health <= 0) {
                        player.health = 0;
                        player.alive = false;
                        const shooter = this.players.get(bullet.ownerId);
                        if (shooter) {
                            shooter.kills++;
                            shooter.score += 100;
                        }
                    }
                    return false;
                }
            }

            return true;
        });

        // === HEALTH ITEMS ===
        if (now - this.lastHealthSpawn > HEALTH_ITEM_SPAWN_INTERVAL_MS) {
            this.spawnHealthItem();
            this.lastHealthSpawn = now;
        }

        this.healthItems = this.healthItems.filter(item => {
            for (const player of this.players.values()) {
                if (!player.alive) continue;
                if (this.rectsOverlap(
                    item.x, item.y, HEALTH_ITEM_SIZE, HEALTH_ITEM_SIZE,
                    player.x, player.y, player.width, player.height
                )) {
                    player.health = Math.min(MAX_HEALTH, player.health + HEALTH_ITEM_HEAL);
                    return false;
                }
            }
            return true;
        });

        // === CHECK WIN CONDITION ===
        const alivePlayers = Array.from(this.players.values()).filter(p => p.alive);
        if (alivePlayers.length <= 1 && this.players.size > 1) {
            this.finishMatch(alivePlayers[0]);
        }
    }

    collidesWithWall(x, y, w, h) {
        for (const wall of this.walls) {
            if (this.rectsOverlap(x, y, w, h, wall.x, wall.y, wall.w, wall.h)) return true;
        }
        return false;
    }

    rectsOverlap(x1, y1, w1, h1, x2, y2, w2, h2) {
        return x1 < x2 + w2 && x1 + w1 > x2 && y1 < y2 + h2 && y1 + h1 > y2;
    }

    spawnHealthItem() {
        let x, y, attempts = 0;
        do {
            x = Math.random() * (WORLD_WIDTH - HEALTH_ITEM_SIZE);
            y = Math.random() * (WORLD_HEIGHT - HEALTH_ITEM_SIZE);
            attempts++;
        } while (this.collidesWithWall(x, y, HEALTH_ITEM_SIZE, HEALTH_ITEM_SIZE) && attempts < 50);

        this.healthItems.push({ id: this.nextItemId++, x, y, width: HEALTH_ITEM_SIZE, height: HEALTH_ITEM_SIZE });
    }

    getSpawnPosition(index) {
        const positions = [
            { x: 10,  y: 10 },   // Top left
            { x: 280, y: 20 },   // Top mid-left
            { x: 550, y: 20 },   // Top mid-right
            { x: 950, y: 20 },   // Top right
            { x: 950, y: 450 },  // Bottom right
            { x: 150, y: 450 },  // Bottom left
            { x: 10,  y: 300 },  // Mid left
            { x: 450, y: 250 },  // Center
            { x: 800, y: 400 },  // Bottom mid-right
            { x: 350, y: 350 },  // Bottom mid-left
        ];
        return positions[index % positions.length];
    }

    startWaitingRoom() {
        this.phase = 'waiting';
        this.winnerId = '';
        this.winnerName = '';
        this.lobbyEndsAt = Date.now() + WAITING_DURATION_MS;
        this.initialStateDirty = true;
        this.bullets = [];
        this.healthItems = [];
        this.generateWalls();
        this.positionPlayersForStart();
    }

    startMatch() {
        this.phase = 'playing';
        this.winnerId = '';
        this.winnerName = '';
        this.lobbyEndsAt = null;
        this.bullets = [];
        this.healthItems = [];
        this.lastHealthSpawn = Date.now();
        this.positionPlayersForStart();
        for (const player of this.players.values()) {
            player.health = MAX_HEALTH;
            player.alive = true;
            player.kills = 0;
            player.score = 0;
            player.direction = 'down';
            player.facing = 'down';
        }
    }

    finishMatch(winner) {
        this.phase = 'finished';
        if (winner) {
            this.winnerId = winner.id;
            this.winnerName = winner.name;
            winner.score += 500;
        }
    }

    restartToWaitingRoom() {
        if (this.players.size <= 0) { this.resetMatch(); return; }
        this.startWaitingRoom();
    }

    resetMatch() {
        this.phase = 'waiting';
        this.lobbyEndsAt = null;
        this.winnerId = '';
        this.winnerName = '';
        this.bullets = [];
        this.healthItems = [];
        this.initialStateDirty = true;
    }

    positionPlayersForStart() {
        const players = Array.from(this.players.values()).sort((a, b) => a.joinOrder - b.joinOrder);
        players.forEach((player, index) => {
            const spawn = this.getSpawnPosition(index);
            player.x = spawn.x;
            player.y = spawn.y;
            player.direction = 'down';
            player.facing = 'down';
            player.health = MAX_HEALTH;
            player.alive = true;
            player.kills = 0;
            player.score = 0;
        });
    }

    // === STATE SERIALIZATION ===

    consumeSnapshotState() {
        if (!this.initialStateDirty) return null;
        this.initialStateDirty = false;
        return this.getSnapshotState();
    }

    getSnapshotState() {
        const players = Array.from(this.players.values()).sort((a, b) => a.joinOrder - b.joinOrder);
        return {
            worldWidth: WORLD_WIDTH,
            worldHeight: WORLD_HEIGHT,
            walls: this.walls,
            pokemonList: POKEMON_IDS.map(id => ({
                id,
                name: POKEMON_DATA[id].name,
                color: POKEMON_DATA[id].color,
                element: POKEMON_DATA[id].element,
            })),
            players: players.map(p => ({
                id: p.id,
                name: p.name,
                color: p.color,
                width: p.width,
                height: p.height,
                joinOrder: p.joinOrder,
                pokemonId: p.pokemonId,
                element: p.element,
            })),
        };
    }

    getGameplayStateForPlayer(playerId, options = {}) {
        const includeOtherPlayers = options.includeOtherPlayers !== false;
        const includeGems = options.includeGems !== false;

        const selfPlayer = this.players.get(playerId);
        const countdownSeconds = this.phase === 'waiting' && this.lobbyEndsAt != null
            ? Math.max(0, Math.ceil((this.lobbyEndsAt - Date.now()) / 1000))
            : 0;

        const state = {
            phase: this.phase,
            countdownSeconds,
            winnerId: this.winnerId,
            winnerName: this.winnerName,
            selfPlayer: selfPlayer ? this.serializePlayer(selfPlayer) : null,
            bullets: this.bullets.map(b => ({
                id: b.id,
                x: Math.round(b.x * 100) / 100,
                y: Math.round(b.y * 100) / 100,
                ownerId: b.ownerId,
                size: b.size,
                element: b.element,
            })),
            ranking: this.getRanking(),
        };

        if (includeOtherPlayers) {
            state.otherPlayers = Array.from(this.players.values())
                .filter(p => p.id !== playerId)
                .map(p => this.serializePlayer(p));
        }

        if (includeGems) {
            state.healthItems = this.healthItems.map(item => ({
                id: item.id, x: item.x, y: item.y, width: item.width, height: item.height,
            }));
        }

        return state;
    }

    serializePlayer(player) {
        return {
            id: player.id,
            name: player.name,
            x: Math.round(player.x * 100) / 100,
            y: Math.round(player.y * 100) / 100,
            health: player.health,
            maxHealth: player.maxHealth,
            alive: player.alive,
            direction: player.direction,
            facing: player.facing,
            color: player.color,
            kills: player.kills,
            score: player.score,
            pokemonId: player.pokemonId,
            element: player.element,
        };
    }

    getRanking() {
        return Array.from(this.players.values())
            .sort((a, b) => {
                if (a.alive !== b.alive) return a.alive ? -1 : 1;
                return b.score - a.score;
            })
            .map((p, index) => ({
                rank: index + 1,
                id: p.id,
                name: p.name,
                kills: p.kills,
                score: p.score,
                alive: p.alive,
                color: p.color,
                pokemonId: p.pokemonId,
            }));
    }
}

module.exports = GameLogic;
