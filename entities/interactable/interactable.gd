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
	if event.is_action_pressed("interact") and _overlapping_players.size() > 0:
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
			if _overlapping_players.size() > 0:
				var player = _overlapping_players[0]
				print("Picked up: ", item_name)
				if player.has_method("add_item"):
					player.add_item(item_name)
				queue_free()
