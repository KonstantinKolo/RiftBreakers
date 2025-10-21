@tool
extends Control

const SPRITE_SIZE = Vector2(128, 128)

@export var bkg_color: Color
@export var line_color: Color
@export var highlight_color: Color

@export var outer_radious: int = 256
@export var inner_radious: int = 64
@export var line_width: int = 4

@export var options: Array[WheelOption]

var selection = 0

func Close():
	hide()
	return options[selection].name

func _draw():
	var offset = SPRITE_SIZE / -2
	
	draw_circle(Vector2.ZERO, outer_radious, bkg_color)
	draw_arc(Vector2.ZERO, inner_radious, 0, TAU, 128, line_color, line_width, true)
	
	if len(options) >= 3:
		# Draw separator lines
		for i in range(len(options) - 1):
			var rads = TAU * i / (len(options) - 1)
			var point = Vector2.from_angle(rads)
			draw_line(
				point * inner_radious,
				point * outer_radious,
				line_color,
				line_width,
				true
			)
		
		# Draw center highlight (first option)
		if selection == 0:
			draw_circle(Vector2.ZERO, inner_radious, highlight_color)
		
		# Draw the first option’s sprite
		draw_texture_rect_region(
			options[0].atlas,
			Rect2(offset, SPRITE_SIZE),
			options[0].region
		)
	
		# Draw other options and numbers
		for i in range(1, len(options)):
			var start_rads = (TAU * (i - 1) / (len(options) - 1))
			var end_rads = (TAU * i / (len(options) - 1))
			var mid_rads = (start_rads + end_rads) / 2.0 * -1
			var radius_mid = (inner_radious + outer_radious) / 2
			
			# Highlight selected segment
			if selection == i:
				var points_per_arc = 128
				var points_inner = PackedVector2Array()
				var points_outer = PackedVector2Array()
				
				for j in range(points_per_arc + 1):
					var angle = start_rads + j * (end_rads - start_rads) / points_per_arc
					points_inner.append(inner_radious * Vector2.from_angle(TAU - angle))
					points_outer.append(outer_radious * Vector2.from_angle(TAU - angle))
				
				points_outer.reverse()
				draw_polygon(points_inner + points_outer, PackedColorArray([highlight_color]))
			
			# Draw option sprite
			var draw_pos = radius_mid * Vector2.from_angle(mid_rads) + offset
			draw_texture_rect_region(
				options[i].atlas,
				Rect2(draw_pos, SPRITE_SIZE),
				options[i].region
			)
			
			# Draw small number near each option
			var number_pos = (radius_mid + 40) * Vector2.from_angle(mid_rads)  # move slightly outward
			draw_string(
				get_theme_default_font(),
				number_pos - Vector2(6, 6),  # small offset for centering
				str(i),
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				24,
				line_color
			)

func _input(event):
	if event is InputEventMouseMotion and visible:
		var mouse_rads = fposmod(event.relative.angle() * -1, TAU)
		selection = ceil((mouse_rads / TAU) * (len(options) - 1))
		queue_redraw()
