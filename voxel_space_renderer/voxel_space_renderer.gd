extends Node2D

@export var height_map : Texture2D
@export var color_map : Texture2D

const SCREEN_WIDTH := 250
const SCREEN_HEIGHT := 150
const SPEED = 5.
var height_map_image : Image
var color_map_image : Image
var y_buffer : PackedFloat32Array = []
var blur_step : float
var min_height : int
var min_width : int
var screen_range : PackedInt32Array = range(0, SCREEN_WIDTH)
var phi : int = 0
var sinphi = sin(phi);
var cosphi = cos(phi);
var hm_bytes : PackedByteArray
var map_color_values : PackedColorArray = []
var lines_to_draw : PackedVector2Array = []
var colors_to_draw : PackedColorArray = []

var current_position : Vector2 = Vector2.ZERO :
	set(value):
		current_position = value
		queue_redraw()
var current_height : int = 200 :
	set(value):
		current_height = value
		blur_step = clamp(current_height / 20000., 0.05, 0.09)
		queue_redraw()
		
func _ready() -> void:
	lines_to_draw.resize(25000 * 2)
	lines_to_draw.fill(Vector2.ZERO)
	colors_to_draw.resize(25000)
	y_buffer.resize(SCREEN_WIDTH)
	height_map_image = height_map.get_image()
	height_map_image.convert(Image.FORMAT_L8)
	color_map_image = color_map.get_image()
	hm_bytes = height_map_image.get_data()
	min_height = min(height_map.get_size().y, color_map.get_size().y)
	min_width = min(height_map.get_size().x, color_map.get_size().x)
	blur_step = clamp(current_height / 20000., 0.04, 0.06)
	
	for y in range(color_map_image.get_size().y):
		for x in range(color_map_image.get_size().x):
			map_color_values.append(color_map_image.get_pixel(x, y))
				
	queue_redraw()
	
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action("ui_left"):
		current_position = current_position + Vector2.LEFT * SPEED
	if event.is_action("ui_right"):
		current_position = current_position + Vector2.RIGHT * SPEED
	if event.is_action("ui_up"):
		current_position = current_position + Vector2.UP * SPEED
	if event.is_action("ui_down"):
		current_position = current_position + Vector2.DOWN * SPEED
	if event.is_action("ui_select"):
		current_height += SPEED
	if event.is_action("ui_text_delete"):
		current_height -= SPEED

func render(pos : Vector2, height: int, horizon: int, scale_height: int, distance: float, screen_width: int, screen_height: int):
	var start_time = Time.get_ticks_msec()
	colors_to_draw.fill(Color.TRANSPARENT)
	y_buffer.fill(screen_height)
	
	var dz : float = 1.
	var z : float = 1.
	var inner_loop_count = 0
	var lines_computed = 0
	
	while z < distance:
		var pleft = Vector2(
			(-cosphi*z - sinphi*z) + pos.x,
			( sinphi*z - cosphi*z) + pos.y)
		var pright = Vector2(
			( cosphi*z - sinphi*z) + pos.x,
			(-sinphi*z - cosphi*z) + pos.y)
			
		var dx = (pright.x - pleft.x) / screen_width
		var dy = (pright.y - pleft.y) / screen_width
		
		for i in screen_range:
			inner_loop_count += 1
			var draw_pos_x = int(pleft.x) & (min_width - 1) 
			var draw_pos_y = int(pleft.y) & (min_height - 1) 
			
			var height_on_screen = (height - hm_bytes[draw_pos_y * min_width + draw_pos_x]) / z * scale_height + horizon
			if height_on_screen < y_buffer[i]:
				lines_computed += 1
				lines_to_draw[lines_computed * 2] = (Vector2(i,  y_buffer[i]))
				lines_to_draw[lines_computed * 2 + 1] = (Vector2(i, min(y_buffer[i], height_on_screen)))
				colors_to_draw[lines_computed] = (map_color_values[draw_pos_y * min_width + draw_pos_x])
				y_buffer[i] = height_on_screen
			pleft.x += dx 
			pleft.y += dy 
		z += dz
		dz += blur_step
	draw_multiline_colors(lines_to_draw, colors_to_draw, 1)
	print("Inner Loop Count: ", inner_loop_count, "; Lines Computed: ", lines_computed, "; Renderint took: ", Time.get_ticks_msec() - start_time, "ms")

func _draw() -> void:
	render(current_position, current_height, 50, 120, 1500, SCREEN_WIDTH, SCREEN_HEIGHT)
