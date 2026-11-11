class_name GameModel
extends RefCounted
## Pure game logic for Sort the Shipment. No visuals here.
##
## Containers sit in yard stacks. Tapping a stack moves its top container:
##  - to a docked ship of the same colour with a free slot, otherwise
##  - to a free buffer slot ("parking"), otherwise the tap is refused.
## A full ship sails away and the next ship in the queue docks; any parked
## containers of the new ship's colour hop aboard automatically. When that
## fills the new ship too, it sails at once: a dispatch chain.
## Hidden containers reveal their colour when they reach the top.
## Locked containers can't be picked until N ships have sailed.
##
## Level stack codes: colour = code & 15, hidden = bit 4, gold = bit 5, lock = code >> 8.

const C_MASK := 15
const HIDDEN_BIT := 16
const GOLD_BIT := 32

var containers := {}        # id -> {"c": colour, "h": hidden, "g": gold, "l": lock threshold (0 = free)}
var stacks := []            # Array[Array[int ids]] bottom -> top
var buffer := []            # Array[int] id or -1
var berth_ship := []        # Array[int] ship uid or -1
var ship_color := {}        # uid -> colour
var ship_slots := {}        # uid -> Array[int ids]
var queue := []             # ship colours, in order
var next_q := 0
var sailed := 0
var cap := 3
var peak := 0
var moves := 0
var combo := 0
var _next_ship_uid := 1
var finished := false
# objective tracking
var best_chain := 0         # most ships sent off by a single tap

func setup(level: Dictionary) -> void:
	containers.clear()
	stacks.clear()
	ship_color.clear()
	ship_slots.clear()
	finished = false
	cap = int(level.get("cap", 3))
	queue = level["ships"].duplicate()
	next_q = 0
	sailed = 0
	peak = 0
	moves = 0
	combo = 0
	best_chain = 0
	_next_ship_uid = 1
	var nid := 1
	for st in level["stacks"]:
		var col := []
		for code in st:
			code = int(code)
			var g: bool = (code & GOLD_BIT) != 0
			containers[nid] = {"c": code & C_MASK, "h": (code & HIDDEN_BIT) != 0, "g": g, "l": code >> 8}
			col.append(nid)
			nid += 1
		stacks.append(col)
	# the top container of every stack is always visible
	for col in stacks:
		if col.size() > 0:
			containers[col.back()]["h"] = false
	buffer.clear()
	for i in int(level.get("buffer", 5)):
		buffer.append(-1)
	berth_ship.clear()
	for b in int(level.get("berths", 2)):
		berth_ship.append(-1)
	for b in berth_ship.size():
		_dock(b, [])

func snapshot() -> Dictionary:
	return {
		"containers": containers.duplicate(true), "stacks": stacks.duplicate(true),
		"buffer": buffer.duplicate(), "berth_ship": berth_ship.duplicate(),
		"ship_color": ship_color.duplicate(), "ship_slots": ship_slots.duplicate(true),
		"next_q": next_q, "sailed": sailed, "peak": peak, "moves": moves,
		"uid": _next_ship_uid, "finished": finished,
		"best_chain": best_chain,
	}

func restore(s: Dictionary) -> void:
	# keys may come back as strings after a round trip through the save file
	containers = _int_keys(s["containers"])
	stacks = s["stacks"].duplicate(true)
	buffer = s["buffer"].duplicate()
	berth_ship = s["berth_ship"].duplicate()
	ship_color = _int_keys(s["ship_color"])
	ship_slots = _int_keys(s["ship_slots"])
	next_q = int(s["next_q"])
	sailed = int(s["sailed"])
	peak = int(s["peak"])
	moves = int(s["moves"])
	_next_ship_uid = int(s["uid"])
	finished = s["finished"]
	best_chain = int(s.get("best_chain", 0))
	combo = 0

static func _int_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		var v = d[k]
		out[int(k)] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	return out

func color_of(id: int) -> int:
	return containers[id]["c"]

func is_gold(id: int) -> bool:
	return containers[id].get("g", false)

func is_locked(id: int) -> bool:
	return containers[id]["l"] > sailed

func buffer_used() -> int:
	var n := 0
	for v in buffer:
		if v != -1:
			n += 1
	return n

func remaining_containers() -> int:
	var n := buffer_used()
	for col in stacks:
		n += col.size()
	return n

func add_buffer_slot() -> int:
	buffer.append(-1)
	return buffer.size() - 1

## Colour counts of containers still under a tarp (the cargo manifest).
func hidden_manifest() -> Dictionary:
	var m := {}
	for col in stacks:
		for id in col:
			if containers[id]["h"]:
				var c: int = containers[id]["c"]
				m[c] = m.get(c, 0) + 1
	return m

func gold_ids() -> Array:
	var out := []
	for id in containers:
		if is_gold(id):
			out.append(id)
	return out

## "" if the stack can be tapped, otherwise a reason: empty, locked, full
func check_tap(s: int) -> String:
	if finished:
		return "done"
	if s < 0 or s >= stacks.size() or stacks[s].is_empty():
		return "empty"
	var id: int = stacks[s].back()
	if is_locked(id):
		return "locked"
	if _berth_for(color_of(id)) == -1 and buffer.find(-1) == -1:
		return "full"
	return ""

func any_move() -> bool:
	for s in stacks.size():
		if check_tap(s) == "":
			return true
	return false

func tap(s: int) -> Array:
	var events := []
	var why := check_tap(s)
	if why != "":
		events.append({"t": "refuse", "stack": s, "why": why})
		return events
	moves += 1
	var id: int = stacks[s].pop_back()
	var c := color_of(id)
	var b := _berth_for(c)
	if b != -1:
		combo += 1
		var uid: int = berth_ship[b]
		ship_slots[uid].append(id)
		events.append({"t": "move", "id": id, "from_stack": s, "to": "ship", "berth": b,
			"ship": uid, "slot": ship_slots[uid].size() - 1, "combo": combo})
	else:
		# parking ends the direct-load streak (a small, visual-only reward)
		combo = 0
		var k := buffer.find(-1)
		buffer[k] = id
		peak = max(peak, buffer_used())
		events.append({"t": "move", "id": id, "from_stack": s, "to": "buffer", "slot": k, "combo": 0})
	# reveal the new top container
	if stacks[s].size() > 0:
		var top: int = stacks[s].back()
		if containers[top]["h"]:
			containers[top]["h"] = false
			events.append({"t": "reveal", "id": top})
	if b != -1 and ship_slots[berth_ship[b]].size() >= cap:
		_depart(b, events)
	# dispatch chain summary for this tap
	var departed := 0
	var from_buffer := 0
	for e in events:
		if e["t"] == "depart":
			departed += 1
		elif e["t"] == "move" and e.has("from_buffer"):
			from_buffer += 1
	best_chain = max(best_chain, departed)
	if departed >= 2 or from_buffer >= 3:
		events.append({"t": "chain", "ships": departed, "from_buffer": from_buffer})
	_check_end(events)
	return events

func _berth_for(c: int) -> int:
	for b in berth_ship.size():
		var uid: int = berth_ship[b]
		if uid != -1 and ship_color[uid] == c and ship_slots[uid].size() < cap:
			return b
	return -1

func _depart(b: int, events: Array) -> void:
	var uid: int = berth_ship[b]
	events.append({"t": "depart", "berth": b, "ship": uid})
	berth_ship[b] = -1
	sailed += 1
	for id in containers:
		var l: int = containers[id]["l"]
		if l > 0 and l <= sailed:
			containers[id]["l"] = 0
			events.append({"t": "unlock", "id": id})
	_dock(b, events)

func _dock(b: int, events: Array) -> void:
	if next_q >= queue.size():
		return
	var c: int = queue[next_q]
	next_q += 1
	var uid := _next_ship_uid
	_next_ship_uid += 1
	ship_color[uid] = c
	ship_slots[uid] = []
	berth_ship[b] = uid
	events.append({"t": "arrive", "berth": b, "ship": uid, "color": c, "initial": events.is_empty() and moves == 0})
	# parked containers of this colour hop aboard
	for k in buffer.size():
		var id: int = buffer[k]
		if id != -1 and color_of(id) == c and ship_slots[uid].size() < cap:
			buffer[k] = -1
			ship_slots[uid].append(id)
			events.append({"t": "move", "id": id, "from_buffer": k, "to": "ship", "berth": b,
				"ship": uid, "slot": ship_slots[uid].size() - 1, "combo": 0})
	if ship_slots[uid].size() >= cap:
		_depart(b, events)

func _check_end(events: Array) -> void:
	if remaining_containers() == 0:
		finished = true
		events.append({"t": "win"})
	elif not any_move():
		events.append({"t": "lose"})

## Encode the current position for the solver (hidden colours are treated as known).
## Solver codes: colour | gold << 4 | lock << 5.
func to_solver_state() -> Dictionary:
	var st := []
	for col in stacks:
		var a := []
		for id in col:
			var info: Dictionary = containers[id]
			a.append(int(info["c"]) | (16 if info.get("g", false) else 0) | (int(info["l"]) << 5))
		st.append(a)
	var buf := []
	buf.resize(16)
	buf.fill(0)
	for id in buffer:
		if id != -1:
			buf[color_of(id)] += 1
	var docked := []
	for uid in berth_ship:
		if uid == -1:
			docked.append([-1, 0])
		else:
			docked.append([ship_color[uid], ship_slots[uid].size()])
	return {"stacks": st, "buf": buf, "docked": docked, "next_q": next_q, "sailed": sailed,
		"chain": best_chain,
		"queue": queue, "cap": cap, "limit": buffer.size()}
