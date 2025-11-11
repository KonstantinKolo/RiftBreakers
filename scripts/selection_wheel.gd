@tool
extends Control

const SPRITE_SIZE = Vector2(128, 128)

@export var bkg_color: Color
@export var line_color: Color
@export var highlight_color: Color
@export var locked_color: Color

@export var outer_radious: int = 256
@export var inner_radious: int = 64
@export var line_width: int = 4

@export var options: Array[WheelOption]

var selection = 0

func Close() -> String:
	hide()
	var choice: String = options[selection].name
	if choice == "dynamite" and !Global.has_dynamite_unclocked:
		return ""
	if choice == "rifle" and !Global.has_rifle_unlocked:
		return ""
	return options[selection].name

func _draw():
	var offset = SPRITE_SIZE / -2

	draw_circle(Vector2.ZERO, outer_radious, bkg_color)
	draw_arc(Vector2.ZERO, inner_radious, 0, TAU, 128, line_color, line_width, true)

	if len(options) >= 3:
		# Draw separator lines
		for i in range(len(options) - 1):
			var rads = TAU * i / float(len(options) - 1)
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
			var start_rads = TAU * (i - 1) / float(len(options) - 1)
			var end_rads = TAU * i / float(len(options) - 1)
			var mid_rads = (start_rads + end_rads) / 2.0
			var radius_mid = (inner_radious + outer_radious) / 2
			
			# Highlight selected segment
			if selection == i:
				var points_per_arc = 128
				var points_inner := PackedVector2Array()
				var points_outer := PackedVector2Array()
				
				for j in range(points_per_arc + 1):
					var angle = start_rads + j * (end_rads - start_rads) / points_per_arc
					points_inner.append(inner_radious * Vector2.from_angle(TAU - angle))
					points_outer.append(outer_radious * Vector2.from_angle(TAU - angle))
				
				points_outer.reverse()
				var vertices := points_inner + points_outer
			
				# build a color array with one color per vertex
				var colors := PackedColorArray()
				var option_name: String
				if options.size() != i + 1: # for locked items
					option_name = options[i + 1].name if "name" in options[i] else ""
				if (option_name == "dynamite" and !Global.has_dynamite_unlocked) or \
				   (option_name == "rifle" and !Global.has_rifle_unlocked):
					for k in range(vertices.size()):
						colors.append(locked_color)
				else:
					for k in range(vertices.size()):
						colors.append(highlight_color)
			
				draw_polygon(vertices, colors)
			
			# Draw option sprite
			var draw_pos = radius_mid * Vector2.from_angle(mid_rads) + offset
			draw_texture_rect_region(
				options[i].atlas,
				Rect2(draw_pos, SPRITE_SIZE),
				options[i].region
			)
			
			# Draw small number near each option
			var number_pos = (radius_mid + 40) * Vector2.from_angle(mid_rads)  # move slightly outward
			# draw_string signature differs between versions; this is a typical usage:
			draw_string(
				get_theme_default_font(),
				number_pos - Vector2(6, 6),
				str(i),
			)
			
		# draw lines for the weapons that haven't been unlocked
		for i in range(1, len(options)):
			var name: String = options[i].name if "name" in options[i] else ""
			var locked := false
			
			if (name == "dynamite" and !Global.has_dynamite_unlocked) or \
			   (name == "rifle" and !Global.has_rifle_unlocked):
				locked = true
			
			if locked:
				# Compute the midpoint angle for this segment
				var start_rads = TAU * (i - 1) / float(len(options) - 1)
				var end_rads = TAU * i / float(len(options) - 1)
				var mid_rads = (start_rads + end_rads) / 2.0
				
				var radius_mid = (inner_radious + outer_radious) / 2.0
				var center_point = radius_mid * Vector2.from_angle(mid_rads)
				
				# Strike line across icon
				var slash_length = 80.0
				var slash_dir = Vector2(-center_point.y, center_point.x).normalized() * slash_length
				
				draw_line(center_point - slash_dir, center_point + slash_dir, Color.from_rgba8(45,45,45,235), line_width + 35.0, true)


func _input(event):
	if event is InputEventMouseMotion and visible:
		var mouse_rads = fposmod(event.relative.angle() * -1, TAU)
		selection = ceil((mouse_rads / TAU) * (len(options) - 1))
		queue_redraw()
