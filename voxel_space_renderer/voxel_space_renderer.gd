extends Node2D

## Set the height map image (.png, .jpeg, etc)
@export var height_map: Texture2D:
	set(value):
		height_map = value
		height_map_image = value.get_image()
		WorkerThreadPool.add_task(_update_view)
		
@onready var height_map_image: Image = height_map.get_image()

## Set the colour map image (.png, .jpeg, etc)
@export var colour_map: Texture2D:
	set(value):
		colour_map = value
		colour_map_image = value.get_image()
		WorkerThreadPool.add_task(_update_view)

@onready var colour_map_image: Image = colour_map.get_image()

var image_mutex = Mutex.new()

## The view distance of the rendered output (big performance impact). This determines how far can be seen at one render in terms of depth.
@export var view_distance = 100.:
	set(value):
		view_distance = value
		WorkerThreadPool.add_task(_update_view)

## The view width of the rendered output (medium performance impact). This determines how much can be seen at one render in terms of width.
@export var field_of_view = 60.:
	set(value):
		field_of_view = value
		WorkerThreadPool.add_task(_update_view)

## The factor that the colour gets multiplied by (no performance impact). This determines how big mountains get, how high walls are and so on.
@export var amplitude = 300.:
	set(value):
		amplitude = value
		WorkerThreadPool.add_task(_update_view)

## The width of the rendered output (medium performance impact).
@export var render_width = 640.:
	set(value):
		render_width = value
		WorkerThreadPool.add_task(_update_view)

## The height of the rendered output (no performance impact).
@export var render_height = 360.:
	set(value):
		render_height = value
		WorkerThreadPool.add_task(_update_view)

## The current position of the rendered view (no performance impact).
@export var current_position = Vector2(0, 0):
	set(value):
		current_position = value
		WorkerThreadPool.add_task(_update_view)

## The approximate height of the view (no performance impact). This determines how far above the terrain the camera is.
@export var z_height = 50.:
	set(value):
		z_height = value
		WorkerThreadPool.add_task(_update_view)

## The approximate pitch of the view (no performance impact). This determines whether the camera looks up or down. 
@export var pitch: float = -20.:
	set(value):
		pitch = value
		WorkerThreadPool.add_task(_update_view)

@export var direction: float = 0.:
	set(value):
		direction = deg_to_rad(value)
		WorkerThreadPool.add_task(_update_view)
		
const STEP_SPEED = 26
const TURN_SPEED = 8
var output_texture: ImageTexture;
var last_render_time = 0
var last_process_time = 0
var last_update_time = 0

func _process(_delta):
	_move_view()

func _draw():
	var map_position = Vector2(render_width, 0)
	var view_width = (tan(deg_to_rad(field_of_view / 2.)) * view_distance) * 2
	# Draw 3d view
	if output_texture:
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
	draw_string(
		ThemeDB.fallback_font,
		Vector2(16, 32),
		"Rendering: {R_TIME}ms | Processing: {P_TIME}ms | Combined: {U_TIME}ms".format(
			{"R_TIME": last_render_time, "P_TIME": last_process_time, "U_TIME": last_update_time}),
		HORIZONTAL_ALIGNMENT_LEFT,
		- 1,
		ThemeDB.fallback_font_size,
		Color.WHITE
	)

## Move the current view based on keyboard input
func _move_view():
	if Input.is_action_just_pressed("ui_left"):
		direction = rad_to_deg(direction) - TURN_SPEED
	elif Input.is_action_just_pressed("ui_right"):
		direction = rad_to_deg(direction) + TURN_SPEED
		
	if Input.is_action_just_pressed("ui_down"):
		current_position -= Vector2.from_angle(direction + PI / 2) * STEP_SPEED
	elif Input.is_action_just_pressed("ui_up"):
		current_position += Vector2.from_angle(direction + PI / 2) * STEP_SPEED

## Update the current view and redraw the rendered output
func _update_view():
	var started_at = Time.get_ticks_msec()
	var render_lines = []
	var threads = []
	for distance in view_distance:
		var process_thread = Thread.new()
		threads.push_front(process_thread)
		process_thread.start(process_triangle_lines.bind(distance))
	render_lines = threads.map(func(_thread: Thread): return _thread.wait_to_finish())
	var process_time = Time.get_ticks_msec() - started_at
	
	var x = 0
	var image = Image.create(render_width, render_height, false, height_map_image.get_format())
	var z: float = view_distance
	for lines in render_lines:
		if lines == null: continue
		x = 0
		var line_width = render_width / lines.size()
		for values in lines:
			var height = (z_height - (values.v * 50.)) / z * amplitude + pitch
			image.fill_rect(
				Rect2i(
					Vector2(x, height),
					Vector2(line_width, render_height - height)
				),
				Color.from_string(values.c, Color.BLACK)
			)
			x += line_width
		z -= 1.
	output_texture = ImageTexture.create_from_image(image)
	var render_time = Time.get_ticks_msec() - process_time - started_at
	var update_time = Time.get_ticks_msec() - started_at
	last_render_time = render_time
	last_update_time = update_time
	last_process_time = process_time
	call_deferred("queue_redraw")
	
func process_triangle_lines(distance: int):
	if height_map_image == null or colour_map_image == null:
		return
	image_mutex.lock()
	var height_map_image_copy = Image.create_from_data(height_map_image.get_width(), height_map_image.get_height(), false, height_map_image.get_format(), height_map_image.get_data())
	var colour_map_image_copy = Image.create_from_data(colour_map_image.get_width(), colour_map_image.get_height(), false, colour_map_image.get_format(), colour_map_image.get_data())
	image_mutex.unlock()
	
	var triangle_render_width = (tan(deg_to_rad(field_of_view / 2.)) * distance) * 2
	var left_point = current_position + Vector2(triangle_render_width / ( - 2), distance).rotated(direction)
	var right_point = current_position + Vector2(triangle_render_width, distance).rotated(direction)
	var line = _get_line_in_height_map_stretched(
			left_point,
			right_point,
			height_map_image_copy,
			colour_map_image_copy,
			render_width,
			distance
			)
	return line

## Scan through a line of pixels and return an array containing the values of the scanned pixels
func _get_line_in_height_map_stretched(from: Vector2, to: Vector2, height_image: Image, colour_image: Image, target_width: float, distance: int) -> Array[Dictionary]:
	var step_distance: Vector2 = (to - from) / target_width
	var current_step = from
	var detail_blurrer = int(1 + (distance) / 25)
	var output: Array[Dictionary] = []
	var map_rect = Rect2(Vector2(0, 0), height_image.get_size())
	for count in int(target_width / detail_blurrer):
		if map_rect.has_point(current_step):
			var height_pixel = height_image.get_pixel(
					int(current_step.x),
					int(current_step.y)
				)
			var colour_pixel = colour_image.get_pixel(
					int(current_step.x),
					int(current_step.y)
				)
			output.push_front({
					"v": height_pixel.v,
					"c": colour_pixel.to_html()
				})
		else:
			output.push_front({
					"v": 0,
					"c": Color.BLACK.to_html()
				})
		current_step += step_distance * detail_blurrer
	return output
