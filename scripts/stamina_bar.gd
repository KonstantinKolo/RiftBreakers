extends TextureProgressBar

@onready var rich_text_label: RichTextLabel = $RichTextLabel
@onready var player: CharacterBody3D = $"../../../.."

func _ready():
	player.staminaChanged.connect(update)
	player.blinkStaminaBar.connect(blink)
	update()

func blink():
	while player.stamina < 20:
		await get_tree().create_timer(0.5).timeout
		modulate = Color(1,0,0)
		await get_tree().create_timer(0.5).timeout
		modulate = Color(1, 1, 1, 0.9922)
	
	modulate = Color(1, 1, 1, 0.9922)
	player.critical_stamina = false

func update():
	value = player.stamina
	rich_text_label.text = "[b]" + str(value) + "/100[/b]" 
