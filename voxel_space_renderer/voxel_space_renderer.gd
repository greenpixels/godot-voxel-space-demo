extends Node2D

## Set the height map image (.png, .jpeg, etc)
@export var height_map: Texture2D:
	set(value):
		height_map = value
		_update_view()

## The view distance of the rendered output (big performance impact). This determines how far can be seen at one render in terms of depth.
@export var view_distance = 100.:
	set(value):
		view_distance = value
		_update_view()

## The view width of the rendered output (medium performance impact). This determines how much can be seen at one render in terms of width.
@export var field_of_view = 60.:
	set(value):
		field_of_view = value
		_update_view()

## The factor that the colour gets multiplied by (no performance impact). This determines how big mountains get, how high walls are and so on.
@export var amplitude = 300.:
	set(value):
		amplitude = value
		_update_view()

## The width of the rendered output (medium performance impact).
@export var render_width = 640.:
	set(value):
		render_width = value
		_update_view()

## The height of the rendered output (no performance impact).
@export var render_height = 360.:
	set(value):
		render_height = value
		_update_view()

## The current position of the rendered view (no performance impact).
@export var current_position = Vector2(0, 0):
	set(value):
		current_position = value
		_update_view()

## The approximate height of the view (no performance impact). This determines how far above the terrain the camera is.
@export var z_height = 50.:
	set(value):
		z_height = value
		_update_view()

## The approximate pitch of the view (no performance impact). This determines whether the camera looks up or down. 
@export var pitch : float = -20.:
	set(value):
		pitch = value
		_update_view()

@export var direction : float = 0.:
	set(value):
		direction = deg_to_rad(value)
		_update_view()
		
const STEP_SPEED = 2
const TURN_SPEED = 8
var output_texture: ImageTexture;
var last_render_time = 0

func _process(_delta):
	_move_view()

func _draw():
	var map_position = Vector2(render_width, 0)
	var view_width = (tan(deg_to_rad(field_of_view / 2.)) * view_distance) * 2
	# Draw 3d view
	draw_texture(output_texture, Vector2(0, 0))
	# Draw 2d height map
	draw_texture(height_map, Vector2(render_width, 0))
	# Draw render width
	draw_line(
		map_position + current_position,
		map_position + current_position + Vector2( - view_width / 2, view_distance).rotated(direction),
		Color.GREEN
	)
	draw_line(
		map_position + current_position,
		map_position + current_position + Vector2(view_width / 2, view_distance).rotated(direction),
		Color.GREEN
	)
	draw_line(
		map_position + current_position + Vector2( - view_width / 2, view_distance).rotated(direction),
		map_position + current_position + Vector2(view_width / 2, view_distance).rotated(direction),
		Color.GREEN
	)
	# Draw render distance
	draw_line(map_position + current_position, map_position + current_position + Vector2(0, view_distance).rotated(direction), Color.BLUE)
	# Draw current position
	draw_circle(map_position + current_position, 3, Color.RED)
	# Draw debug information
	draw_string(ThemeDB.fallback_font, Vector2(16, 32), "Render took {TIME}ms".format({"TIME": last_render_time}), HORIZONTAL_ALIGNMENT_LEFT, -1, ThemeDB.fallback_font_size, Color.WHITE)

## Move the current view based on keyboard input
func _move_view():
	if Input.is_action_just_pressed("ui_left"):
		direction = rad_to_deg(direction) - TURN_SPEED
	elif Input.is_action_just_pressed("ui_right"):
		direction =  rad_to_deg(direction) + TURN_SPEED
		
	if Input.is_action_just_pressed("ui_down"):
		current_position -= Vector2.from_angle(direction + PI/2) * STEP_SPEED
	elif Input.is_action_just_pressed("ui_up"):
		current_position += Vector2.from_angle(direction + PI/2) * STEP_SPEED

## Update the current view and redraw the rendered output
func _update_view():
	var started_at = Time.get_ticks_msec()
	var array = _get_triangle_in_height_map()
	var x = 0
	var image = Image.create(render_width, render_height, false, height_map.get_image().get_format())
	var z: float = view_distance
	for lines in array:
		x = 0
		for value in lines:
			var height = (z_height - (value * 50.)) / z * amplitude + pitch
			image.fill_rect(
				Rect2i(
					Vector2(x, height),
					Vector2(1, height)
				),
				Color.from_hsv(0, 0, value, 1)
			)
			x += 1
		z -= 1.
		
	output_texture = ImageTexture.create_from_image(image)
	queue_redraw()
	var render_time = Time.get_ticks_msec() - started_at
	last_render_time = render_time

## Scan through lines in an expanding pattern (triangle shaped) and return a 2 dimensional array containing the values of the scanned pixels
func _get_triangle_in_height_map(): # -> Array[Array[float]] (can't type it since nested collections are not supported as types)
	var lines: Array = []

	for dist in range(view_distance):
		var step = dist
		var triangle_render_width = (tan(deg_to_rad(field_of_view / 2.)) * step) * 2
		var left_point = current_position + Vector2(triangle_render_width / ( - 2), step).rotated(direction)
		var right_point = current_position + Vector2(triangle_render_width, step).rotated(direction)
		
		lines.push_front(
			_get_line_in_height_map_stretched(
				left_point,
				right_point
			)
		)
		
	return lines

## Scan through a line of pixels and return an array containing the values of the scanned pixels
func _get_line_in_height_map_stretched(from: Vector2, to: Vector2) -> Array[float]:
	var height_map_image = height_map.get_image()
	var step_distance: Vector2 = (to - from) / render_width
	var current_step = from
	var output: Array[float] = []

	for count in int(render_width):
		if Rect2(Vector2(0, 0), height_map_image.get_size()).has_point(current_step):
			var pixel = height_map_image.get_pixel(
					int(current_step.x),
					int(current_step.y)
				)
			output.push_front(float(pixel.v))
		else:
			output.push_front(0)
		current_step += step_distance

	return output
