extends Node
## Ads service (autoload "Ads"): Google consent first, then AdMob.
##
## Rules this service guarantees:
## - Ads are only requested after the consent step (GDPR form where required).
## - A rewarded ad grants its reward only from the SDK's "user earned reward"
##   callback, never just because the ad closed.
## - Interstitials only appear between levels, never in the first levels, at most
##   one every few levels, spaced in time, and never right after a rewarded ad.
## - If anything fails (offline, no fill, no plugin on desktop) the game simply
##   carries on: every call has a "not shown" path.
##
## On desktop there is no ad SDK; `simulate` lets the test harness exercise the
## same code paths (rewards are granted instantly, interstitials are counted).

signal availability_changed

const REWARDED := ["rescue", "hint", "bonus"]
const RETRY_SECONDS := [10.0, 30.0, 60.0, 120.0]

var simulate := false            # test harness: pretend ads always load and play
var interstitials_shown := 0     # (tests)
var _platform := false           # running on a phone with the AdMob plugin
var _sdk_ready := false
var _rewarded := {}              # placement -> RewardedAd (loaded, unused)
var _loading := {}               # placement -> true while a request is in flight
var _retries := {}               # placement -> failed attempts in a row
var _interstitial: InterstitialAd
var _showing := false
var _last_fullscreen := -1000.0  # seconds since start of the last full-screen ad
var _wins_since_interstitial := 0
var _privacy_required := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_platform = OS.get_name() == "Android" and Engine.has_singleton("PoingGodotAdMob")
	if _platform:
		_start_consent()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# ---------------------------------------------------------------- consent

func _start_consent() -> void:
	var params := ConsentRequestParameters.new()
	UserMessagingPlatform.consent_information.update(params, _on_consent_info, _on_consent_info_failed)

func _on_consent_info() -> void:
	var info := UserMessagingPlatform.consent_information
	if info.get_is_consent_form_available() and info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
		UserMessagingPlatform.load_consent_form(
			func(form: ConsentForm): form.show(func(_e: FormError): _after_consent()),
			func(_e: FormError): _after_consent())
	else:
		_after_consent()

func _on_consent_info_failed(_e: FormError) -> void:
	# offline at launch: a consent decision from an earlier session still counts
	_after_consent()

func _after_consent() -> void:
	var info := UserMessagingPlatform.consent_information
	_privacy_required = info.get_privacy_options_requirement_status() == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
	var status := info.get_consent_status()
	if status == ConsentInformation.ConsentStatus.OBTAINED or status == ConsentInformation.ConsentStatus.NOT_REQUIRED:
		_init_sdk()

func _init_sdk() -> void:
	if _sdk_ready:
		return
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus):
		_sdk_ready = true
		for p in REWARDED:
			_load_rewarded(p)
		_load_interstitial()
	MobileAds.initialize(listener)

## Settings shows a "Privacy options" button only when Google says it's needed.
func privacy_options_required() -> bool:
	return _platform and _privacy_required

func show_privacy_options() -> void:
	if not _platform:
		return
	UserMessagingPlatform.show_privacy_options_form(func(_e: FormError):
		_after_consent())

# ---------------------------------------------------------------- rewarded

func _load_rewarded(placement: String) -> void:
	if not _sdk_ready or _loading.get(placement, false) or _rewarded.has(placement):
		return
	_loading[placement] = true
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd):
		_loading[placement] = false
		_retries[placement] = 0
		_rewarded[placement] = ad
		availability_changed.emit()
	cb.on_ad_failed_to_load = func(_err: LoadAdError):
		_loading[placement] = false
		_retry_later(func(): _load_rewarded(placement), placement)
	RewardedAdLoader.new().load(AdConfig.unit(placement), AdRequest.new(), cb)

func _retry_later(fn: Callable, key: String) -> void:
	var n: int = _retries.get(key, 0)
	_retries[key] = n + 1
	get_tree().create_timer(RETRY_SECONDS[min(n, RETRY_SECONDS.size() - 1)]).timeout.connect(fn)

## True when a rewarded ad for this placement can be shown right now.
func rewarded_ready(placement: String) -> bool:
	if simulate:
		return true
	return _platform and not _showing and _rewarded.has(placement)

## Shows a rewarded ad. `on_reward` runs only if the player earned the reward;
## `on_done(earned)` always runs once the ad is gone. Returns false when no ad
## could be shown (nothing is charged or granted then).
func show_rewarded(placement: String, on_reward: Callable, on_done: Callable = Callable()) -> bool:
	if simulate:
		_last_fullscreen = _now()
		on_reward.call()
		if on_done.is_valid():
			on_done.call(true)
		return true
	if not rewarded_ready(placement):
		return false
	var ad: RewardedAd = _rewarded[placement]
	_rewarded.erase(placement)
	var earned := [false]
	var finish := func():
		_end_fullscreen()
		ad.destroy()
		if on_done.is_valid():
			on_done.call(earned[0])
		_load_rewarded(placement)
		availability_changed.emit()
	var content := FullScreenContentCallback.new()
	content.on_ad_dismissed_full_screen_content = finish
	content.on_ad_failed_to_show_full_screen_content = func(_err: AdError): finish.call()
	ad.full_screen_content_callback = content
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem):
		if not earned[0]:
			earned[0] = true
			on_reward.call()
	_begin_fullscreen()
	ad.show(listener)
	return true

# ---------------------------------------------------------------- interstitial

func _load_interstitial() -> void:
	if not _sdk_ready or _loading.get("interstitial", false) or _interstitial != null:
		return
	_loading["interstitial"] = true
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd):
		_loading["interstitial"] = false
		_retries["interstitial"] = 0
		_interstitial = ad
	cb.on_ad_failed_to_load = func(_err: LoadAdError):
		_loading["interstitial"] = false
		_retry_later(_load_interstitial, "interstitial")
	InterstitialAdLoader.new().load(AdConfig.unit("interstitial"), AdRequest.new(), cb)

## Called after each completed level (the natural break). Shows an interstitial
## if the pacing rules allow it, then calls `on_done`. Always calls `on_done`.
func level_break(lifetime_wins: int, on_done: Callable) -> void:
	_wins_since_interstitial += 1
	var due := lifetime_wins > AdConfig.FIRST_INTERSTITIAL_AFTER_WINS \
		and _wins_since_interstitial >= AdConfig.INTERSTITIAL_EVERY_N_LEVELS \
		and _now() - _last_fullscreen >= AdConfig.MIN_SECONDS_BETWEEN_FULLSCREEN
	if not due:
		on_done.call()
		return
	if simulate:
		_wins_since_interstitial = 0
		_last_fullscreen = _now()
		interstitials_shown += 1
		on_done.call()
		return
	if not _platform or _showing or _interstitial == null:
		on_done.call()
		return
	var ad := _interstitial
	_interstitial = null
	_wins_since_interstitial = 0
	var finish := func():
		_end_fullscreen()
		ad.destroy()
		_load_interstitial()
		on_done.call()
	var content := FullScreenContentCallback.new()
	content.on_ad_dismissed_full_screen_content = finish
	content.on_ad_failed_to_show_full_screen_content = func(_err: AdError): finish.call()
	ad.full_screen_content_callback = content
	_begin_fullscreen()
	ad.show()

# ---------------------------------------------------------------- shared

func _begin_fullscreen() -> void:
	_showing = true
	AudioServer.set_bus_mute(0, true)

func _end_fullscreen() -> void:
	_showing = false
	_last_fullscreen = _now()
	AudioServer.set_bus_mute(0, false)
