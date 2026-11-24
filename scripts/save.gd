extends Node
## Persistent player data (cash, garage, upgrades, settings, daily reward, awards).

const PATH := "user://courier_rush.json"

signal changed

var data: Dictionary = {}


func _ready() -> void:
    load_data()
    apply_audio()


func _defaults() -> Dictionary:
    return {
        "cash": 150,
        "earned": 0,
        "deliveries": 0,
        "failed": 0,
        "streak": 0,
        "best_streak": 0,
        "owned": ["truck_yellow"],
        "truck": "truck_yellow",
        "up": {},
        "daily_date": "",
        "daily_day": 0,
        "claimed": [],
        "lang": "en",
        "sound": true,
        "vibration": true,
        "shadows": true,
        "tutorial_done": false,
        "free_cash_at": 0,
        "runs": 0,
    }


func load_data() -> void:
    data = _defaults()
    if FileAccess.file_exists(PATH):
        var f := FileAccess.open(PATH, FileAccess.READ)
        if f:
            var parsed = JSON.parse_string(f.get_as_text())
            if parsed is Dictionary:
                for k in parsed.keys():
                    data[k] = parsed[k]
    else:
        var sys_lang := OS.get_locale_language()
        data["lang"] = "tr" if sys_lang == "tr" else "en"


func save() -> void:
    var f := FileAccess.open(PATH, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(data))
    changed.emit()


func cash() -> int:
    return int(data["cash"])


func add_cash(amount: int) -> void:
    data["cash"] = cash() + amount
    if amount > 0:
        data["earned"] = int(data["earned"]) + amount
    save()


func spend(amount: int) -> bool:
    if cash() < amount:
        return false
    data["cash"] = cash() - amount
    save()
    return true


func level() -> int:
    return 1 + int(data["deliveries"]) / 4


func owns(id: String) -> bool:
    return (data["owned"] as Array).has(id)


func upgrade_level(vehicle_id: String, key: String) -> int:
    var ups: Dictionary = data["up"]
    if not ups.has(vehicle_id):
        return 0
    return int((ups[vehicle_id] as Dictionary).get(key, 0))


func set_upgrade_level(vehicle_id: String, key: String, lvl: int) -> void:
    var ups: Dictionary = data["up"]
    if not ups.has(vehicle_id):
        ups[vehicle_id] = {}
    (ups[vehicle_id] as Dictionary)[key] = lvl
    save()


func apply_audio() -> void:
    AudioServer.set_bus_mute(0, not bool(data["sound"]))
