extends Node
## Ads: AdMob on Android through the Poing AdMob plugin; a harmless stub everywhere else.
## Interstitials are rate limited; rewarded ads always report whether the reward was earned.

const INTERSTITIAL_ID := "ca-app-pub-4674211063760769/7938790950"
const REWARDED_ID := "ca-app-pub-4674211063760769/1684373795"
const MIN_GAP_SECONDS := 120.0
const SHOW_TIMEOUT := 120.0

var provider := "stub"
var _last_interstitial := -1000.0
var _busy := false
var _ready_sdk := false
var _initializing := false
var _iv: InterstitialAd = null
var _rv: RewardedAd = null
var _iv_loading := false
var _rv_loading := false
var _token := 0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    if OS.has_feature("android") and Engine.has_singleton("PoingGodotAdMob"):
        provider = "admob"
        _init_sdk()


func rewarded_ready() -> bool:
    if provider == "admob":
        return _rv != null
    return true


func is_busy() -> bool:
    return _busy


## Shows an interstitial if the cool-down allows it. done() is always called.
func show_interstitial(done: Callable) -> void:
    var now := Time.get_ticks_msec() / 1000.0
    if _busy or now - _last_interstitial < MIN_GAP_SECONDS:
        done.call()
        return
    if provider == "admob":
        _last_interstitial = now
        _show_interstitial(done)
    else:
        done.call()


## Shows a rewarded ad. done(earned: bool) is always called.
func show_rewarded(done: Callable) -> void:
    if _busy:
        done.call(false)
        return
    if provider == "admob":
        _show_rewarded(done)
    else:
        # Desktop / stub: grant the reward so the flow can be tested.
        done.call(true)


# --- AdMob -----------------------------------------------------------------

func _init_sdk() -> void:
    if _ready_sdk or _initializing:
        return
    _initializing = true
    var params := ConsentRequestParameters.new()
    params.tag_for_under_age_of_consent = false
    UserMessagingPlatform.consent_information.update(params, _on_consent_updated, _on_consent_error)


func _on_consent_updated() -> void:
    var info = UserMessagingPlatform.consent_information
    if info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED and info.get_is_consent_form_available():
        UserMessagingPlatform.load_consent_form(_on_form_loaded, _on_consent_error)
    else:
        _start_sdk()


func _on_form_loaded(form: ConsentForm) -> void:
    form.show(_on_form_closed)


func _on_form_closed(_err: FormError) -> void:
    _start_sdk()


func _on_consent_error(_err: FormError) -> void:
    _start_sdk()


func _start_sdk() -> void:
    if _ready_sdk:
        return
    _ready_sdk = true
    MobileAds.initialize()
    _load_interstitial()
    _load_rewarded()


func _retry_interstitial() -> void:
    _load_interstitial()


func _retry_rewarded() -> void:
    _load_rewarded()


func _on_iv_loaded(ad: InterstitialAd) -> void:
    _iv_loading = false
    _iv = ad


func _on_iv_failed(_err: LoadAdError) -> void:
    _iv_loading = false
    get_tree().create_timer(45.0, true, false, true).timeout.connect(_retry_interstitial)


func _on_rv_loaded(ad: RewardedAd) -> void:
    _rv_loading = false
    _rv = ad


func _on_rv_failed(_err: LoadAdError) -> void:
    _rv_loading = false
    get_tree().create_timer(45.0, true, false, true).timeout.connect(_retry_rewarded)


func _load_interstitial() -> void:
    if _iv != null or _iv_loading or not _ready_sdk:
        return
    _iv_loading = true
    var cb := InterstitialAdLoadCallback.new()
    cb.on_ad_loaded = _on_iv_loaded
    cb.on_ad_failed_to_load = _on_iv_failed
    InterstitialAdLoader.new().load(INTERSTITIAL_ID, AdRequest.new(), cb)


func _load_rewarded() -> void:
    if _rv != null or _rv_loading or not _ready_sdk:
        return
    _rv_loading = true
    var cb := RewardedAdLoadCallback.new()
    cb.on_ad_loaded = _on_rv_loaded
    cb.on_ad_failed_to_load = _on_rv_failed
    RewardedAdLoader.new().load(REWARDED_ID, AdRequest.new(), cb)


func _finish_ad(was_paused: bool) -> void:
    _busy = false
    get_tree().paused = was_paused
    AudioServer.set_bus_mute(0, not bool(Save.data["sound"]))


func _show_interstitial(done: Callable) -> void:
    var ad: InterstitialAd = _iv
    if ad == null:
        _load_interstitial()
        done.call()
        return
    _iv = null
    _busy = true
    var token := Time.get_ticks_msec()
    _token = token
    var was_paused := get_tree().paused
    var finished := [false]
    var end := func():
        if finished[0]:
            return
        finished[0] = true
        ad.destroy()
        _finish_ad(was_paused)
        _load_interstitial()
        done.call()

    var content := FullScreenContentCallback.new()
    content.on_ad_showed_full_screen_content = _on_ad_shown
    content.on_ad_dismissed_full_screen_content = func(): end.call()
    content.on_ad_failed_to_show_full_screen_content = func(_err: AdError): end.call()
    ad.full_screen_content_callback = content
    var on_timeout := func(): if _token == token: end.call()
    get_tree().create_timer(SHOW_TIMEOUT, true, false, true).timeout.connect(on_timeout)
    ad.show()


func _show_rewarded(done: Callable) -> void:
    var ad: RewardedAd = _rv
    if ad == null:
        _load_rewarded()
        done.call(false)
        return
    _rv = null
    _busy = true
    var token := Time.get_ticks_msec()
    _token = token
    var was_paused := get_tree().paused
    var earned := [false]
    var finished := [false]
    var end := func():
        if finished[0]:
            return
        finished[0] = true
        ad.destroy()
        _finish_ad(was_paused)
        _load_rewarded()
        done.call(earned[0])

    var content := FullScreenContentCallback.new()
    content.on_ad_showed_full_screen_content = _on_ad_shown
    content.on_ad_dismissed_full_screen_content = func(): end.call()
    content.on_ad_failed_to_show_full_screen_content = func(_err: AdError): end.call()
    ad.full_screen_content_callback = content
    var on_timeout := func(): if _token == token: end.call()
    get_tree().create_timer(SHOW_TIMEOUT, true, false, true).timeout.connect(on_timeout)
    var listener := OnUserEarnedRewardListener.new()
    listener.on_user_earned_reward = func(_item: RewardedItem): earned[0] = true
    ad.show(listener)


func _on_ad_shown() -> void:
    get_tree().paused = true
    AudioServer.set_bus_mute(0, true)
