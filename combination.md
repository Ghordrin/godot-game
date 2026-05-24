# Elemental Types, Combinations, and Projectiles
> This document outlines the design specification for the current upgrade system, covering base elemental types, elemental combinations, and projectile behaviors.

---

## Core Concept

The combat system utilizes a dual-layer upgrade framework to determine combat outcomes:

| Layer | Meaning | Example |
| :--- | :--- | :--- |
| **Element** | Dictates the damage and status identity. | Fire, Ice, Lightning, Poison |
| **Projectile Type** | Dictates how the shot behaves and moves. | Nova, Bouncing, Phase |

* **Elements** decide *what kind* of damage or status effect is applied.
* **Projectile Types** decide *how* that damage is delivered to targets.

### Combination Examples

* **`Fire` + `Bouncing Shot`**
  * *Result:* Fires a projectile that chains between multiple enemies, applying base Fire damage and the Burn status effect on hit.
* **`Thermal` + `Nova Shot`**
  * *Result:* Fires a projectile that detonates upon impact, applying scaled Thermal combo damage and status effects across an area of effect (AOE).

---

## Elemental Types

There are four base elements in the ecosystem:

| Element | Role | Main Status |
| :--- | :--- | :--- |
| **Fire** | Reliable Damage Over Time (DOT) | Burn |
| **Ice** | Crowd Control & Safety | Slow |
| **Lightning** | Fast Disruption & Multi-hit | Shock |
| **Poison** | Scaling Damage Over Time | Poison |

### Fire
* **Identity:** `Fire = reliable damage over time.` The simplest offensive baseline element, maintaining consistent pressure.
* **Status Effect (Burn):** * Deals flat damage over time at medium speed.
  * Does not ramp up or scale dynamically; highly predictable and effective against trash mobs.
* **Strengths:** Consistent DOT; excellent starter element; synergizes cleanly with Viral; builds into Thermal and Corrosive.
* **Weaknesses:** Lacks crowd control; lacks dynamic damage scaling; lacks the instantaneous burst potential of Plasma.

### Ice
* **Identity:** `Ice = control and safety.` Prioritizes survivability and battlefield manipulation over raw DPS.
* **Status Effect (Slow):** * Decreases enemy movement velocity.
  * Dynamically scales down enemy projectile speed *(see engine requirements below)*.
  * Enables seamless kiting against aggressive or fast-moving threats.
* **Projectile Slow Support:** Enemy scripts must reference standardized variable names for the projectile slow to take effect.
  * **Incorrect Implementation ❌**
	```gdscript
	projectile.speed = 180.0 # Hardcoded value bypasses Ice scaling
	```
  * **Correct Implementation  **
	```gdscript
	projectile.speed = projectile_speed # Supports StatsComponent scaling
	# Also supports: attack_projectile_speed, StatsComponent.projectile_speed
	```
* **Strengths:** Exceptional defensive utility; counters rapid/projectile-heavy enemies; builds into Thermal, Magnetic, and Viral.
* **Weaknesses:** Low direct base damage; requires pairing with high-damage projectile types or elements to secure kills.

### Lightning
* **Identity:** `Lightning = fast disruption.` A highly reactive element characterized by rapid multi-hits and micro-stuns.
* **Status Effect (Shock):**
  * Deals low, rapid damage intervals (ticks significantly faster than Burn or Poison).
  * Enforces a minimum tick damage floor to prevent `0` damage readouts.
  * Features a chance to briefly stun targets and chain to nearby threats based on cluster proximity.
* **Strengths:** High visual and gameplay feedback; handles dense groups exceptionally well; maximizes `Bouncing Shot`. Combines into Plasma, Magnetic, and Neurotoxin.
* **Weaknesses:** Negligible single-tick damage; prone to creating screen clutter; demands tight balance tuning to prevent frame rate or visual overhead.

### Poison
* **Identity:** `Poison = slow escalating damage.` Weakest at exposure entry, but achieves the highest total damage output over sustained periods.
* **Status Effect (Poison):**
  * Ticks at a slow interval, but ramps up in damage over time.
  * Reapplying the status extends its total duration **without** resetting the current damage ramp step.
* **Strengths:** Premier anti-boss and anti-elite toolkit; scales infinitely better over prolonged encounters; peerless synergy with Viral.
* **Weaknesses:** Slow ramp-up curve; completely inefficient against low-health enemies that die instantly; highly dependent on target uptime.

---

## Elemental Combinations

Pairing two base elements automatically translates them into a singular, advanced Elemental Combination.

### Combo Resolution Table

| Elements | Resulting Combination |
| :--- | :--- |
| **Fire + Ice** | Thermal |
| **Fire + Lightning** | Plasma |
| **Fire + Poison** | Corrosive |
| **Ice + Lightning** | Magnetic |
| **Ice + Poison** | Viral |
| **Lightning + Poison** | Neurotoxin |

### Evaluation Mechanics & Logic Rules
Combinations are evaluated sequentially based on the order of element acquisition or equipment slotting.

* **Three Elements Equipt (`Fire + Ice + Poison`):**
  1. `Fire` and `Ice` resolve first to create **Thermal**.
  2. `Poison` lacks a valid partner and remains operating as a standard, base element.
* **Fourth Element Added (`Fire + Ice + Poison + Lightning`):**
  1. `Fire` and `Ice` resolve into **Thermal**.
  2. `Poison` and `Lightning` resolve into **Neurotoxin**.

---

## Advanced Combination Profiles

### Thermal
* **Recipe:** `Fire + Ice`
* **Identity:** `Thermal = heat shock and burning ground.` Bridges offensive pressure with positional control.
* **Effects:** Deals Thermal damage ➔ triggers an immediate secondary Fire burst ➔ inflicts Burn ➔ drops a localized burning ground hazard patch. Erodes armor values over time if the target possesses an armor stat. (Visual: Orange profile)
* **Synergies:** Area denial, anti-armor phases, `Nova Shot`, and `Bouncing Shot`.
* **Weaknesses:** Damage potential drops drastically if enemies move out of the ground patch; armor erosion provides zero net utility against unarmored targets.

### Plasma
* **Recipe:** `Fire + Lightning`
* **Identity:** `Plasma = explosive energy damage.` The definitive high-risk, high-burst AOE combination.
* **Effects:** Deals Plasma damage ➔ emits an instantaneous AOE damage pulse ➔ spawns a temporary, fast-ticking Plasma hazard field. (Visual: Purple profile)
* **Synergies:** Bursting down packed enemy waves, `Nova Shot`, and `Bouncing Shot`.
* **Weaknesses:** Field duration is incredibly brief; low efficiency against isolated, highly mobile targets; high visual overlap with base Lightning.

### Corrosive
* **Recipe:** `Fire + Poison`
* **Identity:** `Corrosive = armor destruction and poison pressure.` The premium heavy-target melting toolkit.
* **Effects:** Deals Corrosive damage ➔ aggressively strips enemy armor stats ➔ applies consistent, scaling poison tracking pressure. (Visual: Acid Green profile)
* **Synergies:** Elite execution, Boss phases, and Poison scaling amplification builds.
* **Weaknesses:** Loses structural identity if targets lack armor mechanics; lacks satisfying visual pop compared to Thermal/Plasma.

### Magnetic
* **Recipe:** `Ice + Lightning`
* **Identity:** `Magnetic = shield disruption and control.` Specialized defensive disruption.
* **Effects:** Deals Magnetic damage with a massive scalar multiplier against shields. If the target has no shield present, defaults into a hard movement/projectile slow and control profile. (Visual: Blue Electric profile)
* **Synergies:** Anti-shield encounters, projectile-dense bullet-hell stages, and defensive/immortality builds.
* **Weaknesses:** Shield-shred features are wasted in levels lacking shielded archetypes; notably lower raw base DPS compared to Plasma.

### Viral
* **Recipe:** `Ice + Poison`
* **Identity:** `Viral = damage-over-time amplifier.` A passive force-multiplier for status-heavy playstyles.
* **Effects:** Applies a unique Viral debuff that amplifies **all** incoming DOT profiles (Burn, Shock, and Poison) while active. Excels at scaling up dynamic Poison ramps.
* **Synergies:** Synergizes perfectly with any multi-element DOT build, high-health bosses, and elite units.
* **Weaknesses:** Provides minimal independent damage; requires setup or external DOT applications to bring value; demands clear, readable UI popups so the player recognizes the amplified damage numbers.

### Neurotoxin
* **Recipe:** `Lightning + Poison`
* **Identity:** `Neurotoxin = spreading poison and disruption.` Crowd control via chain-reaction contamination.
* **Effects:** Emits automatic contagion pulses that spread Poison stats to nearby uninfected enemies, applying brief micro-stuns with each spread pulse. (Visual: Green Contagion profile)
* **Synergies:** Ultra-dense wave chapters, crowd control setups, and mass Poison stacking.
* **Weaknesses:** Severely loses effectiveness during solo/isolated boss encounters; requires high unit density to maintain value; prone to extreme screen clutter.

---

## Projectile Types

Projectile types modify vector and targeting behaviors. 

> ⚠️ **CRITICAL ARCHITECTURAL RULE:** Projectile behaviors **must** preserve the complete integrity of the damage packet. If a projectile carries complex elements like *Physical + Thermal*, all derived hits, splits, or sub-explosions must distribute scaled versions of *both Physical and Thermal*, rather than flattening down into a single generic damage type.

### Projectile Profiles

#### Phase Shot
* **Identity:** `Phase Shot = piercing projectile.` High reliability, linear penetration.
* **Behavior:** Linearly pierces through all valid enemy collision vectors in its path, applying the full damage packet to every single entity passed.
* **Pros:** Exceptionally consistent; trivializes linear choke points; outstanding vehicle for delivering DOT across whole groups.
* **Cons:** Visually understated; entirely dependent on line-of-sight enemy positioning.

#### Boulder Shot
* **Identity:** `Boulder Shot = heavy impact projectile.` High impact, slow momentum.
* **Behavior:** Alters the projectile transform size scale. Substantially increases raw hit damage at the cost of reduced projectile velocity.
* **Pros:** Extreme screen feel and hit-stop satisfaction; heavily rewards burst-oriented setups.
* **Cons:** Slow travel speed can make gameplay feel sluggish if untuned; demands high-quality asset design to sell the mass.

#### Bouncing Shot
* **Identity:** `Bouncing Shot = enemy-to-enemy chaining.` Dynamic target acquisition.
* **Design Note:** Replaces the legacy wall-ricochet system to better suit modern arenas that lack dense interior wall collisions.
* **Behavior:** Registers the primary target hit ➔ scans for nearby valid entities within a tracking radius ➔ loops a bounce vector to unhit enemies up to a hard cap, applying a scaled-down modifier to the total damage packet per bounce.
* **Pros:** Highly satisfying clearing tool; perfect scaling paired with Lightning or advanced status combos.
* **Cons:** Completely useless against isolated units; easily over-tunes Lightning mechanics without strict limits; requires clear tracking trails.

#### Nova Shot
* **Identity:** `Nova Shot = area explosion.` Area of effect impact delivery.
* **Behavior:** Detonates immediately upon initial contact with any valid physics layer, outputting a radial blast that inflicts a scaled copy of the entire underlying damage packet (e.g., *Scaled Physical + Scaled Viral*).
* **Pros:** Massive burst coverage; straightforward utility; scales phenomenally with Thermal and Plasma fields.
* **Cons:** Balance hazard (prone to becoming the definitive "best choice"); demands precise visual radius indicators to match logic hitboxes.

#### Homing Shot
* **Identity:** `Homing Shot = reliable targeting.` Quality-of-life and consistency modifier.
* **Behavior:** Continuously applies steering forces toward the nearest enemy center-mass vector inside its forward detection cone.
* **Pros:** Excellent onboarding mechanic for new players; stabilizes slow projectile archetypes (e.g., Boulder Shot); tracks fast, evasive enemies.
* **Cons:** Lacks clear spatial damage potential (no piercing or AOE); feels entirely unnoticeable or "invisible" to the user if steering parameters are tuned too subtly.
