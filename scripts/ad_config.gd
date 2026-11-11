class_name AdConfig
extends RefCounted
## Everything you need to change to go live with ads is in this file and in
## Project Settings > General > Admob > Android > App Id.
##
## While USE_TEST_ADS is true the game shows Google's official test ads, which
## are always safe to tap. Set your real ad unit IDs below, set the real App ID in
## Project Settings, then flip USE_TEST_ADS to false for the store build.
## Never tap your own live ads: AdMob may suspend the account.

const USE_TEST_ADS := true

## Your ad unit IDs from AdMob (Apps > Sort the Shipment > Ad units).
const LIVE_UNITS := {
	"rescue": "",          # Rewarded: +1 parking spot when stuck
	"hint": "",            # Rewarded: an extra hint
	"bonus": "",           # Rewarded: bonus coins on the win screen
	"interstitial": "",    # Interstitial: between levels
}

## Google's public test units for Android (from the AdMob documentation).
const TEST_UNITS := {
	"rescue": "ca-app-pub-3940256099942544/5224354917",
	"hint": "ca-app-pub-3940256099942544/5224354917",
	"bonus": "ca-app-pub-3940256099942544/5224354917",
	"interstitial": "ca-app-pub-3940256099942544/1033173712",
}

## Interstitial pacing (conservative starting values, tune with real data).
const FIRST_INTERSTITIAL_AFTER_WINS := 5      # no forced ads while learning
const INTERSTITIAL_EVERY_N_LEVELS := 3
const MIN_SECONDS_BETWEEN_FULLSCREEN := 120.0

static func unit(placement: String) -> String:
	var live: String = LIVE_UNITS.get(placement, "")
	if USE_TEST_ADS or live == "":
		return TEST_UNITS.get(placement, "")
	return live
