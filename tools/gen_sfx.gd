#!/usr/bin/env -S godot --headless --script
# tools/gen_sfx.gd — synthesise placeholder WAVs for P2 SFX (16-bit PCM, 44100 Hz, mono).
# Run: $GODOT --headless --path . --script tools/gen_sfx.gd
extends SceneTree

const SAMPLE_RATE: int = 44100


func _init() -> void:
	_write_wav("assets/audio/projectile_hit.wav", _gen_hit())
	_write_wav("assets/audio/enemy_death.wav", _gen_death())
	_write_wav("assets/audio/enemy_touch_reset.wav", _gen_reset())
	_write_wav("assets/audio/player_jump.wav", _gen_jump())
	_write_wav("assets/audio/player_land.wav", _gen_land())
	_write_wav("assets/audio/enemy_ambient.wav", _gen_ambient())
	_write_wav("assets/audio/weapon_empty.wav", _gen_weapon_empty())
	_write_wav("assets/audio/weapon_reload.wav", _gen_weapon_reload())
	print("gen_sfx: done")
	quit()


# Short noise burst + pitch drop — impact thud.
func _gen_hit() -> PackedByteArray:
	var dur := int(SAMPLE_RATE * 0.12)
	var out := PackedByteArray()
	out.resize(dur * 2)
	for i: int in dur:
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 30.0)
		var noise := randf_range(-1.0, 1.0)
		var tone := sin(TAU * (800.0 - 600.0 * t) * t)
		var s := clampf((noise * 0.4 + tone * 0.6) * env, -1.0, 1.0)
		var v := int(s * 32767.0)
		out[i * 2] = v & 0xFF
		out[i * 2 + 1] = (v >> 8) & 0xFF
	return out


# Descending gliss + noise fade — retro death.
func _gen_death() -> PackedByteArray:
	var dur := int(SAMPLE_RATE * 0.35)
	var out := PackedByteArray()
	out.resize(dur * 2)
	for i: int in dur:
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 8.0)
		var freq := 600.0 * exp(-t * 5.0)
		var tone := sin(TAU * freq * t)
		var noise := randf_range(-1.0, 1.0)
		var s := clampf((tone * 0.7 + noise * 0.3) * env, -1.0, 1.0)
		var v := int(s * 32767.0)
		out[i * 2] = v & 0xFF
		out[i * 2 + 1] = (v >> 8) & 0xFF
	return out


# Harsh buzz — alarm/reset sting.
func _gen_reset() -> PackedByteArray:
	var dur := int(SAMPLE_RATE * 0.25)
	var out := PackedByteArray()
	out.resize(dur * 2)
	for i: int in dur:
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 12.0)
		var square := 1.0 if sin(TAU * 220.0 * t) > 0.0 else -1.0
		var s := clampf(square * env * 0.8, -1.0, 1.0)
		var v := int(s * 32767.0)
		out[i * 2] = v & 0xFF
		out[i * 2 + 1] = (v >> 8) & 0xFF
	return out


# Rising chirp — boing/spring.
func _gen_jump() -> PackedByteArray:
	var dur := int(SAMPLE_RATE * 0.18)
	var out := PackedByteArray()
	out.resize(dur * 2)
	for i: int in dur:
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 15.0)
		var freq := 200.0 + 800.0 * t
		var tone := sin(TAU * freq * t)
		var s := clampf(tone * env, -1.0, 1.0)
		var v := int(s * 32767.0)
		out[i * 2] = v & 0xFF
		out[i * 2 + 1] = (v >> 8) & 0xFF
	return out


# Short thud — low thump on landing.
func _gen_land() -> PackedByteArray:
	var dur := int(SAMPLE_RATE * 0.1)
	var out := PackedByteArray()
	out.resize(dur * 2)
	for i: int in dur:
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 40.0)
		var tone := sin(TAU * 80.0 * t)
		var noise := randf_range(-1.0, 1.0)
		var s := clampf((tone * 0.6 + noise * 0.4) * env, -1.0, 1.0)
		var v := int(s * 32767.0)
		out[i * 2] = v & 0xFF
		out[i * 2 + 1] = (v >> 8) & 0xFF
	return out


# 1-second looping low growl — 80 Hz saw + filtered noise, seamless loop (starts/ends at zero).
func _gen_ambient() -> PackedByteArray:
	var dur := SAMPLE_RATE  # exactly 1 s for clean loop point
	var out := PackedByteArray()
	out.resize(dur * 2)
	for i: int in dur:
		var t := float(i) / SAMPLE_RATE
		# Fade in/out at edges to avoid click at loop boundary (5 ms ramps).
		var fade_len := int(SAMPLE_RATE * 0.005)
		var env := 1.0
		if i < fade_len:
			env = float(i) / float(fade_len)
		elif i > dur - fade_len:
			env = float(dur - i) / float(fade_len)
		# Low sawtooth growl at 80 Hz + heavy noise for organic texture.
		var saw := fmod(t * 80.0, 1.0) * 2.0 - 1.0
		var noise := randf_range(-1.0, 1.0)
		var s := clampf((saw * 0.5 + noise * 0.5) * env * 0.6, -1.0, 1.0)
		var v := int(s * 32767.0)
		out[i * 2] = v & 0xFF
		out[i * 2 + 1] = (v >> 8) & 0xFF
	return out


# Very short high-freq click + fast decay — dry trigger on empty magazine.
func _gen_weapon_empty() -> PackedByteArray:
	var dur := int(SAMPLE_RATE * 0.06)
	var out := PackedByteArray()
	out.resize(dur * 2)
	for i: int in dur:
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 80.0)
		var square := 1.0 if sin(TAU * 1200.0 * t) > 0.0 else -1.0
		var noise := randf_range(-1.0, 1.0)
		var s := clampf((square * 0.7 + noise * 0.3) * env, -1.0, 1.0)
		var v := int(s * 32767.0)
		out[i * 2] = v & 0xFF
		out[i * 2 + 1] = (v >> 8) & 0xFF
	return out


# Short mechanical clack — magazine seat / rack sound at reload-start.
func _gen_weapon_reload() -> PackedByteArray:
	var dur := int(SAMPLE_RATE * 0.18)
	var out := PackedByteArray()
	out.resize(dur * 2)
	for i: int in dur:
		var t := float(i) / SAMPLE_RATE
		# Two-transient shape: initial clack (t < 0.04) then quieter scrape tail.
		var env := 0.0
		if t < 0.04:
			env = exp(-t * 60.0)
		else:
			env = exp(-(t - 0.04) * 25.0) * 0.35
		var freq := 400.0 - 200.0 * t
		var tone := sin(TAU * freq * t)
		var noise := randf_range(-1.0, 1.0)
		var s := clampf((tone * 0.5 + noise * 0.5) * env, -1.0, 1.0)
		var v := int(s * 32767.0)
		out[i * 2] = v & 0xFF
		out[i * 2 + 1] = (v >> 8) & 0xFF
	return out


func _write_wav(path: String, pcm: PackedByteArray) -> void:
	var data_size := pcm.size()
	var header := PackedByteArray()
	header.resize(44)
	# RIFF chunk
	header[0] = 0x52
	header[1] = 0x49
	header[2] = 0x46
	header[3] = 0x46  # "RIFF"
	var riff_size: int = 36 + data_size
	header[4] = riff_size & 0xFF
	header[5] = (riff_size >> 8) & 0xFF
	header[6] = (riff_size >> 16) & 0xFF
	header[7] = (riff_size >> 24) & 0xFF
	header[8] = 0x57
	header[9] = 0x41
	header[10] = 0x56
	header[11] = 0x45  # "WAVE"
	# fmt  chunk
	header[12] = 0x66
	header[13] = 0x6D
	header[14] = 0x74
	header[15] = 0x20  # "fmt "
	header[16] = 16
	header[17] = 0
	header[18] = 0
	header[19] = 0  # chunk size = 16
	header[20] = 1
	header[21] = 0  # PCM
	header[22] = 1
	header[23] = 0  # mono
	header[24] = SAMPLE_RATE & 0xFF
	header[25] = (SAMPLE_RATE >> 8) & 0xFF
	header[26] = (SAMPLE_RATE >> 16) & 0xFF
	header[27] = (SAMPLE_RATE >> 24) & 0xFF
	var byte_rate: int = SAMPLE_RATE * 2
	header[28] = byte_rate & 0xFF
	header[29] = (byte_rate >> 8) & 0xFF
	header[30] = (byte_rate >> 16) & 0xFF
	header[31] = (byte_rate >> 24) & 0xFF
	header[32] = 2
	header[33] = 0  # block align
	header[34] = 16
	header[35] = 0  # bits per sample
	# data chunk
	header[36] = 0x64
	header[37] = 0x61
	header[38] = 0x74
	header[39] = 0x61  # "data"
	header[40] = data_size & 0xFF
	header[41] = (data_size >> 8) & 0xFF
	header[42] = (data_size >> 16) & 0xFF
	header[43] = (data_size >> 24) & 0xFF

	var full := PackedByteArray()
	full.append_array(header)
	full.append_array(pcm)

	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("gen_sfx: cannot open %s" % path)
		return
	f.store_buffer(full)
	f.close()
	print("gen_sfx: wrote %s (%d bytes)" % [path, full.size()])
