'use strict';

// === GAME CONFIGURATION ===
const WORLD_WIDTH = 800;
const WORLD_HEIGHT = 600;
const PLAYER_SIZE = 30;
const BULLET_SIZE = 6;
const BULLET_SPEED = 300;
const BULLET_DAMAGE = 20;
const BULLET_LIFETIME_MS = 3000;
const PLAYER_SPEED = 120;
const HEALTH_ITEM_SIZE = 20;
const HEALTH_ITEM_HEAL = 30;
const HEALTH_ITEM_SPAWN_INTERVAL_MS = 15000;
const MAX_HEALTH = 100;
const WAITING_DURATION_MS = 30000;
const SHOOT_COOLDOWN_MS = 500;
const TARGET_FPS_FALLBACK = 60;
const WALL_COUNT = 8;

// Player colors for up to 10 players
const PLAYER_COLORS = [
    '#E53935', '#1E88E5', '#43A047', '#FB8C00',
    '#8E24AA', '#00ACC1', '#F4511E', '#3949AB',
    '#7CB342', '#D81B60'
];

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
        this.walls = [];
        // Generate some random walls for cover
        const wallDefs = [
            { x: 150, y: 100, w: 80, h: 20 },
            { x: 350, y: 200, w: 20, h: 100 },
            { x: 550, y: 150, w: 80, h: 20 },
            { x: 200, y: 350, w: 100, h: 20 },
            { x: 500, y: 400, w: 20, h: 80 },
            { x: 100, y: 450, w: 80, h: 20 },
            { x: 650, y: 300, w: 20, h: 100 },
            { x: 400, y: 480, w: 80, h: 20 },
        ];
        this.walls = wallDefs;
    }

    addClient(id) {
        const spawn = this.getSpawnPosition(this.players.size);
        const colorIndex = this.nextJoinOrder % PLAYER_COLORS.length;
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
            direction: 'none',
            score: 0,
            kills: 0,
            joinOrder: this.nextJoinOrder++,
            color: PLAYER_COLORS[colorIndex],
            lastShot: 0,
            aimAngle: 0,
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
                case 'direction':
                    player.direction = obj.value || 'none';
                    break;
                case 'shoot':
                    if (player.alive && this.phase === 'playing') {
                        this.playerShoot(player, obj.angle || 0);
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

    playerShoot(player, angle) {
        const now = Date.now();
        if (now - player.lastShot < SHOOT_COOLDOWN_MS) return;
        player.lastShot = now;

        const centerX = player.x + player.width / 2;
        const centerY = player.y + player.height / 2;
        const spawnDist = player.width / 2 + BULLET_SIZE;

        this.bullets.push({
            id: this.nextBulletId++,
            ownerId: player.id,
            x: centerX + Math.cos(angle) * spawnDist,
            y: centerY + Math.sin(angle) * spawnDist,
            vx: Math.cos(angle) * BULLET_SPEED,
            vy: Math.sin(angle) * BULLET_SPEED,
            size: BULLET_SIZE,
            createdAt: now,
            damage: BULLET_DAMAGE,
        });
    }

    updateGame(fps) {
        if (this.players.size <= 0) return;

        const safeFps = Math.max(1, fps || TARGET_FPS_FALLBACK);
        const dt = 1 / safeFps;

        // === WAITING PHASE ===
        if (this.phase === 'waiting') {
            if (this.lobbyEndsAt == null) {
                this.startWaitingRoom();
            }
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
                case 'up': dy = -1; break;
                case 'down': dy = 1; break;
                case 'left': dx = -1; break;
                case 'right': dx = 1; break;
                case 'upLeft': dx = -0.707; dy = -0.707; break;
                case 'upRight': dx = 0.707; dy = -0.707; break;
                case 'downLeft': dx = -0.707; dy = 0.707; break;
                case 'downRight': dx = 0.707; dy = 0.707; break;
            }

            const newX = player.x + dx * PLAYER_SPEED * dt;
            const newY = player.y + dy * PLAYER_SPEED * dt;

            // Check wall collisions
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

            // Remove if out of bounds or expired
            if (bullet.x < -10 || bullet.x > WORLD_WIDTH + 10 ||
                bullet.y < -10 || bullet.y > WORLD_HEIGHT + 10 ||
                now - bullet.createdAt > BULLET_LIFETIME_MS) {
                return false;
            }

            // Check wall collision
            if (this.collidesWithWall(bullet.x - bullet.size/2, bullet.y - bullet.size/2, bullet.size, bullet.size)) {
                return false;
            }

            // Check player collision
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
                        // Credit kill to shooter
                        const shooter = this.players.get(bullet.ownerId);
                        if (shooter) {
                            shooter.kills++;
                            shooter.score += 100;
                        }
                    }
                    return false; // Remove bullet
                }
            }

            return true;
        });

        // === HEALTH ITEMS ===
        if (now - this.lastHealthSpawn > HEALTH_ITEM_SPAWN_INTERVAL_MS) {
            this.spawnHealthItem();
            this.lastHealthSpawn = now;
        }

        // Check health item pickups
        this.healthItems = this.healthItems.filter(item => {
            for (const player of this.players.values()) {
                if (!player.alive) continue;
                if (this.rectsOverlap(
                    item.x, item.y, HEALTH_ITEM_SIZE, HEALTH_ITEM_SIZE,
                    player.x, player.y, player.width, player.height
                )) {
                    player.health = Math.min(MAX_HEALTH, player.health + HEALTH_ITEM_HEAL);
                    return false; // Remove item
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
            if (this.rectsOverlap(x, y, w, h, wall.x, wall.y, wall.w, wall.h)) {
                return true;
            }
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

        this.healthItems.push({
            id: this.nextItemId++,
            x, y,
            width: HEALTH_ITEM_SIZE,
            height: HEALTH_ITEM_SIZE,
        });
    }

    getSpawnPosition(index) {
        const positions = [
            { x: 50, y: 50 },
            { x: WORLD_WIDTH - 80, y: 50 },
            { x: 50, y: WORLD_HEIGHT - 80 },
            { x: WORLD_WIDTH - 80, y: WORLD_HEIGHT - 80 },
            { x: WORLD_WIDTH / 2, y: 50 },
            { x: WORLD_WIDTH / 2, y: WORLD_HEIGHT - 80 },
            { x: 50, y: WORLD_HEIGHT / 2 },
            { x: WORLD_WIDTH - 80, y: WORLD_HEIGHT / 2 },
            { x: WORLD_WIDTH / 4, y: WORLD_HEIGHT / 4 },
            { x: 3 * WORLD_WIDTH / 4, y: 3 * WORLD_HEIGHT / 4 },
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

        // Reset all players
        for (const player of this.players.values()) {
            player.health = MAX_HEALTH;
            player.alive = true;
            player.kills = 0;
            player.score = 0;
        }
    }

    finishMatch(winner) {
        this.phase = 'finished';
        if (winner) {
            this.winnerId = winner.id;
            this.winnerName = winner.name;
            winner.score += 500; // Bonus for winning
        }
    }

    restartToWaitingRoom() {
        if (this.players.size <= 0) {
            this.resetMatch();
            return;
        }
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
            player.direction = 'none';
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
            players: players.map(p => ({
                id: p.id,
                name: p.name,
                color: p.color,
                width: p.width,
                height: p.height,
                joinOrder: p.joinOrder,
            })),
        };
    }

    getGameplayStateForPlayer(playerId, options = {}) {
        const includeOtherPlayers = options.includeOtherPlayers !== false;
        const includeGems = options.includeGems !== false; // We use this for healthItems

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
                id: item.id,
                x: item.x,
                y: item.y,
                width: item.width,
                height: item.height,
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
            color: player.color,
            kills: player.kills,
            score: player.score,
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
            }));
    }
}

module.exports = GameLogic;
