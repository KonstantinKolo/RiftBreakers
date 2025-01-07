extends TextureProgressBar

@onready var player: CharacterBody3D = $"../../.."
@onready var rich_text_label: RichTextLabel = $RichTextLabel


func _ready():
	player.healthChanged.connect(update)
	update()

func update():
	value = player.health
	rich_text_label.text = "[b]" + str(value) + "/100[/b]" 
