# tools/gen_bus_layout.gd - headless script: generates default_bus_layout.tres
extends SceneTree


func _init() -> void:
	var layout := AudioBusLayout.new()
	# Bus 0: Master (always present, rename not needed — it's named Master by default)
	# AudioBusLayout buses array uses a special engine structure; use AudioServer API instead.
	AudioServer.set_bus_count(3)
	AudioServer.set_bus_name(0, "Master")
	AudioServer.set_bus_name(1, "SFX")
	AudioServer.set_bus_send(1, "Master")
	AudioServer.set_bus_name(2, "Music")
	AudioServer.set_bus_send(2, "Master")
	layout = AudioServer.generate_bus_layout()
	var err: int = ResourceSaver.save(layout, "res://default_bus_layout.tres")
	if err != OK:
		push_error("gen_bus_layout: ResourceSaver.save failed, error %d" % err)
		quit(1)
	else:
		print("gen_bus_layout: saved res://default_bus_layout.tres")
		quit(0)
