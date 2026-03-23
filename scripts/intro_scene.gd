extends Node3D

@export var scroll_speed: float = 40.0

@onready var animation_player: AnimationPlayer = $SmoothMC/AnimationPlayer
@onready var scene_animation_player: AnimationPlayer = $AnimationPlayer
@onready var color_rect_2: ColorRect = $CanvasLayer/ColorRect2
@onready var story: RichTextLabel = $CanvasLayer/Story

var scroll_stop: bool = false

func _ready() -> void:
	color_rect_2.visible = false
	animation_player.play("a-idle")
	scene_animation_player.play("initial_load")
	_lang_setup()

func _process(delta):
	if !scroll_stop:
		story.position.y -= scroll_speed * delta

func _on_button_pressed() -> void:
	color_rect_2.visible = false
	story.visible = false
	scene_animation_player.play("fade_to_black")
	scene_animation_player.animation_finished.connect(_on_fade_finished, CONNECT_ONE_SHOT)
func _on_button_2_pressed() -> void:
	color_rect_2.visible = !color_rect_2.visible
	story.visible = !story.visible
	scroll_stop = !scroll_stop

func _on_rich_text_label_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))
	
func _on_fade_finished(anim_name: StringName) -> void:
	if anim_name == "fade_to_black":
		get_tree().change_scene_to_file("res://scenes/Maps/menu.tscn")


func _on_english_lang_pressed() -> void:
	Global.selected_language = "en"
	_lang_setup()
func _on_bulgarian_lang_pressed() -> void:
	Global.selected_language = "bg"
	_lang_setup()
func _lang_setup() -> void:
	if Global.selected_language == "en":
		$CanvasLayer/Button.text = "SKIP"
		$CanvasLayer/Button2.text = "CREDITS"
		story.text = "YEAR 2041.

Without warning,
PORTALS tear open across the world.

From them march AUTONOMOUS WAR MACHINES —
not explorers,
not refugees,
but CONQUERORS.

Cities fall in hours.
Nations fracture in days.

Humanity fights back with weapons of today…
and technology stolen from the invaders themselves.

From the wreckage of battle,
a new kind of soldier emerges.

One man.
One mission.

Each portal is guarded.
Each guardian is a COMMANDER.

To save Earth,
the portals must be destroyed…
and their masters TERMINATED.

The fate of the planet now rests
on the path he chooses…

AND THE ENEMIES HE DEFEATS."
		$CanvasLayer/ColorRect2/RichTextLabel.text = "loading screen SVG -> [url=https://loading.io]link[/url]
Character Base Male -> Author: madtrollstudio , [url=https://poly.pizza/m/qbDLeTtb8K]link[/url]
Crosshair and other SVGs -> [url=https://www.freepik.com/icons]link[/url]
Pistol model -> Author: Klasy , [url=https://sketchfab.com/3d-models/stylized-pistol-low-poly-rigged-37c5583eb5974f57bcbfe447bbec9cd2#download]link[/url]
Rifle model -> Author: TastyTony , [url=https://sketchfab.com/3d-models/low-poly-stg-940-8a4382f34bc746eeb5914a9e09d18ae1]link[/url]
City Map Building set -> Author: Daniel Zhabotinsky , [url=https://sketchfab.com/3d-models/downtown-buildings-set-low-poly-model-7378e7fb9c914c39880d9913a6f4e1d6]link[/url]
Fences -> Author: TampaJoey , [url=https://sketchfab.com/3d-models/chain-link-fence-pack-low-poly-game-ready-777e50cd6e5d4db99d70bf7b20370f7a#download]link[/url]
Dumpster -> Author: Colin.Greenall , [url=https://sketchfab.com/3d-models/low-poly-dumpster-093e5b05faa947729b1be24c013e563b
Map 2 Ground Texture -> Author: reptilianalien , link: https://reptilianalien.itch.io/tbgp]link[/url]
Map 3 -> author: akselmot , [url=https://sketchfab.com/3d-models/modern-city-block-c80dba249d9547cbb48d00828d23cfa7#download]link[/url]
Additional building -> Author: Daniel Zhabotinsky , [url=https://sketchfab.com/3d-models/brownstone-building-set-low-poly-model-b15e6344acd844eabc823e1cc8332574]link[/url]
Music -> author: David KBD, [url=https://davidkbd.itch.io/the-last-post-apocalypticambient-music-asset-pack]link[/url]"
	elif Global.selected_language == "bg":
		$CanvasLayer/Button.text = "ПРОПУСНИ"
		$CanvasLayer/Button2.text = "КРЕДИТИ"
		story.text = "ГОДИНА 2041.
		
Без предупреждение,
ПОРТАЛИ се разтварят по целия свят.

От тях нахлуват АВТОНОМНИ БОЙНИ МАШИНИ —
не изследователи,
не бежанци,
а ЗАВОЕВАТЕЛИ.

Градове падат за часове.
Нации се разпадат за дни.

Човечеството отвръща с оръжията на днешния ден…
и технологии, откраднати от самите нашественици.

От руините на битката
се ражда нов вид войник.

Един човек.
Една мисия.

Всеки портал е пазен.
Всеки пазител е КОМАНДИР.

За да спаси Земята,
порталите трябва да бъдат унищожени…
а техните господари — ЛИКВИДИРАНИ.

Съдбата на планетата вече зависи
от пътя, който той избере…

И ВРАГОВЕТЕ, КОИТО ПОБЕДИ."
		$CanvasLayer/ColorRect2/RichTextLabel.text = "SVG за екран на зареждане -> [url=https://loading.io]линк[/url]
Базов модел на персонаж -> Автор: madtrollstudio , [url=https://poly.pizza/m/qbDLeTtb8K]линк[/url]
Мерник и други SVG файлове -> [url=https://www.freepik.com/icons]линк[/url]
Модел на пистолет -> Автор: Klasy , [url=https://sketchfab.com/3d-models/stylized-pistol-low-poly-rigged-37c5583eb5974f57bcbfe447bbec9cd2#download]линк[/url]
Модел на пушка -> Автор: TastyTony , [url=https://sketchfab.com/3d-models/low-poly-stg-940-8a4382f34bc746eeb5914a9e09d18ae1]линк[/url]
Сграден комплект за градска карта -> Автор: Daniel Zhabotinsky , [url=https://sketchfab.com/3d-models/downtown-buildings-set-low-poly-model-7378e7fb9c914c39880d9913a6f4e1d6]линк[/url]
Огради -> Автор: TampaJoey , [url=https://sketchfab.com/3d-models/chain-link-fence-pack-low-poly-game-ready-777e50cd6e5d4db99d70bf7b20370f7a#download]линк[/url]
Контейнер за боклук -> Автор: Colin.Greenall , [url=https://sketchfab.com/3d-models/low-poly-dumpster-093e5b05faa947729b1be24c013e563b
Текстура на земята за Карта 2 -> Автор: reptilianalien , линк: https://reptilianalien.itch.io/tbgp]линк[/url]
Карта 3 -> Автор: akselmot , [url=https://sketchfab.com/3d-models/modern-city-block-c80dba249d9547cbb48d00828d23cfa7#download]линк[/url]
Допълнителна сграда -> Автор: Daniel Zhabotinsky , [url=https://sketchfab.com/3d-models/brownstone-building-set-low-poly-model-b15e6344acd844eabc823e1cc8332574]линк[/url]
Музика -> Автор: David KBD, [url=https://davidkbd.itch.io/the-last-post-apocalypticambient-music-asset-pack]линк[/url]"
