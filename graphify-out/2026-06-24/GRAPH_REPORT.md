# Graph Report - .  (2026-06-24)

## Corpus Check
- 187 files · ~133,236 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 541 nodes · 673 edges · 55 communities (23 shown, 32 thin omitted)
- Extraction: 88% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 79 edges (avg confidence: 0.81)
- Token cost: 0 input · 965,441 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Project Conventions & Skills|Project Conventions & Skills]]
- [[_COMMUNITY_Shootable Entities & Melee|Shootable Entities & Melee]]
- [[_COMMUNITY_Player Controller & Feel|Player Controller & Feel]]
- [[_COMMUNITY_Cast System (Bullet Payloads)|Cast System (Bullet Payloads)]]
- [[_COMMUNITY_Blast Court & Arena Levels|Blast Court & Arena Levels]]
- [[_COMMUNITY_CastCombat Smoke Tests|Cast/Combat Smoke Tests]]
- [[_COMMUNITY_Enemy Archetypes & Variety|Enemy Archetypes & Variety]]
- [[_COMMUNITY_Weapon Ammo & Reload|Weapon Ammo & Reload]]
- [[_COMMUNITY_Weapon Controller & Ammo Tracking|Weapon Controller & Ammo Tracking]]
- [[_COMMUNITY_NPC Health & Hit Resolution|NPC Health & Hit Resolution]]
- [[_COMMUNITY_Level Build Scripts|Level Build Scripts]]
- [[_COMMUNITY_Level Design & Tech Debt|Level Design & Tech Debt]]
- [[_COMMUNITY_Enemy AI State Machine|Enemy AI State Machine]]
- [[_COMMUNITY_Cast Effects & Damage Types|Cast Effects & Damage Types]]
- [[_COMMUNITY_Gun Firing & VFX Signals|Gun Firing & VFX Signals]]
- [[_COMMUNITY_Arena Builder & Layout|Arena Builder & Layout]]
- [[_COMMUNITY_Art Direction & Palette|Art Direction & Palette]]
- [[_COMMUNITY_Crosshair Hit Feedback|Crosshair Hit Feedback]]
- [[_COMMUNITY_Quality & Verification Stack|Quality & Verification Stack]]
- [[_COMMUNITY_One-Shot VFX Router|One-Shot VFX Router]]
- [[_COMMUNITY_Procedural Asset Generators|Procedural Asset Generators]]
- [[_COMMUNITY_Arena Layout Resources|Arena Layout Resources]]
- [[_COMMUNITY_Decal VFX Pool|Decal VFX Pool]]
- [[_COMMUNITY_ADS Recoil & Spread|ADS Recoil & Spread]]
- [[_COMMUNITY_Enemy Hit Seam|Enemy Hit Seam]]
- [[_COMMUNITY_Enemy State Machine Core|Enemy State Machine Core]]
- [[_COMMUNITY_Navmesh Bakers|Navmesh Bakers]]
- [[_COMMUNITY_NavEnemy Diagnostics|Nav/Enemy Diagnostics]]
- [[_COMMUNITY_Archetype Smoke Tests|Archetype Smoke Tests]]
- [[_COMMUNITY_Hammer Melee Weapon|Hammer Melee Weapon]]
- [[_COMMUNITY_Arena HUD Flash|Arena HUD Flash]]
- [[_COMMUNITY_Arena HUD Health|Arena HUD Health]]
- [[_COMMUNITY_Controls HUD|Controls HUD]]
- [[_COMMUNITY_Blast Court Fall Zone|Blast Court Fall Zone]]
- [[_COMMUNITY_Firing Yard Reset|Firing Yard Reset]]
- [[_COMMUNITY_Ruined Warehouse Reset|Ruined Warehouse Reset]]
- [[_COMMUNITY_Despawn Audio One-Shot|Despawn Audio One-Shot]]
- [[_COMMUNITY_Mesh Flash Tween|Mesh Flash Tween]]
- [[_COMMUNITY_Node Builder Helper|Node Builder Helper]]
- [[_COMMUNITY_Player Locator Util|Player Locator Util]]
- [[_COMMUNITY_Pickup Item|Pickup Item]]
- [[_COMMUNITY_Player Knockback|Player Knockback]]
- [[_COMMUNITY_Player Death Signal|Player Death Signal]]
- [[_COMMUNITY_Projectile Magnet Steering|Projectile Magnet Steering]]
- [[_COMMUNITY_Projectile Tint|Projectile Tint]]
- [[_COMMUNITY_Repulsion Zone Field|Repulsion Zone Field]]
- [[_COMMUNITY_Shockwave Ring VFX|Shockwave Ring VFX]]
- [[_COMMUNITY_Screenshot Capture Tool|Screenshot Capture Tool]]
- [[_COMMUNITY_Audio Bus Generator|Audio Bus Generator]]
- [[_COMMUNITY_SFX Synthesiser Tool|SFX Synthesiser Tool]]
- [[_COMMUNITY_AoE Smoke Test|AoE Smoke Test]]
- [[_COMMUNITY_Freed-SFX Smoke Test|Freed-SFX Smoke Test]]
- [[_COMMUNITY_Arena Layout Audit|Arena Layout Audit]]
- [[_COMMUNITY_Scene Property Validator|Scene Property Validator]]
- [[_COMMUNITY_Damage Vignette Overlay|Damage Vignette Overlay]]

## God Nodes (most connected - your core abstractions)
1. `WaveManager` - 13 edges
2. `Enemy (CharacterBody3D base)` - 12 edges
3. `CastData (.tres bullet payload resource)` - 10 edges
4. `Smoke: Elemental Casts Contract` - 10 edges
5. `DiceOfFate project conventions` - 9 edges
6. `Firing Yard Enemy (patrolling AI)` - 9 edges
7. `GameContext (hit DTO for Effect.apply)` - 9 edges
8. `WaveManager (arena authority, wave/spawn/reset)` - 8 edges
9. `Blast Court Arena` - 8 edges
10. `Improvements Backlog (Track H candidates)` - 8 edges

## Surprising Connections (you probably didn't know these)
- `EnemyArchetype resource (stats)` --semantically_similar_to--> `CastData (.tres bullet payload resource)`  [INFERRED] [semantically similar]
  design/enemy_archetype.md → .claude/skills/cast-system/SKILL.md
- `code-reviewer rubric (7 categories)` --references--> `Enemy died/touched_player signals up to manager`  [INFERRED]
  .claude/agents/code-reviewer.md → design/arena_survival_loop.md
- `DamageEffect (duck-typed apply_damage)` --references--> `Enemy died/touched_player signals up to manager`  [INFERRED]
  .claude/skills/cast-system/SKILL.md → design/arena_survival_loop.md
- `ArenaBuilder` --conceptually_related_to--> `Level: Blast Court`  [INFERRED]
  entities/arena/arena_builder.gd → design/levels/blast_court.md
- `Verify: Arena Render (Blast Court)` --references--> `BlastCourt`  [INFERRED]
  tools/verify_arena_render.gd → levels/blast_court.gd

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Reparent-to-survivor before owner free (VFX + SFX share)** — godot_oneshot_vfx_reparent_pattern, godot_audio_despawn_sfx, godot_decal_vfx_pool [INFERRED 0.75]
- **Layered L0-L3 verification stack** — claude_md_validate_sh, code_reviewer_agent, godot_runtime_smoke_skill, godot_fps_game_feel_skill [EXTRACTED 0.75]
- **Arena survival loop (manager + HUD + reset)** — arena_survival_loop_wavemanager, arena_hud_arenahud, arena_hazards_reset_player, main_load_level [INFERRED 0.75]
- **Cast data-driven projectile payload chain** — cast_system_castdata, cast_system_effect, cast_system_targetresolver, cast_system_gamecontext, cast_system_projectile_apply_loop [EXTRACTED 0.95]
- **Elemental status-effect pipeline** — elemental_bullets_burneffect, elemental_bullets_sloweffect, elemental_bullets_shockeffect, elemental_bullets_statusreceiver [EXTRACTED 0.95]
- **Archetype trait-mixing behaviour composition** — enemy_archetype_enemyarchetype_resource, enemy_archetype_enemybehaviour, enemy_archetype_magnetbehaviour, enemy_archetype_shooterattack, enemy_archetype_flyingmovement [EXTRACTED 0.90]
- **Shootable entities sharing the duck-typed on_hit() despawn contract** — fps_targets_target_entity, firing_yard_npc_npc_entity, rescuable_civilian_npc_shoot_penalty, fps_weapon_projectile, melee_weapon_knife_component [EXTRACTED 0.85]
- **Four-layer quality stack (L0 static / L1 review / L2 smoke / L3 user-play)** — polish_quality_plan_quality_layers, polish_quality_plan_runtime_smoke, polish_quality_plan_code_reviewer_agent [EXTRACTED 0.85]
- **Run vitals system: HealthComponent / WaveManager lives / RunState cross-swap carry** — health_component_healthcomponent, level_progression_wave_manager, level_progression_runstate_autoload [INFERRED 0.75]
- **Weapon ammo economy build chain** — design_weapon_ammo_limit_weapon_ammo_limit, design_weapon_reload_weapon_reload, design_weapon_ammo_hud_weapon_ammo_hud, design_reserve_ammo_reserve_ammo_economy [EXTRACTED 0.95]
- **ArenaBuilder build pipeline** — arena_arena_builder_emit_pieces, arena_arena_builder_emit_perimeter, arena_arena_builder_emit_spawn_markers, arena_arena_builder_emit_fall_zones, arena_arena_builder_emit_nav_region [EXTRACTED 0.95]
- **L0-L3 quality stack layers** — design_review_checklist_review_checklist, design_review_checklist_quality_stack, design_review_checklist_code_reviewer_agent [EXTRACTED 0.85]
- **All concrete enemy FSM states implement EnemyState** — state_machine_attack_state, state_machine_chase_state, state_machine_patrol_state, state_machine_pursue_state, state_machine_state [EXTRACTED 1.00]
- **All enemy archetypes extend Enemy base** — enemy_enemy_flying, enemy_enemy_magnet, enemy_enemy_runner, enemy_enemy_shooter, enemy_enemy_tank [EXTRACTED 1.00]
- **Movement/attack-role behaviour components bound under Enemy.Abilities** — behaviours_flying_movement, behaviours_magnet_behaviour, behaviours_shooter_attack, enemy_enemy [INFERRED 0.85]
- **Player composition: components own combat/ammo/recoil** — player_player, components_weapon_controller_weaponcontroller, components_bullet_ammo_tracker_bulletammotracker [EXTRACTED 0.95]
- **HUD widgets wired to player/weapon seams** — arena_hud_arenahud, crosshair_crosshair, components_weapon_controller_weaponcontroller [EXTRACTED 0.85]
- **Fire-and-free VFX nodes that free themselves on finish** — rescue_halo_rescuehalo, shockwave_ring_shockwavering, burn_aura_vfx_burnauravfx [INFERRED 0.75]
- **Gun signals → VfxRouter → VfxOneShot spawn flow** — weapon_gun, vfx_vfx_router, vfx_vfx_one_shot [EXTRACTED 0.95]
- **WaveManager spawns/connects Enemy with EnemyArchetype** — levels_wave_manager, enemy_enemy, enemy_enemy_archetype [EXTRACTED 0.95]
- **Parallel headless level build scripts** — scripts_build_firing_yard, scripts_build_ruined_warehouse, scripts_build_rw_slice_e, scripts_build_rw_slice_e4, lib_grid_json_iter [INFERRED 0.85]
- **Procedural generators read ArtStyle palette** — tools_art_style, tools_gen_models_props, tools_gen_models_props_arena, tools_gen_textures_specs [EXTRACTED 0.95]
- **Headless L2 smoke tests (validate.sh suite)** — tools_smoke_aoe, tools_smoke_archetype_grunt, tools_smoke_archetype_mix, tools_smoke_attack_freed, tools_smoke_audit_layout [INFERRED 0.85]
- **Headless NavigationMesh bakers** — tools_bake_navmesh, tools_bake_navmesh_blast_court, tools_diag_blast_court_nav [INFERRED 0.75]
- **Cast System Smoke Suite** — tools_smoke_cast, tools_smoke_cast_slice2, tools_smoke_bullet_ammo, tools_smoke_elemental_casts [INFERRED 0.85]
- **Health/Shield/Status Smoke Suite** — tools_smoke_health_component, tools_smoke_player_health, tools_smoke_typed_shield, tools_smoke_status_effects [INFERRED 0.85]
- **Render Verify Suite** — tools_verify_render, tools_verify_render_action, tools_verify_arena_render [INFERRED 0.85]
- **Effect subclasses implementing Effect base** — cast_burn_effect_burneffect, cast_damage_effect_damageeffect, cast_knockback_effect_knockbackeffect, cast_shock_effect_shockeffect, cast_effect_effect [EXTRACTED 1.00]
- **TargetResolver subclasses implementing TargetResolver** — cast_hit_target_resolver_hittargetresolver, cast_radius_target_resolver_radiustargetresolver, cast_target_resolver_targetresolver [EXTRACTED 1.00]
- **CastData payload: Effects + TargetResolver + GameContext** — cast_cast_data_castdata, cast_effect_effect, cast_target_resolver_targetresolver, cast_game_context_gamecontext [EXTRACTED 1.00]

## Communities (55 total, 32 thin omitted)

### Community 0 - "Project Conventions & Skills"
Cohesion: 0.06
Nodes (52): Moving crusher hazard (slice 2), Arena Hazards design, FallZone reset-on-touch pattern, HazardFloor Area3D (slice 1), _reset_player(body) shared reset helper, ArenaHud (Control HUD, persistent shell), Arena HUD design (kills + active count), Arena Survival Loop design (+44 more)

### Community 1 - "Shootable Entities & Melee"
Cohesion: 0.06
Nodes (39): Firing Yard NPC (standing shootable characters), Greybox-first build (two ordered slices), Npc (StaticBody3D shootable NPC), on_hit() despawn contract, FPS Targets (B2), One-hit despawn (no Health/multi-hit), Target (static shootable block, despawn on hit), DamageEffect.apply (duck-typed apply_damage seam) (+31 more)

### Community 2 - "Player Controller & Feel"
Cohesion: 0.06
Nodes (38): Camera takeover (player cam make_current over ortho rig), First-person eye Camera3D (Head/Camera split), FPS Player — Perspective Eye-Camera + Controller (A1+A2), Orthographic CameraRig (legacy, inert), Player CharacterBody3D controller, FPS Render-Rig Cleanup, Outline post-process shader (post_process.gdshader), PostProcessQuad (outline shader fullscreen quad) (+30 more)

### Community 3 - "Cast System (Bullet Payloads)"
Cohesion: 0.09
Nodes (34): Duck-typed apply_damage hazard seam, Hazard trap strips (damage-only), EnemyArchetype.resistances dictionary, Solid-colour element-immune enemy variant, immune_fire.tres archetype, bullet_color on CastData, Bullet Types (Cast composition proof), Carbine weapon (slot 2) (+26 more)

### Community 4 - "Blast Court & Arena Levels"
Cohesion: 0.08
Nodes (33): Blast Court Arena, Hand-authored greybox .tscn construction, Grid to world cell-center mapping, Level registration in main.gd _levels, blast_court_navmesh.tres navigation, Risk/reward pickup cluster, WaveManager enemy spawning, Programmatic falling floor tiles (+25 more)

### Community 5 - "Cast/Combat Smoke Tests"
Cohesion: 0.09
Nodes (33): Enemy, EnemyShooter, Projectile, Gun / Weapon, Melee Weapon, BulletAmmoTracker, BurnEffect, CastData (+25 more)

### Community 6 - "Enemy Archetypes & Variety"
Cohesion: 0.09
Nodes (29): Behaviour seam contract (bind/do_attack/drive_move), Enemy Archetype (data-driven, trait-mixing), EnemyArchetype resource (stats), EnemyBehaviour component node, FlyingMovement behaviour, Generic enemy.tscn reading archetype, MagnetBehaviour, ShooterAttack behaviour (+21 more)

### Community 7 - "Weapon Ammo & Reload"
Cohesion: 0.09
Nodes (27): CastData resource, ammo_changed(current, reserve) signal, Per-Weapon Reserve Pool, Reserve-Ammo Economy, BulletAmmoTracker component, bullet_casts registry on rifle, rapid_cast.tres (5th bullet), Single-rifle consolidation (+19 more)

### Community 8 - "Weapon Controller & Ammo Tracking"
Cohesion: 0.08
Nodes (26): ArenaHud.set_active_bullet, ArenaHud.set_bullet_ammo, ArenaHud.set_stamina, BulletAmmoTracker.ammo_changed (signal), BulletAmmoTracker, BulletAmmoTracker._process, WeaponController.collect_pickup, Gun (+18 more)

### Community 9 - "NPC Health & Hit Resolution"
Cohesion: 0.09
Nodes (24): BurnAuraVfx, HealthComponent, Npc, Npc.apply_damage, Npc._damage_player, Npc.died (signal), Npc._heal_player, Npc.on_hit (+16 more)

### Community 10 - "Level Build Scripts"
Cohesion: 0.13
Nodes (23): ArenaBuilder, HealthComponent, EnemyArchetype, BlastCourt, FiringYard, RuinedWarehouse, WaveManager, GridJsonIter (+15 more)

### Community 11 - "Level Design & Tech Debt"
Cohesion: 0.10
Nodes (22): code-reviewer agent (L1 deep), Cross-file signal arity match, L0-L3 Quality Stack, Review Checklist (L1 baseline gate), GridMap+hybrid construction method, Ruined Warehouse Build Design, WaveManager SPAWN_POS const constraint, Hybrid far-marker + close-ring spawn (+14 more)

### Community 12 - "Enemy AI State Machine"
Cohesion: 0.16
Nodes (21): FlyingMovement (hover/dive behaviour), MagnetBehaviour (pull-field behaviour), ShooterAttack (telegraph+fire behaviour), Enemy (CharacterBody3D base), EnemyFlying (Stinger dive-bomber), EnemyMagnet (pull-field enemy), Enemy.move_along_path, Enemy.perform_attack (+13 more)

### Community 13 - "Cast Effects & Damage Types"
Cohesion: 0.19
Nodes (19): BurnEffect (DoT via StatusReceiver), CastData (authored Effect[] + resolver), DamageEffect (typed damage amount), Effect (base cast effect Resource), GameContext (hit DTO for Effect.apply), HitTargetResolver (direct hit target), KnockbackEffect (push from instigator), RadiusTargetResolver (AoE sphere resolver) (+11 more)

### Community 14 - "Gun Firing & VFX Signals"
Cohesion: 0.13
Nodes (18): VfxRouter, BulletAmmoTracker, CastData, Gun, Gun._fire, Gun.fired signal, Gun._on_projectile_hit, Gun.try_fire (+10 more)

### Community 15 - "Arena Builder & Layout"
Cohesion: 0.16
Nodes (17): ArenaBuilder, ArenaBuilder._build, ArenaBuilder._emit_fall_zones, ArenaBuilder._emit_nav_region, ArenaBuilder._emit_perimeter, ArenaBuilder._emit_pieces, ArenaBuilder._emit_spawn_markers, ArenaBuilder._make_box_body (+9 more)

### Community 16 - "Art Direction & Palette"
Cohesion: 0.46
Nodes (8): Enemy crimson ramp + humanoid kitbash, Art Direction Enemy, Art Direction Firing Yard, Firing yard steel/concrete/rust palette, ArtStyle const module (single palette source of truth), tools/gen_models.gd (procedural model generator), tools/gen_textures.gd (procedural texture generator), godot-art-style skill

### Community 17 - "Crosshair Hit Feedback"
Cohesion: 0.25
Nodes (8): WeaponController._connect_gun_signals, WeaponController.fired (signal), WeaponController._on_gun_fired, WeaponController._on_hit_confirmed, WeaponController._on_kill_confirmed, Crosshair.fire_pop, Crosshair.hit_pop, Crosshair.kill_pop

### Community 18 - "Quality & Verification Stack"
Cohesion: 0.25
Nodes (8): code-reviewer agent (L1 isolated deep review), GdUnit4 SceneRunner — reject for POC, Headless has no RenderingDevice (logic vs render split), Polish & Quality Plan, Four quality layers (L0 static, L1 review, L2 smoke, L3 user-play), L2 runtime-smoke harness (without GdUnit4), shader_cache + pipeline_cache config (no ubershader toggle), VFX warm-up prewarm (_warmup_vfx shader-variant compile)

### Community 19 - "One-Shot VFX Router"
Cohesion: 0.25
Nodes (8): VfxOneShot, VfxRouter._on_blast, VfxRouter._on_element_impact, VfxRouter._on_fired, VfxRouter._on_hit_burst, VfxRouter._on_impact, VfxRouter._on_kill, VfxRouter._spawn_vfx

### Community 20 - "Procedural Asset Generators"
Cohesion: 0.40
Nodes (6): ArtStyle (palette + style language), gen_models (procedural .glb generator), GenModelsProps (furniture/bathroom prop specs), GenModelsPropsArena (enemy/weapon/pickup specs), gen_textures (procedural pixel-art texture generator), GenTexturesSpecs (texture spec data)

### Community 21 - "Arena Layout Resources"
Cohesion: 0.67
Nodes (3): ArenaPiece (cover element resource), LandmarkDef (named region resource), LaneDef (flow corridor resource)

### Community 22 - "Decal VFX Pool"
Cohesion: 0.67
Nodes (3): DecalPoolRouter._on_impact, DecalPoolRouter._on_kill, ScorchDecalPool.place

## Ambiguous Edges - Review These
- `EnemyStateMachine` → `Npc`  [AMBIGUOUS]
  entities/enemy/state_machine/state_machine.gd · relation: references

## Knowledge Gaps
- **162 isolated node(s):** `Input actions map`, `Art-kind to technique mapping`, `tools/smoke_cast.gd (cast data-path smoke)`, `Degenerate-safe normal to basis orientation`, `Clustered 512-element decal cost model` (+157 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **32 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `EnemyStateMachine` and `Npc`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **Why does `DamageEffect (duck-typed apply_damage)` connect `Cast System (Bullet Payloads)` to `Project Conventions & Skills`?**
  _High betweenness centrality (0.037) - this node is a cross-community bridge._
- **Why does `Enemy died/touched_player signals up to manager` connect `Project Conventions & Skills` to `Cast System (Bullet Payloads)`?**
  _High betweenness centrality (0.035) - this node is a cross-community bridge._
- **What connects `Input actions map`, `Art-kind to technique mapping`, `tools/smoke_cast.gd (cast data-path smoke)` to the rest of the system?**
  _190 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Project Conventions & Skills` be split into smaller, more focused modules?**
  _Cohesion score 0.05660377358490566 - nodes in this community are weakly interconnected._
- **Should `Shootable Entities & Melee` be split into smaller, more focused modules?**
  _Cohesion score 0.0620782726045884 - nodes in this community are weakly interconnected._
- **Should `Player Controller & Feel` be split into smaller, more focused modules?**
  _Cohesion score 0.06258890469416785 - nodes in this community are weakly interconnected._