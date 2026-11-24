extends Node
## Tiny two-language string table. Tr.t("key") or Tr.t("key", [args]).

const EN := {
    "play": "PLAY", "garage": "GARAGE", "daily": "DAILY", "awards": "AWARDS", "settings": "SETTINGS",
    "back": "BACK", "level": "Level %d", "free_cash": "FREE CASH (AD)", "free_cash_wait": "Free cash in %d min",
    "pickup": "Pick up: %s", "deliver": "Deliver: %s", "time_left": "TIME", "integrity": "CARGO",
    "delivered": "DELIVERED!", "failed_time": "TOO LATE", "failed_damage": "CARGO DESTROYED",
    "reward": "Delivery fee", "time_bonus": "Time bonus", "damage_penalty": "Damage", "streak_bonus": "Streak bonus",
    "total": "TOTAL", "double": "DOUBLE (AD)", "next_job": "NEXT JOB", "to_menu": "MENU",
    "pause": "PAUSED", "resume": "RESUME", "quit": "QUIT RUN", "buy": "BUY", "owned": "OWNED",
    "equip": "EQUIP", "equipped": "IN USE", "upgrade": "UPGRADE", "maxed": "MAX",
    "engine": "Engine", "tires": "Tires", "armor": "Armor", "power": "Power", "grip": "Grip", "tough": "Toughness",
    "daily_title": "DAILY REWARD", "daily_streak": "Day %d of 7", "claim": "CLAIM", "claimed": "CLAIMED",
    "come_back": "Come back tomorrow!", "language": "Language", "sound": "Sound", "vibration": "Vibration",
    "shadows": "Shadows", "on": "ON", "off": "OFF", "credits": "Built with Kenney's Starter Kit Racing (MIT, CC0).",
    "cargo_parcel": "Parcel", "cargo_pizza": "Hot pizza", "cargo_crystal": "Crystal", "cargo_crate": "Heavy crate",
    "veh_truck_yellow": "Sunny Hauler", "veh_truck_green": "Green Mule", "veh_truck_red": "Red Runner",
    "veh_truck_purple": "Violet Viper", "veh_moto": "Courier Bike",
    "tut1": "Drive to the glowing pickup ring.", "tut2": "Deliver before the timer ends. Crashes damage the cargo.",
    "tut3": "Earn cash, upgrade your truck, unlock new vehicles.", "got_it": "GOT IT",
    "need_cash": "Not enough cash", "loading_ad": "Loading ad...", "ad_unavailable": "No ad available right now",
    "aw_deliver1": "First delivery", "aw_deliver10": "Ten deliveries", "aw_deliver50": "Fifty deliveries",
    "aw_deliver100": "Hundred deliveries", "aw_earn1000": "Earn $1,000 in total", "aw_earn10000": "Earn $10,000 in total",
    "aw_streak5": "5 deliveries in a row", "aw_trucks3": "Own 3 vehicles", "reward_amount": "+$%d",
    "stat_deliveries": "Deliveries: %d", "stat_best": "Best streak: %d",
}

const TR := {
    "play": "OYNA", "garage": "GARAJ", "daily": "GÜNLÜK", "awards": "ÖDÜLLER", "settings": "AYARLAR",
    "back": "GERİ", "level": "Seviye %d", "free_cash": "BEDAVA PARA (REKLAM)", "free_cash_wait": "Bedava para %d dk sonra",
    "pickup": "Paketi al: %s", "deliver": "Teslim et: %s", "time_left": "SÜRE", "integrity": "KARGO",
    "delivered": "TESLİM EDİLDİ!", "failed_time": "ÇOK GEÇ KALDIN", "failed_damage": "KARGO PARÇALANDI",
    "reward": "Teslimat ücreti", "time_bonus": "Süre bonusu", "damage_penalty": "Hasar", "streak_bonus": "Seri bonusu",
    "total": "TOPLAM", "double": "İKİ KAT (REKLAM)", "next_job": "SONRAKİ İŞ", "to_menu": "MENÜ",
    "pause": "DURAKLATILDI", "resume": "DEVAM", "quit": "ÇIK", "buy": "SATIN AL", "owned": "SENDE",
    "equip": "KULLAN", "equipped": "KULLANIMDA", "upgrade": "GELİŞTİR", "maxed": "MAKS",
    "engine": "Motor", "tires": "Lastik", "armor": "Zırh", "power": "Güç", "grip": "Yol tutuş", "tough": "Dayanıklılık",
    "daily_title": "GÜNLÜK ÖDÜL", "daily_streak": "7 günün %d. günü", "claim": "AL", "claimed": "ALINDI",
    "come_back": "Yarın tekrar gel!", "language": "Dil", "sound": "Ses", "vibration": "Titreşim",
    "shadows": "Gölgeler", "on": "AÇIK", "off": "KAPALI", "credits": "Kenney Starter Kit Racing ile yapıldı (MIT, CC0).",
    "cargo_parcel": "Paket", "cargo_pizza": "Sıcak pizza", "cargo_crystal": "Kristal", "cargo_crate": "Ağır sandık",
    "veh_truck_yellow": "Güneşli Taşıyıcı", "veh_truck_green": "Yeşil Katır", "veh_truck_red": "Kırmızı Koşucu",
    "veh_truck_purple": "Mor Engerek", "veh_moto": "Kurye Motoru",
    "tut1": "Parlayan alma halkasına sür.", "tut2": "Süre bitmeden teslim et. Çarpmalar kargoya zarar verir.",
    "tut3": "Para kazan, aracını geliştir, yeni araçların kilidini aç.", "got_it": "ANLADIM",
    "need_cash": "Yeterli para yok", "loading_ad": "Reklam yükleniyor...", "ad_unavailable": "Şu an reklam yok",
    "aw_deliver1": "İlk teslimat", "aw_deliver10": "On teslimat", "aw_deliver50": "Elli teslimat",
    "aw_deliver100": "Yüz teslimat", "aw_earn1000": "Toplam 1.000$ kazan", "aw_earn10000": "Toplam 10.000$ kazan",
    "aw_streak5": "Üst üste 5 teslimat", "aw_trucks3": "3 araç sahibi ol", "reward_amount": "+$%d",
    "stat_deliveries": "Teslimat: %d", "stat_best": "En iyi seri: %d",
}


func t(key: String, args: Array = []) -> String:
    var table: Dictionary = TR if Save.data.get("lang", "en") == "tr" else EN
    var s: String = table.get(key, EN.get(key, key))
    if args.size() > 0:
        return s % args
    return s
