class_name Catalog
extends RefCounted
## Static game data: vehicles, cargo types, upgrade curves.

const VEHICLES := [
    {"id": "truck_yellow", "name": "veh_truck_yellow", "price": 0, "power": 1.0, "grip": 1.0, "armor": 1.0,
        "scene": "res://scenes/vehicle.tscn", "model": "res://models/vehicle-truck-yellow.glb"},
    {"id": "truck_green", "name": "veh_truck_green", "price": 1500, "power": 1.1, "grip": 1.05, "armor": 1.1,
        "scene": "res://scenes/vehicle.tscn", "model": "res://models/vehicle-truck-green.glb"},
    {"id": "truck_red", "name": "veh_truck_red", "price": 4000, "power": 1.2, "grip": 1.1, "armor": 1.15,
        "scene": "res://scenes/vehicle.tscn", "model": "res://models/vehicle-truck-red.glb"},
    {"id": "truck_purple", "name": "veh_truck_purple", "price": 9000, "power": 1.32, "grip": 1.15, "armor": 1.2,
        "scene": "res://scenes/vehicle.tscn", "model": "res://models/vehicle-truck-purple.glb"},
    {"id": "moto", "name": "veh_moto", "price": 15000, "power": 1.5, "grip": 1.3, "armor": 0.65,
        "scene": "res://scenes/vehicle-motorcycle.tscn", "model": "res://models/vehicle-motorcycle.glb"},
]

const CARGOS := {
    "parcel": {"name": "cargo_parcel", "reward": 1.0, "time": 1.0, "fragile": 1.0, "color": Color(0.95, 0.75, 0.3)},
    "pizza": {"name": "cargo_pizza", "reward": 1.3, "time": 0.72, "fragile": 0.6, "color": Color(1.0, 0.45, 0.3)},
    "crystal": {"name": "cargo_crystal", "reward": 1.9, "time": 1.0, "fragile": 2.0, "color": Color(0.4, 0.85, 1.0)},
    "crate": {"name": "cargo_crate", "reward": 1.0, "time": 1.35, "fragile": 0.4, "color": Color(0.7, 0.55, 0.35)},
}

const UPGRADE_KEYS := ["engine", "tires", "armor"]
const MAX_UPGRADE := 5


static func vehicle(id: String) -> Dictionary:
    for v in VEHICLES:
        if v["id"] == id:
            return v
    return VEHICLES[0]


static func upgrade_cost(level: int) -> int:
    return int(250.0 * pow(float(level + 1), 1.7))


## Final tuning of a vehicle after the player's upgrades.
static func tuning(id: String) -> Dictionary:
    var v := vehicle(id)
    var eng := Save.upgrade_level(id, "engine")
    var tir := Save.upgrade_level(id, "tires")
    var arm := Save.upgrade_level(id, "armor")
    return {
        "power": float(v["power"]) * (1.0 + 0.06 * eng),
        "grip": float(v["grip"]) * (1.0 + 0.05 * tir),
        "armor": float(v["armor"]) * (1.0 + 0.12 * arm),
    }


static func random_cargo(level: int) -> String:
    var pool: Array = ["parcel", "parcel", "crate"]
    if level >= 2:
        pool.append("pizza")
    if level >= 4:
        pool.append("crystal")
    return pool[randi() % pool.size()]
