# levels/firing_yard.gd — day/night sun cycle driver for the Firing Yard arena.
class_name FiringYard
extends Node3D

# Fraction of the period that is daylight (sunrise → sunset arc): 300/420.
const DAYLIGHT_FRACTION: float = 300.0 / 420.0

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
# Moonlight floor — keeps targets readable at night.
const AMBIENT_ENERGY_NIGHT: float = 1.0

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

# Total period in seconds: ~5 min daylight arc + ~2 min night = ~7 min.
# Lower for verification runs (e.g. 14.0 = 10x speed).
@export var period_seconds: float = 420.0

# Normalized day-time in [0, 1). Starts at sunrise (t = 0).
var _day_t: float = 0.0

@onready var _sun: DirectionalLight3D = $Sun
@onready var _world_env: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	# Immediately apply the sunrise start state so the first frame is correct.
	_apply(_day_t)


func _process(delta: float) -> void:
	_day_t = fmod(_day_t + delta / period_seconds, 1.0)
	_apply(_day_t)


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
