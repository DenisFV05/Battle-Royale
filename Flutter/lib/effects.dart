import 'dart:math' as math;
import 'dart:ui' as ui;

import 'libgdx_compat/game_framework.dart';

// ─── Visual Effects System ────────────────────────────────────────────────────

abstract class GameEffect {
  double elapsed = 0;
  double get duration;
  bool get isDone => elapsed >= duration;

  void update(double delta) {
    elapsed += delta;
  }

  void render(ShapeRenderer shapes);
}

// ─── Explosion Effect (death) ─────────────────────────────────────────────────

class ExplosionEffect extends GameEffect {
  final double x;
  final double y;
  final ui.Color color;
  final int particleCount;
  final double maxRadius;
  final List<_Particle> _particles;

  @override
  final double duration;

  ExplosionEffect({
    required this.x,
    required this.y,
    this.color = const ui.Color(0xFFFF6B35),
    this.particleCount = 12,
    this.maxRadius = 40,
    this.duration = 0.8,
  }) : _particles = List.generate(particleCount, (i) {
    final rng = math.Random(i * 31 + x.toInt());
    final angle = (i / particleCount) * math.pi * 2 + rng.nextDouble() * 0.3;
    final speed = 40.0 + rng.nextDouble() * 80.0;
    final size = 2.0 + rng.nextDouble() * 4.0;
    return _Particle(
      angle: angle,
      speed: speed,
      size: size,
      color: _randomFireColor(rng),
    );
  });

  static ui.Color _randomFireColor(math.Random rng) {
    final colors = [
      const ui.Color(0xFFFF6B35), // orange
      const ui.Color(0xFFFFE07A), // yellow
      const ui.Color(0xFFE74C3C), // red
      const ui.Color(0xFFFF9F43), // light orange
      const ui.Color(0xFFFFFFFF), // white core
    ];
    return colors[rng.nextInt(colors.length)];
  }

  @override
  void render(ShapeRenderer shapes) {
    if (isDone) return;
    final progress = (elapsed / duration).clamp(0.0, 1.0);
    final alpha = ((1.0 - progress) * 255).toInt().clamp(0, 255);

    shapes.begin(ShapeType.filled);
    for (final p in _particles) {
      final dist = p.speed * progress * 1.5;
      final px = x + math.cos(p.angle) * dist;
      final py = y + math.sin(p.angle) * dist;
      final size = p.size * (1.0 - progress * 0.5);
      shapes.setColor(p.color.withAlpha(alpha));
      shapes.circle(px, py, size, 6);
    }
    shapes.end();

    // Shockwave ring
    if (progress < 0.5) {
      final ringProgress = progress * 2;
      final ringRadius = maxRadius * ringProgress;
      final ringAlpha = ((1.0 - ringProgress) * 150).toInt().clamp(0, 255);
      shapes.begin(ShapeType.line);
      shapes.setColor(const ui.Color(0xFFFFE07A).withAlpha(ringAlpha));
      shapes.circle(x, y, ringRadius, 20);
      shapes.end();
    }
  }
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final ui.Color color;

  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
  });
}

// ─── Damage Flash Tracker ─────────────────────────────────────────────────────

class DamageTracker {
  final Map<String, double> _lastDamageTime = {};
  final Map<String, int> _lastHealth = {};
  static const double flashDuration = 0.25;

  void update(String playerId, int health, double gameTime) {
    final prevHealth = _lastHealth[playerId];
    if (prevHealth != null && health < prevHealth) {
      _lastDamageTime[playerId] = gameTime;
    }
    _lastHealth[playerId] = health;
  }

  bool isFlashing(String playerId, double gameTime) {
    final lastDmg = _lastDamageTime[playerId];
    if (lastDmg == null) return false;
    return (gameTime - lastDmg) < flashDuration;
  }

  void removePlayer(String playerId) {
    _lastDamageTime.remove(playerId);
    _lastHealth.remove(playerId);
  }
}

// ─── Effects Manager ──────────────────────────────────────────────────────────

class EffectsManager {
  final List<GameEffect> _effects = [];

  void add(GameEffect effect) {
    _effects.add(effect);
  }

  void update(double delta) {
    for (final effect in _effects) {
      effect.update(delta);
    }
    _effects.removeWhere((e) => e.isDone);
  }

  void render(ShapeRenderer shapes) {
    for (final effect in _effects) {
      effect.render(shapes);
    }
  }

  void clear() {
    _effects.clear();
  }
}
