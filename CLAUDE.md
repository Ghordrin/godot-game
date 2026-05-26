# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A wave-based roguelike action game built in **Godot 4.6** (Forward Plus renderer, 1600x900). The player fights enemies across chapters composed of waves, earning powerups and gold for a between-wave shop. The main scene is `scenes/world.tscn`.

## Running the Game

Open `project.godot` in Godot 4.6 and press F5 (or run from the editor). There is no separate build step — Godot runs GDScript directly. There are no tests or linters configured.

**Debug inputs (in-game):**
- `H` — deal debug damage to player
- `]` (right bracket) — toggle debug stats panel

## Physics Collision Layers

| Layer | Name |
|-------|------|
| 1 | player |
| 2 | enemies |
| 3 | collision |
| 4 | projectiles |
| 5 | detection |

Always use these named layers in scene inspector, not raw numbers.

## Architecture

### Autoloads (Singletons)

Registered in `project.godot` and accessible globally:

- **PlayerInventory** (`Data/Player/PlayerInventory.gd`) — owns all collected powerups, equipment slots, elemental combo tracking, and wave-temporary drops. The single source of truth for player progression state.
- **EnemyManager** (`Data/Autoloads/EnemyManager.gd`) — enemy object pool; call `recycle_enemy()` to return enemies, `revive_from_pool()` to reuse them. Avoids spawn/despawn overhead.
- **DeathQueue** (`Data/Autoloads/DeathQueue.gd`) — deferred enemy death processing to prevent frame drops when many enemies die at once.
- **DamageMeter** / **DamageNumberSpawner** — damage accumulation tracking and floating number visuals.
- **EnemyRegistry** — tracks all live enemies by reference.
- **GoldDropManager** — handles gold drop logic on enemy death.
- **AnimationHelper** / **CombatDebugLogger** / **PerformanceDebugMonitor** / **DebugFPSCounter** — utilities and debug tooling.

### Scene Hierarchy

```
world.tscn          ← main game world; contains Player, WaveManager, spawn points
└── main.tscn       ← tilemap layers (background/floor)
Player.tscn         ← CharacterBody2D with StatsComponent, HealthComponent, ShieldComponent
Enemy.tscn          ← normal enemy template; Elite/Boss variants extend or replace this
ShopUI.tscn         ← between-wave shop, shown by WaveManager after each wave
```

### Core Systems

**Wave/Chapter Progression** (`scripts/wave_manager.gd`)  
Controls the outer game loop: spawn wave → wait for clear → show shop/drops → next wave. Chapters contain multiple segments. Elite enemies appear after wave 7; bosses spawn at chapter intervals. Scales enemy health, damage, and speed by virtual wave number.

**Damage Pipeline** (`Data/Damage/`)  
All combat damage flows through structured packets:
1. **DamageBuilder** constructs a `DamagePacket` for a projectile (damage type, element, source stats).
2. **DamageMitigation** resolves the target's defenses (ArmorComponent, ShieldComponent).
3. **DamageResolver** is a legacy-compatibility wrapper — prefer DamageBuilder for new code.
4. Elements: Fire, Ice, Lightning, Poison. Two-element combos produce bonus effects (Thermal, Plasma, Corrosive, Magnetic, Viral, Neurotoxin) tracked in PlayerInventory.

**Component System** (`components/`)  
Entities attach these as child nodes:
- `HealthComponent.gd` — takes damage, emits signals, triggers death.
- `StatsComponent.gd` — aggregates base stats + equipped powerup modifiers (flat and percent); single source of truth for runtime stats.
- `StatusEffectComponent.gd` — CC and debuffs.
- `ArmorComponent.gd` — flat damage reduction applied before health.
- `ShieldComponent.gd` — shield pool with regeneration.
- `AffixComponent.gd` — elite enemy special abilities.

**Powerup System** (`Data/Player/`, `scripts/PowerUpData.gd`)  
Powerups are `.tres` Resources (20+ defined in `Data/Player/Upgrades/`). Each defines rarity (Common/Rare/Epic/Legendary), category (Element/Projectile/Utility/Defensive), stat modifications, and max stacks. PlayerInventory aggregates equipped powerups; StatsComponent reads from it each time stats are queried. `PowerUpTable.tres` is the global lookup table.

**Projectile Types** (`Data/Player/Projectiles/`)  
Phase, Boulder, Nova, Homing — each is a scene with its own script. Unlocked/upgraded through powerups. Boulder has sub-upgrades (size, impact, meteor) configured via upgrade scaling framework added in recent commits.

**Enemy Types**  
- Normal: `Data/Enemies/Normal/` — pooled via EnemyManager.
- Elite: `Data/Enemies/Elite/` — DashHunter variant and base EliteEnemy with AffixComponent.
- Boss: `Data/Enemies/Bosses/` — BruteBoss, PhantomBoss, BossOrbital, RailWarden; each is a standalone scene.

### Key Patterns

- **Object pooling**: All normal enemies go through EnemyManager; never free them with `queue_free()` directly — call `recycle_enemy()` instead.
- **Deferred deaths**: Enemy death logic routes through DeathQueue to batch processing and avoid mid-physics-step frees.
- **Stats are computed, not stored**: StatsComponent recalculates on demand from PlayerInventory; don't cache stat values across frames.
- **Signals over direct calls** for cross-system communication (e.g., HealthComponent emits `died`; WaveManager listens to EnemyRegistry counts).
