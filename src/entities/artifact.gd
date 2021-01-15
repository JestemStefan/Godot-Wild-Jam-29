extends Area

enum Type {
	FIRST,
	SECOND,
	THIRD
}

export(int, "First", "Second", "Third") var type := Type.FIRST


func _ready() -> void:
	var gem_mat: SpatialMaterial = $Mesh.get_surface_material(1).duplicate()
	$Mesh.set_surface_material(1, gem_mat)
	match type:
		Type.FIRST:
			gem_mat.albedo_color = Color(1, 0.2, 0.1)
		Type.SECOND:
			gem_mat.albedo_color = Color(0.2, 1.0, 0.1)
		Type.FIRST:
			gem_mat.albedo_color = Color(0.1, 0.2, 1.0)


func _process(delta: float) -> void:
	rotation.y += delta * 0.5