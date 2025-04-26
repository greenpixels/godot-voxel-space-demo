extends Node2D

@export var height_map : Texture2D
@export var color_map : Texture2D
var height_map_image : Image
var color_map_image : Image
var y_buffer : Array[float] = []
const SCREEN_WIDTH := 250
const SCREEN_HEIGHT := 150
const SPEED = 5.
var blur_step : float
var min_height : float
var min_width : float
var screen_range = range(0, SCREEN_WIDTH)

var current_position : Vector2 = Vector2.ZERO :
	set(value):
		current_position = value
		queue_redraw()
var current_height : float = 200 :
	set(value):
		current_height = value
		blur_step = clamp(current_height / 20000., 0.05, 0.09)
		queue_redraw()
		
func _ready() -> void:
	y_buffer.resize(SCREEN_WIDTH)
	height_map_image = height_map.get_image()
	color_map_image = color_map.get_image()
	min_height = min(height_map.get_size().y, color_map.get_size().y)
	min_width = min(height_map.get_size().x, color_map.get_size().x)
	blur_step = clamp(current_height / 20000., 0.03, 0.05)
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
		current_height += 5.
	if event.is_action("ui_text_delete"):
		current_height -= 5.

func render(pos : Vector2, phi: float,  height: float, horizon: float, scale_height: float, distance: float, screen_width: float, screen_height: float):
	var sinphi = sin(phi);
	var cosphi = cos(phi);

	y_buffer.fill(screen_height)
	
	var dz : float = 1.
	var z : float = 1.
	
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
			var draw_pos_x = wrapf(pleft.x, 0, min_width)
			var draw_pos_y = wrapf(pleft.y, 0, min_height)
			
			var height_on_screen = (height - height_map_image.get_pixel(draw_pos_x, draw_pos_y).v * 255.) / z * scale_height + horizon

			if height_on_screen < y_buffer[i]:
				var color = color_map_image.get_pixel(draw_pos_x, draw_pos_y)
				draw_line(Vector2(i,  y_buffer[i]), Vector2(i, min(y_buffer[i], height_on_screen)), color, 1)
				y_buffer[i] = height_on_screen
			pleft.x += dx 
			pleft.y += dy 
		z += dz
		dz += blur_step



func _draw() -> void:
	var start_time = Time.get_ticks_msec()
	render(current_position, 0, current_height, 50, 120, 800, SCREEN_WIDTH, SCREEN_HEIGHT)
	%FpsCounter.text = str(Time.get_ticks_msec() - start_time)
