extends Resource
class_name InteractableDialogueEntry

@export_file("*.json") var json_path: String = ""
@export var start_node: String = "start"
@export var presentation: String = "box"
@export var bubble_target: NodePath
