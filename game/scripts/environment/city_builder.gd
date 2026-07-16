class_name CityBuilder
extends Node3D

var speed := 22.0
var mission_state: StringName = &"ATTRACT"
var lateral := 0.0
var _chunks: Array[MeshInstance3D] = []
var _props: Array[MeshInstance3D] = []
var _boss: MeshInstance3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
    _rng.seed = 7331
    _build_city()
    _build_boss()


func _process(delta: float) -> void:
    var active := mission_state in [&"CHASE", &"BOSS_INTRO", &"BOSS_COMBAT", &"FINISHER"]
    var travel := speed * delta if active else 3.0 * delta
    for chunk in _chunks:
        chunk.position.z += travel
        if chunk.position.z > 24.0:
            chunk.position.z -= 180.0
            _randomize_building(chunk)
    for prop in _props:
        prop.position.z += travel * 1.25
        prop.rotation.z += delta * 0.7
        if prop.position.z > 12.0:
            prop.position.z -= 150.0
            prop.position.x = _rng.randf_range(-6.5, 6.5)
    _boss.visible = mission_state in [&"BOSS_INTRO", &"BOSS_COMBAT", &"FINISHER"]
    if _boss.visible:
        _boss.position = Vector3(sin(Time.get_ticks_msec() * 0.0017) * 2.2, 6.2, -22.0)
        _boss.rotation.y += delta * 1.3
        var material := _boss.material_override as StandardMaterial3D
        material.emission_energy_multiplier = 2.5 + sin(Time.get_ticks_msec() * 0.006) * 1.4


func set_mission_state(value: StringName) -> void:
    mission_state = value


func _build_city() -> void:
    var road := _box(Vector3(16, 0.35, 190), Color(0.018, 0.025, 0.055), Vector3(0, -0.2, -70))
    _chunks.append(road)
    for side in [-1, 1]:
        for index in range(18):
            var width := _rng.randf_range(7.0, 13.0)
            var height := _rng.randf_range(12.0, 36.0)
            var depth := _rng.randf_range(7.0, 12.0)
            var x: float = float(side) * _rng.randf_range(10.5, 16.0)
            var z := 15.0 - index * 10.0 + _rng.randf_range(-2.0, 2.0)
            var color := Color(0.025, 0.04 + index * 0.001, 0.09 + _rng.randf_range(0.0, 0.05))
            var building := _box(Vector3(width, height, depth), color, Vector3(x, height * 0.5 - 0.1, z))
            _chunks.append(building)
            var neon_color := Color(1.0, 0.02, 0.13) if index % 3 == 0 else Color(0.02, 0.7, 1.0)
            var strip := _box(Vector3(0.18, height * 0.65, depth * 0.55), neon_color, Vector3(x - side * width * 0.51, height * 0.55, z))
            var neon := strip.material_override as StandardMaterial3D
            neon.emission_enabled = true
            neon.emission = neon_color
            neon.emission_energy_multiplier = 4.0
            _chunks.append(strip)
    for index in range(12):
        var prop := _box(Vector3(1.2, 1.2, 2.4), Color(0.12, 0.17, 0.26), Vector3(_rng.randf_range(-6.0, 6.0), 2.0, -index * 13.0))
        _props.append(prop)


func _build_boss() -> void:
    _boss = MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 3.2
    mesh.height = 7.5
    _boss.mesh = mesh
    var material := StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(0.03, 0.04, 0.08, 0.42)
    material.metallic = 0.75
    material.roughness = 0.18
    material.emission_enabled = true
    material.emission = Color(0.65, 0.02, 0.16)
    material.emission_energy_multiplier = 3.0
    _boss.material_override = material
    _boss.visible = false
    add_child(_boss)


func _box(size: Vector3, color: Color, position_: Vector3) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.35
    material.roughness = 0.55
    instance.material_override = material
    instance.position = position_
    add_child(instance)
    return instance


func _randomize_building(building: MeshInstance3D) -> void:
    if absf(building.position.x) < 9.0:
        return
    building.position.x = signf(building.position.x) * _rng.randf_range(10.5, 16.0)