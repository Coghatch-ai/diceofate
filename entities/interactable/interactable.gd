# entities/interactable/interactable.gd — Area3D the player can interact with (message or pickup).
class_name Interactable
extends Area3D

enum Type { MESSAGE, INVENTORY }

@export var type: Type = Type.MESSAGE
@export var message_text: String = ""
@export var item_name: String = ""

var _overlapping_players: Array[Node3D] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not _overlapping_players.is_empty():
		_interact()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		_overlapping_players.append(body)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		_overlapping_players.erase(body)


func _interact() -> void:
	match type:
		Type.MESSAGE:
			print(message_text)
		Type.INVENTORY:
			if not _overlapping_players.is_empty():
				var player: Node3D = _overlapping_players[0]
				print("Picked up: ", item_name)
				if player.has_method("add_item"):
					# SEAM: duck-typed pickup — any body with add_item() can collect
					# (godot-composition: no concrete cross-entity types).
					@warning_ignore("unsafe_method_access")
					player.add_item(item_name)
				queue_free()
