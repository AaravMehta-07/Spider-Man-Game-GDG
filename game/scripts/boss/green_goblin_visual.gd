class_name GreenGoblinVisual
extends Node3D

@onready var motion_pivot: Node3D = $MotionPivot
@onready var model_pivot: Node3D = $MotionPivot/ModelPivot
@onready var hit_burst: GPUParticles3D = $MotionPivot/HitBurst
@onready var left_thruster: OmniLight3D = $MotionPivot/LeftThruster
@onready var right_thruster: OmniLight3D = $MotionPivot/RightThruster

var _time := 0.0
var _hit_time := 0.0
var _hit_heavy := false
var _action_time := 0.0
var _action: StringName = &"idle"
var _materials: Array[Dictionary] = []


func _ready() -> void:
    _cache_model_materials(model_pivot)


func update_visual(delta: float, health: float, tension: float, mission_state: StringName) -> void:
    _time += delta
    _hit_time = maxf(0.0, _hit_time - delta)
    _action_time = maxf(0.0, _action_time - delta)
    var hit_weight := ease(clampf(_hit_time / (0.5 if _hit_heavy else 0.32), 0.0, 1.0), -2.0)
    var action_weight := sin(clampf(_action_time / 0.72, 0.0, 1.0) * PI)
    var bank := sin(_time * 1.35) * 0.055
    var lift := sin(_time * 2.4) * 0.16
    var action_offset := Vector3.ZERO
    var action_rotation := Vector3.ZERO
    match _action:
        &"right_slash":
            action_offset = Vector3(-1.1, 0.1, 1.2) * action_weight
            action_rotation = Vector3(-0.08, -0.18, -0.28) * action_weight
        &"overhead":
            action_offset = Vector3(0.0, 1.0, 0.9) * action_weight
            action_rotation = Vector3(-0.24, 0.0, 0.0) * action_weight
        &"energy", &"counter":
            action_offset = Vector3(0.0, 0.2, 1.3) * action_weight
            action_rotation = Vector3(-0.16, 0.0, 0.0) * action_weight
        &"debris":
            action_offset = Vector3(1.0, 0.5, 0.7) * action_weight
            action_rotation = Vector3(0.0, 0.32, 0.22) * action_weight
        &"ground_wave":
            action_offset = Vector3(0.0, -1.0, 1.2) * action_weight
            action_rotation = Vector3(0.26, 0.0, 0.0) * action_weight
        &"contained":
            action_rotation = Vector3(0.0, 0.0, sin(_time * 9.0) * 0.08) * (0.3 + tension)
    var hit_offset := Vector3(0.45 if _hit_heavy else 0.24, 0.32, -1.15 if _hit_heavy else -0.72) * hit_weight
    var hit_rotation := Vector3(0.16, -0.12, 0.24 if _hit_heavy else 0.14) * hit_weight
    motion_pivot.position = Vector3(0.0, lift, 0.0) + action_offset + hit_offset
    motion_pivot.rotation = Vector3(0.0, sin(_time * 0.72) * 0.06, bank) + action_rotation + hit_rotation
    model_pivot.scale = Vector3.ONE * (3.25 - tension * 0.38)
    var thruster_energy := 4.2 + sin(_time * 12.0) * 0.8 + (1.8 if _action_time > 0.0 else 0.0)
    left_thruster.light_energy = thruster_energy
    right_thruster.light_energy = thruster_energy
    _set_hit_flash(hit_weight)
    if mission_state == &"FINISHER" and _action != &"contained":
        _action = &"contained"


func play_action(kind: StringName) -> void:
    _action = kind
    _action_time = 0.72


func show_hit(heavy := false) -> void:
    _hit_heavy = heavy
    _hit_time = 0.5 if heavy else 0.32
    hit_burst.amount = 46 if heavy else 28
    hit_burst.restart()


func _cache_model_materials(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        for surface in mesh_instance.get_surface_override_material_count():
            var source := mesh_instance.get_active_material(surface)
            if source is StandardMaterial3D:
                var material := source.duplicate() as StandardMaterial3D
                mesh_instance.set_surface_override_material(surface, material)
                _materials.append({
                    "material": material,
                    "enabled": material.emission_enabled,
                    "color": material.emission,
                    "energy": material.emission_energy_multiplier,
                })
    for child in node.get_children():
        _cache_model_materials(child)


func _set_hit_flash(weight: float) -> void:
    for entry in _materials:
        var material: StandardMaterial3D = entry["material"]
        if weight > 0.01:
            material.emission_enabled = true
            material.emission = Color(0.45, 1.0, 0.28)
            material.emission_energy_multiplier = 1.0 + weight * 5.5
        else:
            material.emission_enabled = bool(entry["enabled"])
            material.emission = entry["color"]
            material.emission_energy_multiplier = float(entry["energy"])
