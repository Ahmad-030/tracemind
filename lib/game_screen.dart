import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  TraceMind — game_screen.dart  (v6 — Redesigned Mazes + Faster Clone)
//
//  Changes vs v5:
//    • ALL mazes redesigned: row 0 fully clear on every level
//    • Mazes use interior walls only (rows 1-9, cols 0-9)
//    • Clone speed significantly increased across all tiers
//    • Countdown times reduced (tier 1: 2s, tier 2-3: 1s, tier 4-5: 1s)
//    • Ghost tick: tier1=280ms, tier2=210ms, tier3=160ms, tier4=110ms, tier5=75ms
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Palette ──────────────────────────────────────────────────────────────────

class _C {
  static const bg           = Color(0xFF02020A);
  static const bgDeep       = Color(0xFF000005);
  static const surface      = Color(0xFF07071C);
  static const surfaceLite  = Color(0xFF0D0D2A);
  static const border       = Color(0xFF1A1A3E);

  static const player       = Color(0xFF00D4FF);
  static const ghost        = Color(0xFFBB55FF);
  static const goal         = Color(0xFF00FFB0);
  static const wall         = Color(0xFFFF2255);

  static const accent1      = Color(0xFF00D4FF);
  static const accent2      = Color(0xFFCC44FF);
  static const accent3      = Color(0xFF00FFB0);
  static const gold         = Color(0xFFFFCC00);
  static const danger       = Color(0xFFFF2255);

  static const textPrimary  = Color(0xFFDDEEFF);
  static const textSub      = Color(0xFF4A5A7A);
  static const textDim      = Color(0xFF1E2A3E);

  static const tierColors = [
    Color(0xFF000000),
    Color(0xFF00D4FF), // tier 1
    Color(0xFF00FFB0), // tier 2
    Color(0xFFFFCC00), // tier 3
    Color(0xFFFF7733), // tier 4
    Color(0xFFFF2255), // tier 5
  ];
}

// ─── Data types ───────────────────────────────────────────────────────────────

class _Pos {
  final int row, col;
  const _Pos(this.row, this.col);
  _Pos move(int dr, int dc) => _Pos(row + dr, col + dc);
  @override bool operator ==(Object o) => o is _Pos && o.row == row && o.col == col;
  @override int get hashCode => Object.hash(row, col);
}

class _Step { final int dr, dc; const _Step(this.dr, this.dc); }

class _Level {
  final String name;
  final String tagline;
  final int par;
  final int tier;
  final Set<_Pos> walls;
  const _Level({
    required this.name, required this.tagline,
    required this.par, required this.tier,
    required this.walls,
  });
}

class _Particle {
  double x, y, vx, vy, life, size, rotation, spin;
  Color color;
  bool isSquare;
  _Particle({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.life, required this.size,
    required this.color,
    this.rotation = 0, this.spin = 0, this.isSquare = false,
  });
}

class _GhostTrail {
  final _Pos pos;
  double opacity;
  _GhostTrail(this.pos, this.opacity);
}

enum _Phase { idle, playing, cloning, dead, complete, paused }

// ─── Best scores ─────────────────────────────────────────────────────────────

final Map<int, int> _bestMoves = {};

// ═══════════════════════════════════════════════════════════════════════════════
//  Levels
//  RULE: Row 0 is ALWAYS completely clear (no walls).
//        Goal = (0,9)  →  top-right corner (row=0, col=9) — always free.
//        Start = (9,0) →  bottom-left corner — always free.
//        Walls live in rows 1-9 only, and never at (9,0).
// ═══════════════════════════════════════════════════════════════════════════════

List<_Level> _buildLevels() => [

  // ══════════════════════════════════════════════════════
  //  TIER 1 — NOVICE  (gentle intro, sparse walls)
  // ══════════════════════════════════════════════════════

  _Level(
    name: 'OPEN FIELD', tagline: 'Your reflection stirs.', par: 18, tier: 1,
    walls: {
      // Two horizontal barriers with gaps
      const _Pos(3,1), const _Pos(3,2), const _Pos(3,3), const _Pos(3,4), const _Pos(3,5),
      const _Pos(6,4), const _Pos(6,5), const _Pos(6,6), const _Pos(6,7), const _Pos(6,8),
      // Corner blockers
      const _Pos(2,8), const _Pos(4,1),
      const _Pos(8,3), const _Pos(8,7),
    },
  ),

  _Level(
    name: 'CROSSROADS', tagline: 'Which path does your shadow choose?', par: 20, tier: 1,
    walls: {
      // Plus-shaped barrier in the center
      const _Pos(4,4), const _Pos(4,5), const _Pos(5,4), const _Pos(5,5),
      // Arms
      const _Pos(3,4), const _Pos(3,5),
      const _Pos(6,4), const _Pos(6,5),
      const _Pos(4,3), const _Pos(5,3),
      const _Pos(4,6), const _Pos(5,6),
      // Outer obstacles
      const _Pos(2,1), const _Pos(2,8),
      const _Pos(7,2), const _Pos(7,7),
      const _Pos(9,4), const _Pos(9,5),
    },
  ),

  _Level(
    name: 'THE FORK', tagline: 'Two roads. One shadow.', par: 22, tier: 1,
    walls: {
      // Vertical divider rows 2-6 col 4 with gaps
      const _Pos(2,4), const _Pos(3,4),
      const _Pos(5,4), const _Pos(6,4), const _Pos(7,4),
      // Left channel
      const _Pos(2,2), const _Pos(3,2),
      const _Pos(5,1), const _Pos(6,1),
      // Right channel
      const _Pos(2,7), const _Pos(3,7),
      const _Pos(5,8), const _Pos(6,8),
      // Bottom
      const _Pos(8,3), const _Pos(8,5),
      const _Pos(9,2), const _Pos(9,7),
    },
  ),

  _Level(
    name: 'SPIRAL', tagline: 'Going in circles? So is your clone.', par: 26, tier: 1,
    walls: {
      // Outer ring with one gap on each side
      const _Pos(1,1), const _Pos(1,2), const _Pos(1,3), const _Pos(1,4),
      const _Pos(1,5), const _Pos(1,6), const _Pos(1,7), const _Pos(1,8),
      const _Pos(2,1), const _Pos(3,1), const _Pos(4,1), const _Pos(5,1),
      const _Pos(6,1), const _Pos(7,1),
      const _Pos(8,1), const _Pos(8,2), const _Pos(8,3), const _Pos(8,4),
      const _Pos(8,5), const _Pos(8,6), const _Pos(8,7),
      const _Pos(2,8), const _Pos(3,8), const _Pos(4,8), const _Pos(5,8),
      // Inner ring
      const _Pos(3,3), const _Pos(3,4), const _Pos(3,5), const _Pos(3,6),
      const _Pos(4,3), const _Pos(5,3), const _Pos(6,3),
      const _Pos(6,4), const _Pos(6,5), const _Pos(6,6),
      const _Pos(4,6), const _Pos(5,6),
    },
  ),

  // ══════════════════════════════════════════════════════
  //  TIER 2 — ADEPT  (denser, more deliberate pathing)
  // ══════════════════════════════════════════════════════

  _Level(
    name: 'CORRIDOR', tagline: 'The long way round is still a way out.', par: 20, tier: 2,
    walls: {
      // S-shaped corridor
      const _Pos(1,2), const _Pos(1,3), const _Pos(1,4), const _Pos(1,5), const _Pos(1,6),
      const _Pos(2,6), const _Pos(3,6), const _Pos(3,7), const _Pos(3,8),
      const _Pos(4,2), const _Pos(4,3), const _Pos(4,4), const _Pos(4,5),
      const _Pos(5,1), const _Pos(5,2),
      const _Pos(6,2), const _Pos(6,3), const _Pos(6,4), const _Pos(6,5), const _Pos(6,6),
      const _Pos(7,6), const _Pos(7,7),
      const _Pos(8,3), const _Pos(8,4), const _Pos(8,5), const _Pos(8,6),
      const _Pos(9,3), const _Pos(9,7),
    },
  ),

  _Level(
    name: 'CHAMBERS', tagline: 'Every room has a door. Find the right ones.', par: 26, tier: 2,
    walls: {
      // Left chamber
      const _Pos(1,1), const _Pos(2,1), const _Pos(3,1), const _Pos(3,2), const _Pos(3,3),
      const _Pos(2,3),
      // Right chamber
      const _Pos(1,7), const _Pos(2,7), const _Pos(3,7), const _Pos(3,6), const _Pos(3,5),
      const _Pos(2,5),
      // Center wall
      const _Pos(4,3), const _Pos(4,4), const _Pos(4,5), const _Pos(4,6),
      const _Pos(5,3), const _Pos(5,6),
      // Lower chambers
      const _Pos(6,1), const _Pos(6,2), const _Pos(7,2), const _Pos(8,2), const _Pos(8,1),
      const _Pos(6,7), const _Pos(6,8), const _Pos(7,8), const _Pos(8,8), const _Pos(8,7),
      const _Pos(9,4), const _Pos(9,5),
    },
  ),

  _Level(
    name: 'ZIGZAG', tagline: 'Never move in a straight line.', par: 28, tier: 2,
    walls: {
      // Staggered horizontal bars
      const _Pos(2,1), const _Pos(2,2), const _Pos(2,3), const _Pos(2,4), const _Pos(2,5), const _Pos(2,6),
      const _Pos(4,3), const _Pos(4,4), const _Pos(4,5), const _Pos(4,6), const _Pos(4,7), const _Pos(4,8),
      const _Pos(6,1), const _Pos(6,2), const _Pos(6,3), const _Pos(6,4), const _Pos(6,5), const _Pos(6,6),
      const _Pos(8,2), const _Pos(8,3), const _Pos(8,4), const _Pos(8,5), const _Pos(8,6), const _Pos(8,7),
      // Corner fillers
      const _Pos(3,8), const _Pos(5,1), const _Pos(7,8),
      const _Pos(9,1), const _Pos(9,8),
    },
  ),

  _Level(
    name: 'THE DIVIDE', tagline: 'Left brain, right brain. Choose wisely.', par: 26, tier: 2,
    walls: {
      // Vertical divide col 4-5
      const _Pos(1,4), const _Pos(1,5),
      const _Pos(2,4), const _Pos(2,5),
      const _Pos(3,4), const _Pos(3,5),
      const _Pos(5,4), const _Pos(5,5),
      const _Pos(6,4), const _Pos(6,5),
      const _Pos(7,4), const _Pos(7,5),
      // Left side obstacles
      const _Pos(3,1), const _Pos(3,2),
      const _Pos(5,2), const _Pos(6,2),
      const _Pos(8,1), const _Pos(8,2),
      // Right side obstacles
      const _Pos(3,7), const _Pos(3,8),
      const _Pos(5,7), const _Pos(6,7),
      const _Pos(8,7), const _Pos(8,8),
      const _Pos(9,3), const _Pos(9,6),
    },
  ),

  // ══════════════════════════════════════════════════════
  //  TIER 3 — SKILLED  (complex mazes, fewer gaps)
  // ══════════════════════════════════════════════════════

  _Level(
    name: 'LABYRINTH', tagline: 'Every step you take, your shadow takes too.', par: 32, tier: 3,
    walls: {
      // Winding corridors
      const _Pos(1,2), const _Pos(1,3), const _Pos(1,4), const _Pos(1,5), const _Pos(1,6), const _Pos(1,7),
      const _Pos(2,2), const _Pos(2,7),
      const _Pos(3,2), const _Pos(3,3), const _Pos(3,4), const _Pos(3,6), const _Pos(3,7),
      const _Pos(4,4), const _Pos(4,5), const _Pos(4,6),
      const _Pos(5,2), const _Pos(5,3), const _Pos(5,4),
      const _Pos(5,7), const _Pos(5,8),
      const _Pos(6,2), const _Pos(6,6), const _Pos(6,7),
      const _Pos(7,2), const _Pos(7,3), const _Pos(7,4), const _Pos(7,5), const _Pos(7,8),
      const _Pos(8,5), const _Pos(8,6), const _Pos(8,7), const _Pos(8,8),
      const _Pos(9,1), const _Pos(9,2), const _Pos(9,4), const _Pos(9,6),
    },
  ),

  _Level(
    name: 'THE WEB', tagline: 'Something is watching from the center.', par: 30, tier: 3,
    walls: {
      // Radial-ish pattern from center (5,5)
      const _Pos(2,1), const _Pos(2,3), const _Pos(2,6), const _Pos(2,8),
      const _Pos(3,2), const _Pos(3,5), const _Pos(3,7),
      const _Pos(4,1), const _Pos(4,3), const _Pos(4,4), const _Pos(4,6), const _Pos(4,8),
      const _Pos(5,2), const _Pos(5,5), const _Pos(5,7),
      const _Pos(6,1), const _Pos(6,3), const _Pos(6,4), const _Pos(6,6), const _Pos(6,8),
      const _Pos(7,2), const _Pos(7,5), const _Pos(7,7),
      const _Pos(8,1), const _Pos(8,3), const _Pos(8,6), const _Pos(8,8),
      const _Pos(9,2), const _Pos(9,4), const _Pos(9,6), const _Pos(9,8),
    },
  ),

  _Level(
    name: 'DEAD ENDS', tagline: 'Not every corridor leads somewhere.', par: 34, tier: 3,
    walls: {
      // Many dead-end pockets
      const _Pos(1,2), const _Pos(1,3), const _Pos(1,6), const _Pos(1,7),
      const _Pos(2,2), const _Pos(2,4), const _Pos(2,5), const _Pos(2,7),
      const _Pos(3,1), const _Pos(3,4), const _Pos(3,5), const _Pos(3,8),
      const _Pos(4,1), const _Pos(4,3), const _Pos(4,6), const _Pos(4,8),
      const _Pos(5,2), const _Pos(5,3), const _Pos(5,6), const _Pos(5,7),
      const _Pos(6,1), const _Pos(6,4), const _Pos(6,5), const _Pos(6,8),
      const _Pos(7,2), const _Pos(7,4), const _Pos(7,6), const _Pos(7,8),
      const _Pos(8,3), const _Pos(8,5), const _Pos(8,7),
      const _Pos(9,1), const _Pos(9,3), const _Pos(9,5), const _Pos(9,7),
    },
  ),

  _Level(
    name: 'THE CAGE', tagline: 'Freedom is just one wall away.', par: 36, tier: 3,
    walls: {
      // Outer frame rows 1-8
      const _Pos(1,1), const _Pos(1,2), const _Pos(1,3), const _Pos(1,4),
      const _Pos(1,5), const _Pos(1,6), const _Pos(1,7), const _Pos(1,8),
      const _Pos(2,1), const _Pos(2,8),
      const _Pos(3,1), const _Pos(3,8),
      const _Pos(4,1), const _Pos(4,8),
      const _Pos(5,1), const _Pos(5,8),
      const _Pos(6,1), const _Pos(6,8),
      const _Pos(7,1), const _Pos(7,8),
      const _Pos(8,1), const _Pos(8,2), const _Pos(8,3),
      const _Pos(8,5), const _Pos(8,6), const _Pos(8,7), const _Pos(8,8),
      // Inner maze
      const _Pos(3,3), const _Pos(3,4), const _Pos(3,5), const _Pos(3,6),
      const _Pos(4,3), const _Pos(5,3), const _Pos(5,5), const _Pos(5,6),
      const _Pos(6,3), const _Pos(6,5),
      const _Pos(7,3), const _Pos(7,4), const _Pos(7,5), const _Pos(7,6),
      const _Pos(9,2), const _Pos(9,4), const _Pos(9,6),
    },
  ),

  // ══════════════════════════════════════════════════════
  //  TIER 4 — EXPERT  (tight paths, many traps)
  // ══════════════════════════════════════════════════════

  _Level(
    name: 'FRACTURE', tagline: 'Your mind is cracking at the seams.', par: 38, tier: 4,
    walls: {
      const _Pos(1,1), const _Pos(1,2), const _Pos(1,4), const _Pos(1,5), const _Pos(1,7), const _Pos(1,8),
      const _Pos(2,1), const _Pos(2,4), const _Pos(2,7),
      const _Pos(3,1), const _Pos(3,2), const _Pos(3,4), const _Pos(3,5), const _Pos(3,7), const _Pos(3,8),
      const _Pos(4,2), const _Pos(4,5), const _Pos(4,8),
      const _Pos(5,1), const _Pos(5,2), const _Pos(5,4), const _Pos(5,5), const _Pos(5,7), const _Pos(5,8),
      const _Pos(6,1), const _Pos(6,4), const _Pos(6,7),
      const _Pos(7,1), const _Pos(7,2), const _Pos(7,4), const _Pos(7,5), const _Pos(7,7), const _Pos(7,8),
      const _Pos(8,2), const _Pos(8,5), const _Pos(8,8),
      const _Pos(9,1), const _Pos(9,3), const _Pos(9,5), const _Pos(9,7),
    },
  ),

  _Level(
    name: 'MIRROR MAZE', tagline: 'Which reflection is the real one?', par: 40, tier: 4,
    walls: {
      const _Pos(1,1), const _Pos(1,2), const _Pos(1,3), const _Pos(1,6), const _Pos(1,7), const _Pos(1,8),
      const _Pos(2,3), const _Pos(2,4), const _Pos(2,5), const _Pos(2,6),
      const _Pos(3,1), const _Pos(3,3), const _Pos(3,6), const _Pos(3,8),
      const _Pos(4,1), const _Pos(4,2), const _Pos(4,4), const _Pos(4,5), const _Pos(4,7), const _Pos(4,8),
      const _Pos(5,2), const _Pos(5,4), const _Pos(5,5), const _Pos(5,7),
      const _Pos(6,1), const _Pos(6,3), const _Pos(6,6), const _Pos(6,8),
      const _Pos(7,1), const _Pos(7,2), const _Pos(7,4), const _Pos(7,5), const _Pos(7,7), const _Pos(7,8),
      const _Pos(8,3), const _Pos(8,4), const _Pos(8,5), const _Pos(8,6),
      const _Pos(9,1), const _Pos(9,2), const _Pos(9,6), const _Pos(9,7), const _Pos(9,8),
    },
  ),

  _Level(
    name: 'VORTEX', tagline: 'The center pulls everything in.', par: 42, tier: 4,
    walls: {
      const _Pos(1,1), const _Pos(1,2), const _Pos(1,3), const _Pos(1,5), const _Pos(1,6), const _Pos(1,7), const _Pos(1,8),
      const _Pos(2,1), const _Pos(2,5), const _Pos(2,8),
      const _Pos(3,1), const _Pos(3,2), const _Pos(3,3), const _Pos(3,5), const _Pos(3,7), const _Pos(3,8),
      const _Pos(4,3), const _Pos(4,5), const _Pos(4,7),
      const _Pos(5,1), const _Pos(5,3), const _Pos(5,4), const _Pos(5,5), const _Pos(5,6), const _Pos(5,8),
      const _Pos(6,1), const _Pos(6,3), const _Pos(6,6), const _Pos(6,8),
      const _Pos(7,1), const _Pos(7,2), const _Pos(7,4), const _Pos(7,6), const _Pos(7,7), const _Pos(7,8),
      const _Pos(8,2), const _Pos(8,4), const _Pos(8,7),
      const _Pos(9,1), const _Pos(9,3), const _Pos(9,5), const _Pos(9,6), const _Pos(9,8),
    },
  ),

  _Level(
    name: 'THE ASYLUM', tagline: 'You built these walls yourself.', par: 44, tier: 4,
    walls: {
      const _Pos(1,1), const _Pos(1,3), const _Pos(1,4), const _Pos(1,5), const _Pos(1,7), const _Pos(1,8),
      const _Pos(2,1), const _Pos(2,3), const _Pos(2,5), const _Pos(2,7),
      const _Pos(3,1), const _Pos(3,2), const _Pos(3,5), const _Pos(3,7), const _Pos(3,8),
      const _Pos(4,2), const _Pos(4,3), const _Pos(4,5), const _Pos(4,6), const _Pos(4,8),
      const _Pos(5,1), const _Pos(5,3), const _Pos(5,5), const _Pos(5,8),
      const _Pos(6,1), const _Pos(6,3), const _Pos(6,4), const _Pos(6,5), const _Pos(6,7),
      const _Pos(7,1), const _Pos(7,3), const _Pos(7,7), const _Pos(7,8),
      const _Pos(8,1), const _Pos(8,2), const _Pos(8,4), const _Pos(8,5), const _Pos(8,7),
      const _Pos(9,2), const _Pos(9,4), const _Pos(9,6), const _Pos(9,8),
    },
  ),

  // ══════════════════════════════════════════════════════
  //  TIER 5 — MASTER  (brutal density, near-perfect play required)
  // ══════════════════════════════════════════════════════

  _Level(
    name: 'SHATTERED', tagline: 'The mirror has broken. So have you.', par: 46, tier: 5,
    walls: {
      const _Pos(1,1), const _Pos(1,2), const _Pos(1,4), const _Pos(1,6), const _Pos(1,7), const _Pos(1,8),
      const _Pos(2,2), const _Pos(2,4), const _Pos(2,5), const _Pos(2,7),
      const _Pos(3,1), const _Pos(3,3), const _Pos(3,5), const _Pos(3,7), const _Pos(3,8),
      const _Pos(4,1), const _Pos(4,3), const _Pos(4,4), const _Pos(4,6), const _Pos(4,8),
      const _Pos(5,2), const _Pos(5,4), const _Pos(5,6), const _Pos(5,8),
      const _Pos(6,1), const _Pos(6,2), const _Pos(6,4), const _Pos(6,6), const _Pos(6,7),
      const _Pos(7,1), const _Pos(7,3), const _Pos(7,5), const _Pos(7,7), const _Pos(7,8),
      const _Pos(8,2), const _Pos(8,3), const _Pos(8,5), const _Pos(8,7),
      const _Pos(9,1), const _Pos(9,3), const _Pos(9,4), const _Pos(9,6), const _Pos(9,8),
    },
  ),

  _Level(
    name: 'NEURON', tagline: 'Think faster. Your clone already has.', par: 48, tier: 5,
    walls: {
      const _Pos(1,1), const _Pos(1,2), const _Pos(1,4), const _Pos(1,5), const _Pos(1,7), const _Pos(1,8),
      const _Pos(2,2), const _Pos(2,4), const _Pos(2,6), const _Pos(2,8),
      const _Pos(3,1), const _Pos(3,3), const _Pos(3,4), const _Pos(3,6), const _Pos(3,8),
      const _Pos(4,1), const _Pos(4,3), const _Pos(4,5), const _Pos(4,6), const _Pos(4,8),
      const _Pos(5,2), const _Pos(5,3), const _Pos(5,5), const _Pos(5,7), const _Pos(5,8),
      const _Pos(6,1), const _Pos(6,3), const _Pos(6,5), const _Pos(6,6), const _Pos(6,8),
      const _Pos(7,1), const _Pos(7,2), const _Pos(7,4), const _Pos(7,6), const _Pos(7,7),
      const _Pos(8,2), const _Pos(8,4), const _Pos(8,5), const _Pos(8,7), const _Pos(8,8),
      const _Pos(9,1), const _Pos(9,3), const _Pos(9,5), const _Pos(9,6), const _Pos(9,8),
    },
  ),

  _Level(
    name: 'OBLIVION', tagline: 'There is no path. And yet you must walk.', par: 50, tier: 5,
    walls: {
      const _Pos(1,1), const _Pos(1,2), const _Pos(1,3), const _Pos(1,5), const _Pos(1,6), const _Pos(1,8),
      const _Pos(2,1), const _Pos(2,3), const _Pos(2,5), const _Pos(2,6), const _Pos(2,8),
      const _Pos(3,1), const _Pos(3,2), const _Pos(3,4), const _Pos(3,6), const _Pos(3,8),
      const _Pos(4,2), const _Pos(4,4), const _Pos(4,5), const _Pos(4,7), const _Pos(4,8),
      const _Pos(5,1), const _Pos(5,2), const _Pos(5,4), const _Pos(5,6), const _Pos(5,7),
      const _Pos(6,1), const _Pos(6,3), const _Pos(6,4), const _Pos(6,6), const _Pos(6,8),
      const _Pos(7,1), const _Pos(7,3), const _Pos(7,5), const _Pos(7,6), const _Pos(7,8),
      const _Pos(8,2), const _Pos(8,3), const _Pos(8,5), const _Pos(8,7), const _Pos(8,8),
      const _Pos(9,1), const _Pos(9,2), const _Pos(9,4), const _Pos(9,6), const _Pos(9,7),
    },
  ),

  _Level(
    name: 'FINAL MIRROR', tagline: 'Face yourself. One last time.', par: 54, tier: 5,
    walls: {
      const _Pos(1,1), const _Pos(1,2), const _Pos(1,3), const _Pos(1,4),
      const _Pos(1,6), const _Pos(1,7), const _Pos(1,8),
      const _Pos(2,1), const _Pos(2,4), const _Pos(2,6), const _Pos(2,8),
      const _Pos(3,1), const _Pos(3,2), const _Pos(3,4), const _Pos(3,6), const _Pos(3,7), const _Pos(3,8),
      const _Pos(4,2), const _Pos(4,4), const _Pos(4,5), const _Pos(4,8),
      const _Pos(5,1), const _Pos(5,2), const _Pos(5,3), const _Pos(5,5), const _Pos(5,7), const _Pos(5,8),
      const _Pos(6,1), const _Pos(6,3), const _Pos(6,5), const _Pos(6,7),
      const _Pos(7,1), const _Pos(7,2), const _Pos(7,4), const _Pos(7,5), const _Pos(7,7), const _Pos(7,8),
      const _Pos(8,2), const _Pos(8,4), const _Pos(8,6), const _Pos(8,8),
      const _Pos(9,1), const _Pos(9,3), const _Pos(9,4), const _Pos(9,6), const _Pos(9,7), const _Pos(9,8),
    },
  ),
];

// ─── Tier metadata ────────────────────────────────────────────────────────────

const _tierNames = ['', 'NOVICE', 'ADEPT', 'SKILLED', 'EXPERT', 'MASTER'];

// ─── FASTER clone speeds + SHORTER countdown ─────────────────────────────────
// Significantly faster than v5: ~30-40% speed increase

Duration _ghostTickForTier(int t) {
  switch (t.clamp(1, 5)) {
    case 1: return const Duration(milliseconds: 280);  // was 380  (faster start)
    case 2: return const Duration(milliseconds: 210);  // was 300
    case 3: return const Duration(milliseconds: 155);  // was 230
    case 4: return const Duration(milliseconds: 105);  // was 170
    case 5: return const Duration(milliseconds: 70);   // was 120  (nearly instant)
    default: return const Duration(milliseconds: 280);
  }
}

// Shorter countdowns: tier1 = 2s, tier2-3 = 1s, tier4-5 = 1s
int _countdownForTier(int t) => [0, 2, 1, 1, 1, 1][t.clamp(1, 5)];

// ═══════════════════════════════════════════════════════════════════════════════
//  GameScreen
// ═══════════════════════════════════════════════════════════════════════════════

class GameScreen extends StatefulWidget {
  final int startLevel;
  const GameScreen({super.key, this.startLevel = 0});
  @override State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {

  static const int _N = 10;
  static const _Pos _kStart = _Pos(9, 0);
  static const _Pos _kGoal  = _Pos(0, 9);
  static const _dMove      = Duration(milliseconds: 130);
  static const _dGhostMove = Duration(milliseconds: 160);

  late final List<_Level> _levels;
  int    _lvlIdx   = 0;
  _Phase _phase    = _Phase.idle;
  _Phase _prePause = _Phase.idle;

  late _Pos _pPos;
  int  _moves   = 0;
  bool _pMoving = false;

  final List<_Step> _tape = [];
  late _Pos _gPos;
  bool _gOn     = false;
  bool _gMoving = false;
  int  _gIdx    = 0;
  final List<_GhostTrail> _gTrail = [];

  int    _countdown    = 0;
  List<_Particle> _particles = [];
  Color  _flashColor   = _C.danger;
  double _flashOpacity = 0;
  bool   _goalReached  = false;

  Offset? _dragStart;
  int?    _dpadPressed;

  Timer? _ghostTicker;
  Timer? _particleTicker;
  Timer? _flashTicker;

  // Animation controllers
  late final AnimationController _acBg;
  late final AnimationController _acGoal;
  late final AnimationController _acWall;
  late final AnimationController _acGhost;
  late final AnimationController _acShake;
  late final AnimationController _acDeath;
  late final AnimationController _acWin;
  late final AnimationController _acFade;
  late final AnimationController _acCountdown;
  late final AnimationController _acHudPulse;

  _Level get _lvl => _levels[_lvlIdx];

  @override
  void initState() {
    super.initState();
    _levels = _buildLevels();
    _lvlIdx = widget.startLevel.clamp(0, _levels.length - 1);
    _pPos   = _kStart;
    _gPos   = _kStart;

    _acBg        = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat(reverse: true);
    _acGoal      = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _acWall      = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
    _acGhost     = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _acShake     = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _acDeath     = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _acWin       = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _acFade      = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
    _acCountdown = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _acHudPulse  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  }

  @override
  void dispose() {
    for (final ac in [_acBg, _acGoal, _acWall, _acGhost, _acShake,
      _acDeath, _acWin, _acFade, _acCountdown, _acHudPulse]) {
      ac.dispose();
    }
    _ghostTicker?.cancel();
    _particleTicker?.cancel();
    _flashTicker?.cancel();
    super.dispose();
  }

  // ─── Logic ───────────────────────────────────────────────────────────────

  bool _isWall(_Pos p)   => _lvl.walls.contains(p);
  bool _inBounds(_Pos p) => p.row >= 0 && p.row < _N && p.col >= 0 && p.col < _N;
  bool _canStep(_Pos p)  => _inBounds(p) && !_isWall(p);

  void _onDir(int dr, int dc) {
    if (_phase == _Phase.dead || _phase == _Phase.complete || _phase == _Phase.paused) return;
    final next = _pPos.move(dr, dc);
    if (!_canStep(next)) {
      HapticFeedback.lightImpact();
      _acShake.forward(from: 0);
      return;
    }
    _tape.add(_Step(dr, dc));
    setState(() {
      _pPos    = next;
      _moves   += 1;
      _pMoving = true;
      if (_phase == _Phase.idle) _phase = _Phase.playing;
    });
    Future.delayed(_dMove, () { if (mounted) setState(() => _pMoving = false); });
    if (_tape.length == 1) _beginCountdown();
    _checkCollision();
    if (_pPos == _kGoal) _winLevel();
  }

  void _beginCountdown() {
    final s = _countdownForTier(_lvl.tier);
    setState(() => _countdown = s);
    _acCountdown.forward(from: 0);
    void tick(int rem) {
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        if (rem > 1) {
          setState(() => _countdown = rem - 1);
          _acCountdown.forward(from: 0);
          tick(rem - 1);
        } else {
          setState(() {
            _countdown = 0;
            _gPos  = _kStart;
            _gOn   = true;
            _gIdx  = 0;
            _phase = _Phase.cloning;
          });
          _startGhostPlayback();
        }
      });
    }
    tick(s);
  }

  void _startGhostPlayback() {
    _ghostTicker?.cancel();
    _ghostTicker = Timer.periodic(_ghostTickForTier(_lvl.tier), (_) {
      if (!mounted) return;
      if (_phase == _Phase.paused) return;
      if (_tape.isEmpty) return;
      if (_gIdx >= _tape.length) {
        setState(() { _gPos = _kStart; _gIdx = 0; _gTrail.clear(); });
        return;
      }
      if (_gTrail.length >= 4) _gTrail.removeAt(0);
      _gTrail.add(_GhostTrail(_gPos, 0.5));
      final s    = _tape[_gIdx];
      final next = _gPos.move(s.dr, s.dc);
      setState(() {
        if (_inBounds(next)) _gPos = next;
        _gMoving = true;
        _gIdx++;
        for (int i = 0; i < _gTrail.length; i++) {
          _gTrail[i].opacity = (i + 1) / (_gTrail.length + 1) * 0.45;
        }
      });
      Future.delayed(_dGhostMove, () { if (mounted) setState(() => _gMoving = false); });
      _checkCollision();
    });
  }

  void _checkCollision() {
    if (_gOn && _pPos == _gPos) _dieLevel();
  }

  void _dieLevel() {
    _ghostTicker?.cancel();
    _particleTicker?.cancel();
    setState(() { _phase = _Phase.dead; _particles = []; });
    HapticFeedback.heavyImpact();
    _acDeath.forward(from: 0);
    _triggerFlash(_C.danger, 0.45);
    _acShake.forward(from: 0);
    final sw = MediaQuery.of(context).size.width;
    final ts = sw / _N;
    _spawnDeathParticles(_pPos.col * ts + ts / 2, _pPos.row * ts + ts / 2);
    Future.delayed(const Duration(milliseconds: 620), _showDeathDialog);
  }

  void _winLevel() {
    _ghostTicker?.cancel();
    setState(() { _phase = _Phase.complete; _goalReached = true; });
    HapticFeedback.mediumImpact();
    if (!_bestMoves.containsKey(_lvlIdx) || _moves < _bestMoves[_lvlIdx]!) {
      _bestMoves[_lvlIdx] = _moves;
    }
    _acWin.forward(from: 0);
    _triggerFlash(_C.goal, 0.22);
    final sw = MediaQuery.of(context).size.width;
    final ts = sw / _N;
    _spawnWinConfetti(sw / 2, ts * 3);
    Future.delayed(const Duration(milliseconds: 500), _showWinDialog);
  }

  void _triggerFlash(Color c, double maxOpacity) {
    _flashColor = c;
    _flashTicker?.cancel();
    double op = maxOpacity;
    _flashTicker = Timer.periodic(const Duration(milliseconds: 28), (t) {
      if (!mounted) { t.cancel(); return; }
      op -= 0.03;
      if (op <= 0) { op = 0; t.cancel(); }
      setState(() => _flashOpacity = op);
    });
  }

  void _spawnDeathParticles(double cx, double cy) {
    final rng = Random();
    _particles = List.generate(32, (i) {
      final angle = i / 32 * 2 * pi + rng.nextDouble() * 0.3;
      final speed = 4 + rng.nextDouble() * 8;
      return _Particle(
        x: cx, y: cy,
        vx: cos(angle) * speed, vy: sin(angle) * speed - 2,
        life: 1.0, size: 3 + rng.nextDouble() * 5,
        color: [_C.danger, _C.wall, Colors.white][rng.nextInt(3)],
        rotation: rng.nextDouble() * pi,
        spin: (rng.nextDouble() - 0.5) * 0.2,
        isSquare: rng.nextBool(),
      );
    });
    _runParticles();
  }

  void _spawnWinConfetti(double cx, double cy) {
    final rng = Random();
    _particles = List.generate(48, (i) {
      final angle = i / 48 * 2 * pi + rng.nextDouble() * 0.4;
      final speed = 3 + rng.nextDouble() * 10;
      return _Particle(
        x: cx + (rng.nextDouble() - 0.5) * 80, y: cy,
        vx: cos(angle) * speed, vy: sin(angle) * speed - 5,
        life: 1.0, size: 4 + rng.nextDouble() * 6,
        color: [_C.goal, _C.player, _C.gold, _C.ghost, Colors.white][rng.nextInt(5)],
        rotation: rng.nextDouble() * pi,
        spin: (rng.nextDouble() - 0.5) * 0.15,
        isSquare: rng.nextBool(),
      );
    });
    _runParticles();
  }

  void _runParticles() {
    _particleTicker?.cancel();
    _particleTicker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) { _particleTicker?.cancel(); return; }
      setState(() {
        for (final p in _particles) {
          p.x += p.vx; p.y += p.vy;
          p.vx *= 0.94; p.vy = p.vy * 0.94 + 0.35;
          p.rotation += p.spin;
          p.life -= 0.025;
        }
        _particles.removeWhere((p) => p.life <= 0);
      });
      if (_particles.isEmpty) _particleTicker?.cancel();
    });
  }

  void _resetLevel() {
    _ghostTicker?.cancel();
    _particleTicker?.cancel();
    _tape.clear(); _gTrail.clear();
    _acDeath.reset(); _acWin.reset();
    _flashOpacity = 0; _goalReached = false;
    setState(() {
      _pPos = _kStart; _gPos = _kStart;
      _gOn = false; _gMoving = false; _gIdx = 0;
      _moves = 0; _countdown = 0; _pMoving = false;
      _phase = _Phase.idle; _particles = [];
    });
    _acFade.forward(from: 0);
  }

  void _nextLevel() {
    _lvlIdx = (_lvlIdx < _levels.length - 1) ? _lvlIdx + 1 : 0;
    _resetLevel();
  }

  void _goToLevel(int idx) {
    _lvlIdx = idx.clamp(0, _levels.length - 1);
    _resetLevel();
  }

  void _pauseGame() {
    if (_phase == _Phase.dead || _phase == _Phase.complete) return;
    _prePause = _phase;
    _ghostTicker?.cancel();
    setState(() => _phase = _Phase.paused);
    _showPauseMenu();
  }

  void _resumeGame() {
    setState(() => _phase = _prePause);
    if (_gOn && _phase == _Phase.cloning) _startGhostPlayback();
  }

  void _onPanStart(DragStartDetails d) => _dragStart = d.globalPosition;
  void _onPanEnd(DragEndDetails d) {
    if (_dragStart == null) return;
    final v = d.velocity.pixelsPerSecond;
    if (v.distance < 200) return;
    if (v.dx.abs() > v.dy.abs()) {
      _onDir(0, v.dx > 0 ? 1 : -1);
    } else {
      _onDir(v.dy > 0 ? 1 : -1, 0);
    }
    _dragStart = null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final sw  = MediaQuery.of(context).size.width;
    final sh  = MediaQuery.of(context).size.height;
    final ts  = sw / _N;
    final gPx = ts * _N;

    final shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -7.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -7.0, end:  7.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin:  7.0, end: -4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.0, end:  4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin:  4.0, end:  0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _acShake, curve: Curves.linear));

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          _buildAnimatedBg(sw, sh),

          FadeTransition(
            opacity: CurvedAnimation(parent: _acFade, curve: Curves.easeOut),
            child: SafeArea(
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanEnd: _onPanEnd,
                child: Column(
                  children: [
                    _buildHUD(),
                    AnimatedBuilder(
                      animation: shakeAnim,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(shakeAnim.value, 0),
                        child: child,
                      ),
                      child: _buildGrid(ts, gPx),
                    ),
                    const Spacer(),
                    _buildLegend(),
                    const SizedBox(height: 10),
                    _buildControls(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          if (_flashOpacity > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(color: _flashColor.withOpacity(_flashOpacity)),
              ),
            ),

          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _OverlayPainter()))),
        ],
      ),
    );
  }

  // ─── Animated background ──────────────────────────────────────────────────

  Widget _buildAnimatedBg(double sw, double sh) {
    final tc = _C.tierColors[_lvl.tier];
    return AnimatedBuilder(
      animation: _acBg,
      builder: (_, __) {
        final t = _acBg.value;
        return Container(
          width: sw, height: sh,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.6 + t * 1.2, -0.4 + t * 0.8),
              radius: 1.4,
              colors: [tc.withOpacity(0.05), _C.bgDeep],
            ),
          ),
        );
      },
    );
  }

  // ─── HUD ──────────────────────────────────────────────────────────────────

  Widget _buildHUD() {
    final tc = _C.tierColors[_lvl.tier];
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _C.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border, width: 1),
        boxShadow: [BoxShadow(color: tc.withOpacity(0.08), blurRadius: 20, spreadRadius: 1)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Logo + Buttons
          Row(
            children: [
              AnimatedBuilder(
                animation: _acHudPulse,
                builder: (_, __) => ShaderMask(
                  shaderCallback: (b) => LinearGradient(
                    colors: [
                      Color.lerp(_C.accent1, _C.accent2, _acHudPulse.value)!,
                      Color.lerp(_C.accent2, _C.accent3, _acHudPulse.value)!,
                    ],
                  ).createShader(b),
                  child: const Text('TRACEMIND', style: TextStyle(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w900, letterSpacing: 3.5,
                  )),
                ),
              ),
              const Spacer(),
              _hudBtn(Icons.pause_rounded,   _C.accent1, _pauseGame),
              const SizedBox(width: 6),
              _hudBtn(Icons.refresh_rounded, _C.textSub, _resetLevel),
            ],
          ),
          const SizedBox(height: 7),

          // Row 2: Level info
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: tc, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: tc.withOpacity(0.8), blurRadius: 8)],
                ),
              ),
              const SizedBox(width: 5),
              Text('LVL ${_lvlIdx + 1}', style: TextStyle(
                color: tc.withOpacity(0.9), fontSize: 10,
                fontWeight: FontWeight.w900, letterSpacing: 2,
              )),
              const SizedBox(width: 5),
              Flexible(
                flex: 2,
                child: Text(_lvl.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.textSub, fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _statChip(_moves.toString(), _C.accent1, 'MV'),
              const SizedBox(width: 4),
              _statChip(_lvl.par.toString(), _C.textSub, 'PAR'),
              if (_bestMoves.containsKey(_lvlIdx)) ...[
                const SizedBox(width: 4),
                _statChip(_bestMoves[_lvlIdx].toString(), _C.gold, 'BEST'),
              ],
              const SizedBox(width: 6),
              _buildPhaseIndicator(),
            ],
          ),

          if (_countdown > 0) ...[
            const SizedBox(height: 8),
            _buildCountdownBar(),
          ],
        ],
      ),
    );
  }

  Widget _hudBtn(IconData icon, Color c, VoidCallback fn) {
    return GestureDetector(
      onTap: fn,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: c.withOpacity(0.08),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: c.withOpacity(0.22), width: 1),
        ),
        child: Icon(icon, color: c, size: 17),
      ),
    );
  }

  Widget _statChip(String val, Color c, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.06),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.withOpacity(0.18), width: 1),
      ),
      child: RichText(text: TextSpan(children: [
        TextSpan(text: '$label ', style: TextStyle(
          color: c.withOpacity(0.38), fontSize: 6.5, letterSpacing: 1, fontWeight: FontWeight.w700,
        )),
        TextSpan(text: val, style: TextStyle(
          color: c, fontSize: 12, fontWeight: FontWeight.w900,
        )),
      ])),
    );
  }

  Widget _buildPhaseIndicator() {
    switch (_phase) {
      case _Phase.idle:
        return _phaseText('START', _C.textDim);
      case _Phase.playing:
        return Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _acHudPulse,
            builder: (_, __) => Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: Color.lerp(_C.accent1, _C.accent1.withOpacity(0.2), _acHudPulse.value),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: _C.accent1.withOpacity(0.6 * (1 - _acHudPulse.value)),
                  blurRadius: 8,
                )],
              ),
            ),
          ),
          const SizedBox(width: 4),
          _phaseText('REC', _C.accent1),
        ]);
      case _Phase.cloning:
        return AnimatedBuilder(
          animation: _acGhost,
          builder: (_, __) => _phaseText('◉ CLONE',
              Color.lerp(_C.ghost, _C.accent2, _acGhost.value)!),
        );
      case _Phase.dead:     return _phaseText('✕ DEAD',   _C.danger);
      case _Phase.complete: return _phaseText('◈ WIN',    _C.goal);
      case _Phase.paused:   return _phaseText('⏸ PAUSE',  _C.gold);
    }
  }

  Widget _phaseText(String t, Color c) => Text(t,
    style: TextStyle(color: c, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.2),
  );

  Widget _buildCountdownBar() {
    return AnimatedBuilder(
      animation: _acCountdown,
      builder: (_, __) {
        final s = CurvedAnimation(parent: _acCountdown, curve: Curves.elasticOut).value;
        return Transform.scale(
          scale: 1.0 + s * 0.05,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _C.ghost.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.ghost.withOpacity(0.32), width: 1),
              boxShadow: [BoxShadow(color: _C.ghost.withOpacity(0.10), blurRadius: 10)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timelapse_rounded, color: _C.ghost.withOpacity(0.8), size: 12),
                const SizedBox(width: 6),
                Text('CLONE IN  $_countdown', style: const TextStyle(
                  color: _C.ghost, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2,
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Grid ─────────────────────────────────────────────────────────────────

  Widget _buildGrid(double ts, double gPx) {
    return Container(
      width: gPx, height: gPx,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: _C.bgDeep,
        border: Border.all(color: _C.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: _phase == _Phase.dead
                ? _C.danger.withOpacity(0.18)
                : _C.accent1.withOpacity(0.04),
            blurRadius: 20, spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(children: [
        CustomPaint(size: Size(gPx, gPx), painter: _GridPainter(ts: ts, n: _N)),
        ..._buildWalls(ts),
        _buildGoalTile(ts),
        ..._gTrail.map((trail) => _buildTrailTile(ts, trail)),
        if (_gOn) _buildGhostTile(ts),
        _buildPlayerTile(ts),
        ..._particles.map((p) => Positioned(
          left: p.x - p.size / 2, top: p.y - p.size / 2,
          child: Transform.rotate(
            angle: p.rotation,
            child: Opacity(
              opacity: p.life.clamp(0.0, 1.0),
              child: p.isSquare
                  ? Container(
                width: p.size, height: p.size,
                decoration: BoxDecoration(
                  color: p.color, borderRadius: BorderRadius.circular(1.5),
                ),
              )
                  : Container(
                width: p.size, height: p.size,
                decoration: BoxDecoration(color: p.color, shape: BoxShape.circle),
              ),
            ),
          ),
        )),
      ]),
    );
  }

  List<Widget> _buildWalls(double ts) {
    return _lvl.walls.map((p) => AnimatedBuilder(
      animation: _acWall,
      builder: (_, __) => Positioned(
        left: p.col * ts, top: p.row * ts,
        child: SizedBox(
          width: ts, height: ts,
          child: CustomPaint(painter: _WallPainter(flicker: _acWall.value)),
        ),
      ),
    )).toList();
  }

  Widget _buildGoalTile(double ts) {
    return AnimatedBuilder(
      animation: Listenable.merge([_acGoal, _acWin]),
      builder: (_, __) {
        final p   = _acGoal.value;
        final win = CurvedAnimation(parent: _acWin, curve: Curves.elasticOut).value;
        final pad = ts * 0.18;
        final d   = ts - pad * 2;
        final sc  = _goalReached ? (1.0 + win * 0.5) : 1.0;
        return Positioned(
          left: _kGoal.col * ts + pad,
          top:  _kGoal.row * ts + pad,
          child: Transform.scale(
            scale: sc,
            child: Container(
              width: d, height: d,
              decoration: BoxDecoration(
                color: _C.goal.withOpacity(0.90),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: _C.goal.withOpacity(0.50 + 0.30 * p),
                      blurRadius: 12 + 10 * p + win * 24, spreadRadius: 1 + 2 * p),
                  BoxShadow(color: _C.goal.withOpacity(0.18), blurRadius: 30),
                ],
              ),
              child: Center(child: Container(
                width: d * 0.38, height: d * 0.38,
                decoration: BoxDecoration(
                  color: _C.bgDeep, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: _C.goal.withOpacity(0.4), blurRadius: 8)],
                ),
              )),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrailTile(double ts, _GhostTrail trail) {
    final pad = ts * 0.25;
    final d   = ts - pad * 2;
    return Positioned(
      left: trail.pos.col * ts + pad,
      top:  trail.pos.row * ts + pad,
      child: Opacity(
        opacity: trail.opacity,
        child: Container(
          width: d, height: d,
          decoration: BoxDecoration(
            color: _C.ghost.withOpacity(0.07),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _C.ghost.withOpacity(0.18), width: 0.8),
          ),
        ),
      ),
    );
  }

  Widget _buildGhostTile(double ts) {
    final pad = ts * 0.09;
    final sz  = ts - pad * 2;
    return AnimatedBuilder(
      animation: _acGhost,
      builder: (_, __) {
        final g = _acGhost.value;
        return AnimatedPositioned(
          duration: _dGhostMove, curve: Curves.easeInOut,
          left: _gPos.col * ts + pad,
          top:  _gPos.row * ts + pad,
          child: AnimatedScale(
            scale: _gMoving ? 1.08 : 1.0, duration: _dGhostMove,
            child: Container(
              width: sz, height: sz,
              decoration: BoxDecoration(
                color: _C.ghost.withOpacity(0.12 + 0.10 * g),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _C.ghost.withOpacity(0.45 + 0.35 * g), width: 1.3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _C.ghost.withOpacity(0.40 + 0.28 * g),
                    blurRadius: 14 + 10 * g, spreadRadius: 1 + 2 * g,
                  ),
                  BoxShadow(
                    color: _C.ghost.withOpacity(0.08 + 0.08 * g),
                    blurRadius: 28, spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: CustomPaint(
                  size: Size(sz * 0.5, sz * 0.5),
                  painter: _GhostIconPainter(
                    color: _C.ghost.withOpacity(0.55 + 0.40 * g),
                    pulse: g,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerTile(double ts) {
    const pc  = _C.player;
    final pad = ts * 0.09;
    final sz  = ts - pad * 2;

    final shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -7.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -7.0, end:  7.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin:  7.0, end:  0.0), weight: 1),
    ]).animate(_acShake);

    return AnimatedBuilder(
      animation: shakeAnim,
      builder: (_, child) => AnimatedPositioned(
        duration: _dMove, curve: Curves.easeOutCubic,
        left: _pPos.col * ts + pad + shakeAnim.value,
        top:  _pPos.row * ts + pad,
        child: child!,
      ),
      child: AnimatedScale(
        scale: _pMoving ? 1.11 : 1.0, duration: _dMove,
        child: Container(
          width: sz, height: sz,
          decoration: BoxDecoration(
            color: _phase == _Phase.dead ? pc.withOpacity(0.25) : pc.withOpacity(0.95),
            borderRadius: BorderRadius.circular(10),
            boxShadow: _phase == _Phase.dead ? [] : [
              BoxShadow(color: pc.withOpacity(0.85), blurRadius: 16, spreadRadius: 2),
              BoxShadow(color: pc.withOpacity(0.40), blurRadius: 32, spreadRadius: 5),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: sz * 0.12, left: sz * 0.20, right: sz * 0.20,
                height: sz * 0.18,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.26),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Container(
                width: sz * 0.28, height: sz * 0.28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.90),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [BoxShadow(color: pc, blurRadius: 8)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Legend ───────────────────────────────────────────────────────────────

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _C.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _legendItem(_C.player, 'YOU'),
          _vDivider(),
          _legendItem(_C.ghost, 'CLONE'),
          _vDivider(),
          _legendItem(_C.goal, 'GOAL'),
          _vDivider(),
          _legendItem(_C.wall, 'WALL'),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 12, color: _C.textDim);

  Widget _legendItem(Color c, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [BoxShadow(color: c.withOpacity(0.6), blurRadius: 5)],
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(
        color: c.withOpacity(0.52), fontSize: 9,
        letterSpacing: 1.6, fontWeight: FontWeight.w700,
      )),
    ]);
  }

  // ─── D-pad ────────────────────────────────────────────────────────────────

  Widget _buildControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dpadBtn(0, Icons.keyboard_arrow_up_rounded, () => _onDir(-1, 0)),
        const SizedBox(height: 3),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _dpadBtn(1, Icons.keyboard_arrow_left_rounded,  () => _onDir(0, -1)),
          const SizedBox(width: 3),
          _dpadBtn(2, Icons.keyboard_arrow_down_rounded,  () => _onDir(1, 0)),
          const SizedBox(width: 3),
          _dpadBtn(3, Icons.keyboard_arrow_right_rounded, () => _onDir(0, 1)),
        ]),
      ],
    );
  }

  Widget _dpadBtn(int id, IconData icon, VoidCallback fn) {
    const c = _C.accent1;
    const sz = 60.0;
    final pressed = _dpadPressed == id;
    return GestureDetector(
      onTapDown:   (_) => setState(() => _dpadPressed = id),
      onTapUp:     (_) { setState(() => _dpadPressed = null); fn(); },
      onTapCancel: ()  => setState(() => _dpadPressed = null),
      child: AnimatedScale(
        scale: pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 75),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 75),
          width: sz, height: sz,
          decoration: BoxDecoration(
            color: pressed ? c.withOpacity(0.14) : _C.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: pressed ? c.withOpacity(0.52) : _C.border,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: c.withOpacity(pressed ? 0.18 : 0.05),
                blurRadius: pressed ? 8 : 16,
                offset: pressed ? Offset.zero : const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon,
            color: c.withOpacity(pressed ? 1.0 : 0.72),
            size: 33,
            shadows: [Shadow(color: c.withOpacity(0.5), blurRadius: pressed ? 12 : 4)],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Dialogs
  // ═══════════════════════════════════════════════════════════════════════════

  void _showPauseMenu() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.82),
      builder: (_) => _PauseDialog(
        levelIdx: _lvlIdx,
        totalLevels: _levels.length,
        onResume: () { Navigator.pop(context); _resumeGame(); },
        onRestart: () { Navigator.pop(context); _resetLevel(); },
        onStartFromLevel: (i) { Navigator.pop(context); _goToLevel(i); },
      ),
    );
  }

  void _showDeathDialog() {
    if (!mounted) return;
    _openDialog(
      icon: '👁',
      title: 'YOU MET YOURSELF',
      subtitle: _lvl.tagline,
      body: 'Your mirror clone caught you.\nYour past self is merciless.',
      accent: _C.danger,
      buttons: [
        _dlgBtn('TRY AGAIN', _C.danger, () { Navigator.pop(context); _resetLevel(); }),
      ],
    );
  }

  void _showWinDialog() {
    if (!mounted) return;
    final stars  = _moves <= _lvl.par ? 3 : (_moves <= _lvl.par + 5 ? 2 : 1);
    final isLast = _lvlIdx == _levels.length - 1;
    _openDialog(
      icon: '◈',
      title: 'TRACE COMPLETE',
      subtitle: _lvl.tagline,
      body: 'Moves: $_moves   ·   Par: ${_lvl.par}\n\n${'★' * stars}${'☆' * (3 - stars)}',
      accent: _C.goal,
      buttons: [
        _dlgBtn('RETRY', _C.textSub, () { Navigator.pop(context); _resetLevel(); }),
        const SizedBox(width: 8),
        _dlgBtn(isLast ? 'RESTART' : 'NEXT  ›', _C.goal, () { Navigator.pop(context); _nextLevel(); }),
      ],
    );
  }

  void _openDialog({
    required String icon,
    required String title,
    required String subtitle,
    required String body,
    required Color accent,
    required List<Widget> buttons,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.80),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withOpacity(0.42), width: 1.3),
            boxShadow: [
              BoxShadow(color: accent.withOpacity(0.12), blurRadius: 48, spreadRadius: 6),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: TextStyle(
                fontSize: 36,
                shadows: [Shadow(color: accent.withOpacity(0.6), blurRadius: 22)],
              )),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: TextStyle(
                color: accent, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 3.5,
                shadows: [Shadow(color: accent.withOpacity(0.4), blurRadius: 10)],
              )),
              const SizedBox(height: 4),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(
                color: _C.textSub, fontSize: 11, fontStyle: FontStyle.italic, height: 1.45,
              )),
              const SizedBox(height: 12),
              Container(height: 1, color: accent.withOpacity(0.14)),
              const SizedBox(height: 12),
              Text(body, textAlign: TextAlign.center, style: const TextStyle(
                color: Color(0xFF6677AA), fontSize: 13, height: 1.8, fontFamily: 'monospace',
              )),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: buttons),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dlgBtn(String label, Color c, VoidCallback fn) {
    return GestureDetector(
      onTap: fn,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: c.withOpacity(0.10),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: c.withOpacity(0.50), width: 1.1),
          boxShadow: [BoxShadow(color: c.withOpacity(0.10), blurRadius: 12)],
        ),
        child: Text(label, style: TextStyle(
          color: c, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2,
        )),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Pause Dialog
// ═══════════════════════════════════════════════════════════════════════════════

class _PauseDialog extends StatefulWidget {
  final int levelIdx;
  final int totalLevels;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final void Function(int) onStartFromLevel;

  const _PauseDialog({
    required this.levelIdx, required this.totalLevels,
    required this.onResume, required this.onRestart,
    required this.onStartFromLevel,
  });

  @override State<_PauseDialog> createState() => _PauseDialogState();
}

class _PauseDialogState extends State<_PauseDialog> {
  bool _showPicker = false;
  late int _pick;

  @override
  void initState() {
    super.initState();
    _pick = widget.levelIdx;
  }

  @override
  Widget build(BuildContext context) {
    const accent = _C.gold;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent.withOpacity(0.32), width: 1.3),
            boxShadow: [BoxShadow(color: accent.withOpacity(0.10), blurRadius: 52, spreadRadius: 4)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08), shape: BoxShape.circle,
                  border: Border.all(color: accent.withOpacity(0.28), width: 1.2),
                ),
                child: const Icon(Icons.pause_rounded, color: accent, size: 24),
              ),
              const SizedBox(height: 12),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFFFCC00), Color(0xFFFF9900)],
                ).createShader(b),
                child: const Text('PAUSED', style: TextStyle(
                  color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.w900, letterSpacing: 5,
                )),
              ),
              const SizedBox(height: 3),
              Text('TRACEMIND  ·  LEVEL ${widget.levelIdx + 1} / ${widget.totalLevels}',
                  style: const TextStyle(
                    color: _C.textSub, fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 22),

              _pauseBtn('▶   RESUME', accent, widget.onResume),
              const SizedBox(height: 9),
              _pauseBtn('↺   RESTART', const Color(0xFF3A8AFF), widget.onRestart),
              const SizedBox(height: 9),
              _pauseBtn('⊞   SELECT LEVEL', const Color(0xFFAA44FF),
                      () => setState(() => _showPicker = !_showPicker)),

              if (_showPicker) ...[
                const SizedBox(height: 14),
                _buildLevelPicker(),
                const SizedBox(height: 9),
                _pauseBtn('GO → LEVEL ${_pick + 1}', const Color(0xFFAA44FF),
                        () => widget.onStartFromLevel(_pick)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelPicker() {
    final levels = _buildLevels();
    return Container(
      height: 185,
      decoration: BoxDecoration(
        color: _C.bgDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 5),
          itemCount: widget.totalLevels,
          itemBuilder: (_, i) {
            final lvl = levels[i];
            final tc  = _C.tierColors[lvl.tier];
            final sel = i == _pick;
            final cur = i == widget.levelIdx;
            return GestureDetector(
              onTap: () => setState(() => _pick = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFFAA44FF).withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: sel ? const Color(0xFFAA44FF).withOpacity(0.42) : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: tc.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: tc.withOpacity(0.30), width: 1),
                    ),
                    child: Center(child: Text('${i + 1}', style: TextStyle(
                      color: tc, fontSize: 9, fontWeight: FontWeight.w900,
                    ))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lvl.name, style: TextStyle(
                        color: sel ? _C.textPrimary : _C.textSub,
                        fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1,
                      )),
                      Text(_tierNames[lvl.tier], style: TextStyle(
                        color: tc.withOpacity(0.45), fontSize: 8, letterSpacing: 1,
                      )),
                    ],
                  )),
                  if (cur)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: _C.gold.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _C.gold.withOpacity(0.28), width: 1),
                      ),
                      child: const Text('NOW', style: TextStyle(
                        color: _C.gold, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1,
                      )),
                    ),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _pauseBtn(String label, Color c, VoidCallback fn) {
    return GestureDetector(
      onTap: fn,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: c.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withOpacity(0.33), width: 1.1),
          boxShadow: [BoxShadow(color: c.withOpacity(0.07), blurRadius: 10)],
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(
          color: c, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2,
        )),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Custom Painters
// ═══════════════════════════════════════════════════════════════════════════════

class _GridPainter extends CustomPainter {
  final double ts;
  final int n;
  const _GridPainter({required this.ts, required this.n});

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()..color = const Color(0xFF0A0A22)..strokeWidth = 0.5;
    final acc = Paint()..color = const Color(0xFF141432)..strokeWidth = 0.7;
    for (int i = 0; i <= n; i++) {
      final p = (i % 5 == 0) ? acc : dim;
      canvas.drawLine(Offset(i * ts, 0), Offset(i * ts, size.height), p);
      canvas.drawLine(Offset(0, i * ts), Offset(size.width, i * ts), p);
    }
  }

  @override bool shouldRepaint(_GridPainter o) => o.ts != ts;
}

class _WallPainter extends CustomPainter {
  final double flicker;
  const _WallPainter({required this.flicker});

  @override
  void paint(Canvas canvas, Size size) {
    const base = _C.wall;
    final w = size.width, h = size.height;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..color = base.withOpacity(0.09 * flicker));

    canvas.drawRect(Rect.fromLTWH(0.4, 0.4, w - 0.8, h - 0.8),
        Paint()
          ..color = base.withOpacity(0.28 * flicker)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8);

    final cx = w / 2, cy = h / 2;
    final arm   = w * 0.18;
    final thick = w * 0.08;
    final crossPaint = Paint()
      ..color = base.withOpacity(0.38 * flicker)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: arm * 2, height: thick),
        const Radius.circular(1.5),
      ),
      crossPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: thick, height: arm * 2),
        const Radius.circular(1.5),
      ),
      crossPaint,
    );

    final dotPaint = Paint()..color = base.withOpacity(0.20 * flicker);
    const dotR = 1.5, off = 3.5;
    for (final dx in <double>[-off, w - off]) {
      for (final dy in <double>[-off, h - off]) {
        canvas.drawCircle(Offset(dx + off, dy + off), dotR, dotPaint);
      }
    }
  }

  @override bool shouldRepaint(_WallPainter o) => o.flicker != flicker;
}

class _GhostIconPainter extends CustomPainter {
  final Color color;
  final double pulse;
  const _GhostIconPainter({required this.color, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2, cy = h / 2;

    final path = Path();
    path.addOval(Rect.fromCenter(
      center: Offset(cx, cy - h * 0.06), width: w * 0.7, height: h * 0.7,
    ));
    canvas.drawPath(path, Paint()
      ..color = color.withOpacity(0.85)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + pulse * 3));

    final eyePaint = Paint()..color = Colors.white.withOpacity(0.6 + pulse * 0.3);
    canvas.drawCircle(Offset(cx - w * 0.12, cy - h * 0.08), w * 0.07, eyePaint);
    canvas.drawCircle(Offset(cx + w * 0.12, cy - h * 0.08), w * 0.07, eyePaint);
  }

  @override bool shouldRepaint(_GhostIconPainter o) => o.pulse != pulse;
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final lp = Paint()..color = Colors.black.withOpacity(0.035)..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), lp);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, Colors.black.withOpacity(0.28)],
          radius: 0.85,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  @override bool shouldRepaint(_) => false;
}