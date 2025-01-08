![Screenshot](https://github.com/EGA-SUPREMO/Destructible-terrain-in-Godot/blob/main/destructible.gif?raw=true)

# Destructible-terrain-in-Godot
A scene to make distructible terrain in godot

This repo can be imported as a project. Part of this code is also used in https://github.com/EGA-SUPREMO/Course-Notes-Godot

This code is mostly the same as from this [tutorial](https://www.youtube.com/watch?v=q9SV4o7ZZNk)[1], adjusted to the needs to my game(Terrain must have physics like affected by gravity, but only those that are separated from the initial polygon).

The terrain is generated based on an image

[1] the tutorial was made for Godot 3, in the current version(4.3) there is an unsolved issue with the way godot handles shaders, so the part where it updates the image through a SubViewport doesn't work, instead this project uses `Polygon2D` for that, [the repo link](https://github.com/MitchMakesThings/Godot-Things/tree/main/Terrain-Destruction-Example)

It starts at `create_collisions()`, it creates the polygons from an image(the one from `Background` node). every pixel that isn't transparent will turn solid, it uses `create_from_image_alpha` and `opaque_to_polygons` for that, all of them are static bodies, if you want to change the way polygons are generated this is the place, as long as you follow the hierarchy of:
* StaticBody2D or RigidBody2D
    * CollisionPolygon2D
    * Polygon2D

The project consist of the following nodes:

* `Background`: the image the terrain is based on
* `IslandHolder`: A 2D node that contains all destructible bodies created from `create_collisions()`, after that function is executed it should contain at least 1 `StaticBody2D` with its `CollisionPolygon2D` and `Polygon2D` to show its shape, after a polygon is divided, it will create another body, it'll be a `RigidBody2D` with a mass equal to its area

the function ~~with its typo xd~~ `create_circle_radious_polygon()` is used to calculate the shape of polygon to be destroyed, the first argument is for the position of circle and the second is for the size, it returns a `PackedVector2Array`, which is required for `clip()`

the function `clip()` is used when we want to remove terrain, it requires a PackedVector2Array. If you don't want the terrain to be affected by physics, change the line
```gdscript
               var body := RigidBody2D.new()
```
with:
```gdscript
               var body := StaticBody2D.new()
```
and make sure you remove `body.mass = abs(calculate_area(collider.polygon))`, because StaticBody doesnt have a mass attribute

* `_process()` can be deleted, its mainly for demonstration purposes

