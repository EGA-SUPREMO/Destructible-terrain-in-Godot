extends Node2D

@onready var island_holder = $IslandHolder
@onready var circle: Node2D = $SubViewport/Circle
@onready var shape_sprite: Sprite2D = $SubViewport/ShapeSprite

var map_size: Vector2i
const FORCE_MULTIPLIER_TO_POLYGONS = 500

func _ready() -> void:
	add_to_group("destructibles")
	create_collisions()
	
	#var _image_republish_texture = ImageTexture.create_from_image(shape_sprite.texture.get_image())
	
	shape_sprite.material.set_shader_parameter("destruction_mask", circle)
	#shape_sprite.material.set_shader_parameter("ratio", float(map_size.x)/map_size.y)
	
	
func create_collisions():	
	var bitMap = BitMap.new()
	bitMap.create_from_image_alpha(shape_sprite.texture.get_image())
	
	var polygons = bitMap.opaque_to_polygons(Rect2(Vector2(0, 0), bitMap.get_size()))
	
	for polygon in polygons:
		var collider = CollisionPolygon2D.new()
		
		var newpoints := Array()
		var body := StaticBody2D.new()
		var polygon_temp := Polygon2D.new()
		
		body.collision_layer = 3
		body.collision_mask = 3
		
		for point in polygon:
			newpoints.push_back(point)
		
		collider.polygon = newpoints
		polygon_temp.polygon = collider.polygon
		polygon_temp.color = Color.WEB_MAROON
		map_size = bitMap.get_size()
		
		body.add_child(collider)
		body.add_child(polygon_temp)
		island_holder.add_child(body)
		
func clip(missile_polygon: PackedVector2Array):
	for collision_body in island_holder.get_children():
		var collision_polygon = collision_body.get_child(0)
		
		var offset_position = Vector2(-collision_body.global_position.x,
			-collision_body.global_position.y)
		offset_position = offset_position.rotated(-collision_body.rotation)
		
		var offset_missile_polygon := Transform2D(-collision_body.rotation,
			offset_position) * missile_polygon
		var res = Geometry2D.clip_polygons(collision_polygon.polygon, offset_missile_polygon)
		
		if res.size() == 0:
			collision_polygon.get_parent().queue_free()
			
		#for i in range(res.size() - 1, -1, -1):#has to go from size to 0, for some reason
		for i in range(res.size()):
			var clipped_collision = res[i]
			# These are awkward single or two-point floaters.
			if clipped_collision.size() < 3:
				continue
				
			if i == 0:
				collision_polygon.set_deferred("polygon", res[0])
				collision_body.get_child(1).set_deferred("polygon", res[0])
				
				if collision_body is RigidBody2D:
					collision_body.set_deferred("mass", abs(calculate_area(res[0])))
					var centroid = calculate_centroid(clipped_collision)
					if abs(centroid) > Vector2(0.5, 0.5):
						collision_polygon.set_deferred("polygon",
							offset_polygon_by_center_of_mass(res[0], centroid))
						collision_body.get_child(1).set_deferred("polygon",
							offset_polygon_by_center_of_mass(res[0], centroid))
						
						collision_body.set_deferred("global_position", collision_body.global_position + centroid.rotated(collision_body.rotation))

			else:
				var collider := CollisionPolygon2D.new()
				var polygon_temp := Polygon2D.new()
				var body := RigidBody2D.new()
				body.collision_layer = 3
				body.collision_mask = 3
				
				var centroid = calculate_centroid(clipped_collision)
				collider.polygon = offset_polygon_by_center_of_mass(clipped_collision, centroid)
				polygon_temp.polygon = collider.polygon
				polygon_temp.color = Color.WEB_MAROON
				
				body.rotation = collision_body.rotation
				body.global_position = collision_body.position + centroid.rotated(collision_body.rotation)
				body.contact_monitor = true
				body.max_contacts_reported = 2
				body.connect("body_entered", on_collision_polygon.bind(body))
				body.mass = abs(calculate_area(collider.polygon))
				
				island_holder.call_deferred("add_child", body)
				body.call_deferred("add_child", collider)
				body.call_deferred("add_child", polygon_temp)
				
func on_collision_polygon(_target_body, _body):
	if _target_body is CharacterBody2D:
		# TODO Shouldnt we check if player has velocity zero, if so, it'd mean that is being squished
		var angular_force = _body.angular_velocity * _body.mass
		var linear_force = _body.linear_velocity.length() * _body.mass
		var total_force = angular_force + linear_force# TODO este metodo le falta chicha
		#print(total_force)

func create_circle_radious_polygon(circle_position, radius: int) -> PackedVector2Array:
	var nb_points = 16
	var points_arc = PackedVector2Array()
	
	points_arc.push_back(circle_position)
	for i in range(nb_points + 1):
		var angle_point = deg_to_rad(i * 360 / nb_points)
		points_arc.push_back(circle_position + Vector2(cos(angle_point), sin(angle_point)) * radius)

	return points_arc

func calculate_area(mesh_vertices: PackedVector2Array) -> float:
	var result := 0.0
	var num_vertices := mesh_vertices.size()
	
	for q in range(num_vertices):
		var p = (q - 1 + num_vertices) % num_vertices
		result += mesh_vertices[q].cross(mesh_vertices[p])
	
	return result * 0.5

func calculate_centroid(mesh_vertices: PackedVector2Array) -> Vector2:
	var centroid = Vector2()
	var area = calculate_area(mesh_vertices)
	var num_vertices = mesh_vertices.size()
	var factor = 0.0

	for q in range(num_vertices):
		var p = (q - 1 + num_vertices) % num_vertices
		factor = mesh_vertices[q].cross(mesh_vertices[p])
		centroid += (mesh_vertices[q] + mesh_vertices[p]) * factor

	centroid /= (6.0 * area)
	return centroid

func offset_polygon_by_center_of_mass(polygon: PackedVector2Array, center_of_mass: Vector2) -> PackedVector2Array:
	var offset_polygon = Transform2D(0, -center_of_mass) * polygon
	return offset_polygon

func get_min_x_y(points: PackedVector2Array) -> Vector2:
	var min_x = points[0].x
	var min_y = points[0].y

	for point in points:
		if point.x < min_x:
			min_x = point.x
		if point.y < min_y:
			min_y = point.y
	return Vector2(min_x, min_y)

func apply_explotion_impulse(missile_position: Vector2, force: float) -> void:
	for collision_body in island_holder.get_children():
		if collision_body is RigidBody2D:
			var strength_knockback = Global.calculate_strength_knockback(collision_body.global_position,
				missile_position, force, collision_body.mass)
			collision_body.apply_impulse(strength_knockback, Vector2())

func destroy(missile) -> void:
	call_deferred("clip", create_circle_radious_polygon(missile.global_position, missile.damage))
	apply_explotion_impulse(missile.global_position, missile.damage*FORCE_MULTIPLIER_TO_POLYGONS)
