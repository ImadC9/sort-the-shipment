extends Node
## Persistent player progress: levels, stars, coins, harbour projects,
## settings, and the level in progress (so a closed app resumes mid-puzzle).

const PATH := "user://save.cfg"

## Harbour projects: purely cosmetic upgrades that visibly change the port.
## [id, name, cost, description]
const PROJECTS := [
	["lighthouse", "Restore the Lighthouse", 120, "Fresh paint and a working lamp"],
	["bunting", "Festival Bunting", 200, "Colourful flags along the warehouses"],
	["cafe", "Quay Café", 300, "Umbrellas, tables and a little kiosk"],
	["planters", "Flower Promenade", 400, "Flower boxes and benches by the yard"],
	["fireworks", "Victory Fireworks", 520, "Fireworks over the port when you win"],
	["fountain", "Harbour Fountain", 650, "A splashing fountain by the palms"],
	["clocktower", "Clock Tower", 800, "A landmark for the finest port"],
	["cranes", "Golden Cranes", 1000, "Gold paint for the quay cranes"],
	# second phase: the harbour district grows
	["solar", "Solar Roofs", 900, "Solar panels on the warehouse roofs"],
	["lamps", "Quay Lamps", 1000, "Glowing lamp posts along the quay"],
	["flags", "Flag Masts", 1100, "Tall masts with waving flags"],
	["pool", "Rooftop Pool", 1300, "A pool with sun loungers on the roof"],
	["gardens", "Rooftop Gardens", 1400, "Trees and planters on the roofs"],
	["icecream", "Ice Cream Stand", 1500, "A striped stand beside the yard"],
	["fairylights", "Fairy Lights", 1600, "Warm bulbs along the roof edges"],
	["monument", "Anchor Monument", 1800, "A bronze anchor for the port's heroes"],
	["liveries", "Ship Liveries", 2200, "Gold stripes and pennants on every ship"],
]

const RANKS := [
	[0, "Deckhand"], [6, "Lasher"], [15, "Crane Operator"], [27, "Stevedore Boss"],
	[42, "Berth Planner"], [60, "Terminal Captain"], [85, "Port Captain"], [115, "Harbor Master"],
	[150, "Fleet Admiral"], [190, "Shipping Magnate"], [235, "Ocean Tycoon"], [280, "Legend of the Seas"],
]

var unlocked := 1
var stars := {}          # level id (String) -> best stars
var coins := 150
var sound := true
var music := true
var vibrate := true
var reduce_motion := false
var seen := {}           # one-time intros already shown
var projects: Array = [] # built project ids
var resume := {}         # level in progress (empty = none)
var campaign_done := false
var chains := 0          # lifetime dispatch chains (for fun stats)

func _ready() -> void:
	load_data()

func load_data() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	unlocked = cf.get_value("p", "unlocked", 1)
	stars = cf.get_value("p", "stars", {})
	coins = cf.get_value("p", "coins", 150)
	seen = cf.get_value("p", "seen", {})
	projects = cf.get_value("p", "projects", [])
	resume = cf.get_value("p", "resume", {})
	campaign_done = cf.get_value("p", "campaign_done", false)
	chains = cf.get_value("p", "chains", 0)
	sound = cf.get_value("s", "sound", true)
	music = cf.get_value("s", "music", true)
	vibrate = cf.get_value("s", "vibrate", true)
	reduce_motion = cf.get_value("s", "reduce_motion", false)
	# older saves kept intro flags inside the star table
	for k in stars.keys():
		if str(k).begins_with("intro_"):
			seen[k] = true
			stars.erase(k)

func save_data() -> void:
	var cf := ConfigFile.new()
	cf.set_value("p", "unlocked", unlocked)
	cf.set_value("p", "stars", stars)
	cf.set_value("p", "coins", coins)
	cf.set_value("p", "seen", seen)
	cf.set_value("p", "projects", projects)
	cf.set_value("p", "resume", resume)
	cf.set_value("p", "campaign_done", campaign_done)
	cf.set_value("p", "chains", chains)
	cf.set_value("s", "sound", sound)
	cf.set_value("s", "music", music)
	cf.set_value("s", "vibrate", vibrate)
	cf.set_value("s", "reduce_motion", reduce_motion)
	cf.save(PATH)

func get_stars(level_id: int) -> int:
	return int(stars.get(str(level_id), 0))

func record_win(level_id: int, s: int, total_levels: int) -> void:
	if s > get_stars(level_id):
		stars[str(level_id)] = s
	unlocked = clampi(max(unlocked, level_id + 1), 1, total_levels)
	resume = {}
	save_data()

func total_stars() -> int:
	var n := 0
	for k in stars:
		n += int(stars[k])
	return n

## [rank name, stars at this rank, stars for next rank (-1 at max), index]
func rank_info(total: int = -1) -> Array:
	if total < 0:
		total = total_stars()
	var idx := 0
	for i in RANKS.size():
		if total >= RANKS[i][0]:
			idx = i
	var next: int = RANKS[idx + 1][0] if idx + 1 < RANKS.size() else -1
	return [RANKS[idx][1], RANKS[idx][0], next, idx]

func add_coins(n: int) -> void:
	coins = max(0, coins + n)
	save_data()

func spend(n: int) -> bool:
	if coins < n:
		return false
	coins -= n
	save_data()
	return true

func has_project(id: String) -> bool:
	return id in projects

## The next project not built yet, or [] when the harbour is complete.
func next_project() -> Array:
	for p in PROJECTS:
		if not has_project(p[0]):
			return p
	return []

func build_project(id: String) -> bool:
	for p in PROJECTS:
		if p[0] == id and not has_project(id):
			if not spend(p[2]):
				return false
			projects.append(id)
			save_data()
			return true
	return false

func buzz(ms: int = 18) -> void:
	if vibrate and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
