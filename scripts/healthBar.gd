extends TextureProgressBar

@onready var player: CharacterBody3D = $"../../../.."
@onready var rich_text_label: RichTextLabel = $RichTextLabel
@onready var damage: TextureRect = $Damage
@onready var timer: Timer = $Timer


func _ready():
	player.healthChanged.connect(update)
	update()
	damage.visible = false

func update():
	if player.health < value:
		#for taking damage
		damage.visible = true
		damage.size.x = (value - player.health) * 2
		damage.position.x = 201 - ((100 - player.health) * 2)
		timer.start()
	else:
		damage.visible = false
	
	value = player.health
	rich_text_label.text = "[b]" + str(value) + "/100[/b]" 


func _on_timer_timeout() -> void:
	damage.visible = false
