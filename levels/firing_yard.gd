# levels/firing_yard.gd — day/night sun cycle driver and respawn handler for the Firing Yard.
class_name FiringYard
extends Node3D

# Fraction of the period that is daylight (sunrise → sunset arc): ~5/7 ≈ 0.714.
const DAYLIGHT_FRACTION: float = 5.0 / 7.0

# --- Sun pitch (X rotation) keyframes (degrees) ---
# Sunrise: low, angled in from the east (negative pitch = tilted down from zenith)
const SUN_PITCH_SUNRISE: float = -10.0
# Midday: high overhead
const SUN_PITCH_MIDDAY: float = -80.0
# Sunset: low again (symmetric with sunrise)
const SUN_PITCH_SUNSET: float = -10.0
# Night: moonlight — gentle angle from above, cool blue direct light.
const SUN_PITCH_NIGHT: float = -50.0

# Sun yaw stays fixed pointing from north.
const SUN_YAW: float = 180.0

# --- Sun light_energy keyframes ---
const SUN_ENERGY_SUNRISE: float = 0.6
const SUN_ENERGY_MIDDAY: float = 2.0
const SUN_ENERGY_SUNSET: float = 0.6
# At night the "sun" becomes a dim moonlight — cool blue, low energy, still casts shadows.
const SUN_ENERGY_NIGHT: float = 0.35

# --- Sun light_color keyframes ---
const SUN_COLOR_SUNRISE: Color = Color(1.0, 0.6, 0.2, 1.0)  # warm orange
const SUN_COLOR_MIDDAY: Color = Color(1.0, 0.97, 0.88, 1.0)  # near-white warm
const SUN_COLOR_SUNSET: Color = Color(1.0, 0.55, 0.15, 1.0)  # deeper orange
const SUN_COLOR_NIGHT: Color = Color(0.3, 0.4, 0.8, 1.0)  # cool blue moonlight

# --- Ambient light_color keyframes ---
const AMBIENT_COLOR_SUNRISE: Color = Color(0.4, 0.25, 0.15, 1.0)  # dim warm
const AMBIENT_COLOR_MIDDAY: Color = Color(0.35, 0.38, 0.45, 1.0)  # neutral sky fill
const AMBIENT_COLOR_SUNSET: Color = Color(0.35, 0.2, 0.12, 1.0)  # warm reddish
const AMBIENT_COLOR_NIGHT: Color = Color(0.25, 0.3, 0.55, 1.0)  # cool blue moonlight

# --- Ambient energy keyframes ---
const AMBIENT_ENERGY_SUNRISE: float = 0.5
const AMBIENT_ENERGY_MIDDAY: float = 0.8
const AMBIENT_ENERGY_SUNSET: float = 0.5
# Moonlight floor — lifted to 1.2 so the darker CONCRETE_DARKEST floor (value 0.16) stays
# readable at night; was 1.0 before the concrete_floor texture pass.
const AMBIENT_ENERGY_NIGHT: float = 1.2

# --- Sky top color keyframes ---
const SKY_TOP_SUNRISE: Color = Color(0.5, 0.35, 0.2, 1.0)  # orange dawn
const SKY_TOP_MIDDAY: Color = Color(0.25, 0.45, 0.75, 1.0)  # blue day sky
const SKY_TOP_SUNSET: Color = Color(0.55, 0.28, 0.1, 1.0)  # deep orange dusk
const SKY_TOP_NIGHT: Color = Color(0.02, 0.03, 0.08, 1.0)  # near-black night

# --- Sky horizon color keyframes ---
const SKY_HORIZON_SUNRISE: Color = Color(0.9, 0.55, 0.2, 1.0)
const SKY_HORIZON_MIDDAY: Color = Color(0.45, 0.62, 0.85, 1.0)
const SKY_HORIZON_SUNSET: Color = Color(0.85, 0.42, 0.12, 1.0)
const SKY_HORIZON_NIGHT: Color = Color(0.04, 0.05, 0.12, 1.0)

# Spawn constants — must match the builder so the respawn lands at the same point.
const SPAWN_POS: Vector3 = Vector3(24.0, 1.0, 30.0)
# Facing -Z = rotation_y of PI
const SPAWN_ROT_Y: float = PI

# Crusher sweep bounds (world X) and speed — must match builder CRUSHER_START/lane.
const CRUSHER_X_MIN: float = 8.0
const CRUSHER_X_MAX: float = 20.0
const CRUSHER_SPEED: float = 4.0  # m/s

## WaveManager sibling — injected by main.gd after level load.
## Used to route fall/hazard life-loss through the shared lose_life() seam.
@export var wave_manager: WaveManager

# Total period in seconds: ~214s daylight arc + ~86s night = 5 min full cycle.
# Lower for verification runs (e.g. 12.0 = 25x speed).
@export var period_seconds: float = 300.0

# Normalized day-time in [0, 1). Starts at sunrise (t=0) per design doc.
var _day_t: float = 0.0
# Ping-pong direction: +1 = moving toward X_MAX, -1 = toward X_MIN.
var _crusher_dir: float = 1.0

@onready var _sun: DirectionalLight3D = $Sun
@onready var _world_env: WorldEnvironment = $WorldEnvironment
@onready var _fall_zone: Area3D = $FallZone
@onready var _hazard_floor: Area3D = $HazardFloor
@onready var _crusher: StaticBody3D = $Crusher
@onready var _crusher_hit: Area3D = $Crusher/CrusherHit
@onready var _npc0: Npc = $Npc0
@onready var _npc1: Npc = $Npc1


func _ready() -> void:
	# Immediately apply the sunrise start state so the first frame is correct.
	_apply(_day_t)
	_fall_zone.body_entered.connect(_on_FallZone_body_entered)
	_hazard_floor.body_entered.connect(_on_HazardFloor_body_entered)
	_crusher_hit.body_entered.connect(_on_CrusherHit_body_entered)
	# Inject WaveManager into all civilian NPCs (DI — no find_child/autoload).
	_npc0.wave_manager = wave_manager
	_npc1.wave_manager = wave_manager
	# Navigation mesh is pre-baked (tools/bake_navmesh.gd) and stored in
	# levels/firing_yard_navmesh.tres — no runtime bake needed.


# Shared reset helper — teleports a Player body back to spawn and costs a life.
func _reset_player(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	body.global_position = SPAWN_POS
	body.rotation.y = SPAWN_ROT_Y
	# SEAM: duck-typed reset — velocity is on CharacterBody3D, not the Node3D base type.
	@warning_ignore("unsafe_property_access")
	body.velocity = Vector3.ZERO
	if wave_manager != null:
		wave_manager.lose_life()


# Respawn the player when they fall through a fake-wall hole.
func _on_FallZone_body_entered(body: Node3D) -> void:
	_reset_player(body)


# Respawn the player when they step onto the hazard floor patch.
func _on_HazardFloor_body_entered(body: Node3D) -> void:
	print("[hazard] floor touched -> reset")
	_reset_player(body)


# Respawn the player when the crusher catches them.
func _on_CrusherHit_body_entered(body: Node3D) -> void:
	print("[hazard] crushed -> reset")
	_reset_player(body)


func _process(delta: float) -> void:
	_day_t = fmod(_day_t + delta / period_seconds, 1.0)
	_apply(_day_t)
	_move_crusher(delta)


func _move_crusher(delta: float) -> void:
	var x: float = _crusher.position.x + _crusher_dir * CRUSHER_SPEED * delta
	if x >= CRUSHER_X_MAX:
		x = CRUSHER_X_MAX
		_crusher_dir = -1.0
	elif x <= CRUSHER_X_MIN:
		x = CRUSHER_X_MIN
		_crusher_dir = 1.0
	_crusher.position.x = x


# Apply all lighting state for normalized time t in [0, 1).
func _apply(t: float) -> void:
	if t < DAYLIGHT_FRACTION:
		# Daylight arc: map t into [0, 1) within the day sub-period.
		var day_t: float = t / DAYLIGHT_FRACTION
		_apply_day(day_t)
	else:
		# Night phase: map t into [0, 1) within the night sub-period.
		var night_t: float = (t - DAYLIGHT_FRACTION) / (1.0 - DAYLIGHT_FRACTION)
		_apply_night(night_t)


# Drive all values across the daylight arc (day_t: 0=sunrise, 0.5=midday, 1=sunset).
func _apply_day(day_t: float) -> void:
	# Split the arc into sunrise→midday (0..0.5) and midday→sunset (0.5..1).
	var sun_pitch: float
	var sun_energy: float
	var sun_color: Color
	var ambient_color: Color
	var ambient_energy: float
	var sky_top: Color
	var sky_horizon: Color

	if day_t < 0.5:
		var h: float = day_t * 2.0  # 0 = sunrise, 1 = midday
		sun_pitch = lerpf(SUN_PITCH_SUNRISE, SUN_PITCH_MIDDAY, h)
		sun_energy = lerpf(SUN_ENERGY_SUNRISE, SUN_ENERGY_MIDDAY, h)
		sun_color = SUN_COLOR_SUNRISE.lerp(SUN_COLOR_MIDDAY, h)
		ambient_color = AMBIENT_COLOR_SUNRISE.lerp(AMBIENT_COLOR_MIDDAY, h)
		ambient_energy = lerpf(AMBIENT_ENERGY_SUNRISE, AMBIENT_ENERGY_MIDDAY, h)
		sky_top = SKY_TOP_SUNRISE.lerp(SKY_TOP_MIDDAY, h)
		sky_horizon = SKY_HORIZON_SUNRISE.lerp(SKY_HORIZON_MIDDAY, h)
	else:
		var h: float = (day_t - 0.5) * 2.0  # 0 = midday, 1 = sunset
		sun_pitch = lerpf(SUN_PITCH_MIDDAY, SUN_PITCH_SUNSET, h)
		sun_energy = lerpf(SUN_ENERGY_MIDDAY, SUN_ENERGY_SUNSET, h)
		sun_color = SUN_COLOR_MIDDAY.lerp(SUN_COLOR_SUNSET, h)
		ambient_color = AMBIENT_COLOR_MIDDAY.lerp(AMBIENT_COLOR_SUNSET, h)
		ambient_energy = lerpf(AMBIENT_ENERGY_MIDDAY, AMBIENT_ENERGY_SUNSET, h)
		sky_top = SKY_TOP_MIDDAY.lerp(SKY_TOP_SUNSET, h)
		sky_horizon = SKY_HORIZON_MIDDAY.lerp(SKY_HORIZON_SUNSET, h)

	_apply_sun(sun_pitch, sun_energy, sun_color)
	_apply_env(ambient_color, ambient_energy, sky_top, sky_horizon)


# Drive all values through the night phase (night_t: 0=just-past-sunset, 1=about-to-sunrise).
func _apply_night(night_t: float) -> void:
	# Blend sunset→night for first quarter, hold night, blend night→sunrise for last quarter.
	var sun_pitch: float
	var sun_energy: float
	var sun_color: Color
	var ambient_color: Color
	var ambient_energy: float
	var sky_top: Color
	var sky_horizon: Color

	if night_t < 0.25:
		var h: float = night_t * 4.0  # 0 = sunset, 1 = full night
		sun_pitch = lerpf(SUN_PITCH_SUNSET, SUN_PITCH_NIGHT, h)
		sun_energy = lerpf(SUN_ENERGY_SUNSET, SUN_ENERGY_NIGHT, h)
		sun_color = SUN_COLOR_SUNSET.lerp(SUN_COLOR_NIGHT, h)
		ambient_color = AMBIENT_COLOR_SUNSET.lerp(AMBIENT_COLOR_NIGHT, h)
		ambient_energy = lerpf(AMBIENT_ENERGY_SUNSET, AMBIENT_ENERGY_NIGHT, h)
		sky_top = SKY_TOP_SUNSET.lerp(SKY_TOP_NIGHT, h)
		sky_horizon = SKY_HORIZON_SUNSET.lerp(SKY_HORIZON_NIGHT, h)
	elif night_t < 0.75:
		# Full night hold — constant moonlight floor.
		sun_pitch = SUN_PITCH_NIGHT
		sun_energy = SUN_ENERGY_NIGHT
		sun_color = SUN_COLOR_NIGHT
		ambient_color = AMBIENT_COLOR_NIGHT
		ambient_energy = AMBIENT_ENERGY_NIGHT
		sky_top = SKY_TOP_NIGHT
		sky_horizon = SKY_HORIZON_NIGHT
	else:
		var h: float = (night_t - 0.75) * 4.0  # 0 = full night, 1 = sunrise
		sun_pitch = lerpf(SUN_PITCH_NIGHT, SUN_PITCH_SUNRISE, h)
		sun_energy = lerpf(SUN_ENERGY_NIGHT, SUN_ENERGY_SUNRISE, h)
		sun_color = SUN_COLOR_NIGHT.lerp(SUN_COLOR_SUNRISE, h)
		ambient_color = AMBIENT_COLOR_NIGHT.lerp(AMBIENT_COLOR_SUNRISE, h)
		ambient_energy = lerpf(AMBIENT_ENERGY_NIGHT, AMBIENT_ENERGY_SUNRISE, h)
		sky_top = SKY_TOP_NIGHT.lerp(SKY_TOP_SUNRISE, h)
		sky_horizon = SKY_HORIZON_NIGHT.lerp(SKY_HORIZON_SUNRISE, h)

	_apply_sun(sun_pitch, sun_energy, sun_color)
	_apply_env(ambient_color, ambient_energy, sky_top, sky_horizon)


func _apply_sun(pitch_deg: float, energy: float, color: Color) -> void:
	_sun.rotation_degrees = Vector3(pitch_deg, SUN_YAW, 0.0)
	_sun.light_energy = energy
	_sun.light_color = color


func _apply_env(
	ambient_color: Color, ambient_energy: float, sky_top: Color, sky_horizon: Color
) -> void:
	var env: Environment = _world_env.environment
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy
	var sky_mat: ProceduralSkyMaterial = env.sky.sky_material as ProceduralSkyMaterial
	if sky_mat != null:
		sky_mat.sky_top_color = sky_top
		sky_mat.sky_horizon_color = sky_horizon
		sky_mat.ground_horizon_color = sky_horizon
