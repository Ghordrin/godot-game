# Elemental Combination System

Design reference for the element / combo damage pipeline.

---

## Elements

| Powerup | Element | `amount` | Identity |
|---|---|---|---|
| Ignition Core | Fire | 0.50/rank | Burn DoT, execute (Thermal) |
| Cryo Lens | Ice | 0.50/rank | Slow, crystallize, shatter |
| Arc Conductor | Lightning | 0.50/rank | Shock DoT, chain, stun |
| Venom Injector | Poison | 0.50/rank | Ramping poison, contagion |

Combo legendaries (e.g. Thermal Catalyst) grant **both** elements at **0.40/rank** — convenient but slightly less raw power than investing in both separately.

---

## Combo Table

| Elements | Combo | Effect |
|---|---|---|
| Fire + Ice | **Thermal** | Instant execute burst scaled by missing HP. 40% AoE splash within 80px. |
| Fire + Lightning | **Plasma** | Target becomes conductor for 3.5s, arcing to 2 nearby enemies every 0.6s. |
| Fire + Poison | **Corrosive** | Ramping poison + viral amplifier (spreads DoT bonus to all active ticks). |
| Ice + Lightning | **Magnetic** | Shock DoT + 25% slow for 2s. |
| Ice + Poison | **Viral** | Viral amplifier (75% bonus to all active DoTs on target). |
| Lightning + Poison | **Neurotoxin** | Permanent ramping DoT + escalating slow. Stacks on reapply. |

---

## Damage Formula

```
element_damage = base_damage × amount × rank × starter_mult × wave_element_mult

wave_element_mult = 1.0 + (current_wave - 1) × ELEMENT_WAVE_SCALE   # 0.03/wave
					→ ×1.0 at wave 1, ×1.90 at wave 31, ×2.50 at wave 51

combo_damage = (pool_A + pool_B) × COMBO_BONUS_MULT   # 1.5×
```

The `starter_mult` only applies when the player has **exactly one** element equipped (solo-element identity bonus). It drops to 1.0 once any second element is active.

`base_damage` is the fully-modified projectile damage value (includes StatsComponent powerup bonuses like Scrap Rounds and Impact Coil). Investing in raw damage directly amplifies all elemental output.

---

## Starter Multipliers (solo element only)

| Element | Mult |
|---|---|
| Fire | ×1.25 |
| Ice | ×0.90 |
| Lightning | ×0.70 |
| Poison | ×1.00 |

These are intentionally asymmetric — solo fire is the strongest aggression pick; solo lightning is weakest alone but powerful in combos.

---

## Constants (DamageBuilder.gd)

| Constant | Value | Effect |
|---|---|---|
| `ELEMENT_WAVE_SCALE` | 0.03 | +3% element damage per virtual wave |
| `COMBO_BONUS_MULT` | 1.50 | 50% bonus when two elements combine into a combo |

---

## TODO

- [ ] Wave-based passive player damage floor: `+2% damage per virtual wave` applied in StatsComponent, so players without heavy Scrap Rounds investment don't fall behind on raw physical hits.
- [ ] Make the multi-element pairing exhaustive: with 4 elements active, pair all valid combos (not just the first pair). Currently fire+ice+lightning only finds Thermal; Plasma and Magnetic are unused.
- [ ] UI indicator: show active combo names and their damage pool on the HUD or upgrade screen.
- [ ] Consider combo-specific `max_stacks` tuning — Neurotoxin and Viral are permanent effects, lower max stacks may feel better than 5.
