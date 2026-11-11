class_name Solver
extends RefCounted
## Exhaustive search over yard positions.
## A state: stacks (codes colour | gold << 4 | lock << 5), parked counts per colour,
## docked ships [colour, fill], next ship index, ships sailed and the best chain
## so far. Used at build time to verify levels (3-star limit, chain) and at
## runtime for the Hint booster.

var queue: Array = []
var cap := 3
var limit := 5               # buffer size (peak storage allowed)
var budget := 200000
var nodes := 0
var need_chain := 0          # require a tap that sends off this many ships
var _dead := {}

static func colour(code: int) -> int:
	return code & 15

static func lock(code: int) -> int:
	return code >> 5

func _key(st: Dictionary) -> String:
	return var_to_str([st["stacks"], st["buf"], st["docked"], st["next_q"], min(st["chain"], need_chain)])

static func copy_state(st: Dictionary) -> Dictionary:
	return {"stacks": st["stacks"].duplicate(true), "buf": st["buf"].duplicate(),
		"docked": st["docked"].duplicate(true), "next_q": st["next_q"], "sailed": st["sailed"],
		"chain": st.get("chain", 0)}

func _buf_total(st: Dictionary) -> int:
	var n := 0
	for v in st["buf"]:
		n += v
	return n

## Returns the new state or null if the move is illegal (or breaks a constraint).
func apply(st: Dictionary, s: int):
	var col: Array = st["stacks"][s]
	if col.is_empty():
		return null
	var code: int = col.back()
	var c := colour(code)
	if lock(code) > st["sailed"]:
		return null
	var b := -1
	for i in st["docked"].size():
		if st["docked"][i][0] == c and st["docked"][i][1] < cap:
			b = i
			break
	if b == -1:
		if _buf_total(st) >= limit:
			return null
	var ns := copy_state(st)
	ns["stacks"][s].pop_back()
	if b != -1:
		ns["docked"][b][1] += 1
	else:
		ns["buf"][c] += 1
	var before: int = ns["sailed"]
	_cascade(ns)
	ns["chain"] = max(ns["chain"], ns["sailed"] - before)
	return ns

func _cascade(ns: Dictionary) -> void:
	var changed := true
	while changed:
		changed = false
		for i in ns["docked"].size():
			if ns["docked"][i][0] != -1 and ns["docked"][i][1] >= cap:
				ns["sailed"] += 1
				if ns["next_q"] < queue.size():
					var nc: int = queue[ns["next_q"]]
					ns["next_q"] += 1
					var take: int = min(ns["buf"][nc], cap)
					ns["buf"][nc] -= take
					ns["docked"][i] = [nc, take]
				else:
					ns["docked"][i] = [-1, 0]
				changed = true

func is_goal(st: Dictionary) -> bool:
	for col in st["stacks"]:
		if not col.is_empty():
			return false
	if _buf_total(st) != 0:
		return false
	return st["chain"] >= need_chain

## Depth-first search. Returns the list of stack indices to tap, or null.
## After a null, `exhausted()` tells a proven dead end from a search that ran out of budget.
func solve(st: Dictionary):
	nodes = 0
	_dead.clear()
	var s0 := copy_state(st)
	var path := []
	if _dfs(s0, path):
		return path
	return null

func exhausted() -> bool:
	return nodes > budget

func _dfs(st: Dictionary, path: Array) -> bool:
	if is_goal(st):
		return true
	nodes += 1
	if nodes > budget:
		return false
	var k := _key(st)
	if _dead.has(k):
		return false
	# Prefer moves that load a ship directly, then parking moves.
	var direct := []
	var other := []
	for s in st["stacks"].size():
		var col: Array = st["stacks"][s]
		if col.is_empty():
			continue
		var c: int = colour(col.back())
		var hit := false
		for d in st["docked"]:
			if d[0] == c and d[1] < cap:
				hit = true
		if hit:
			direct.append(s)
		else:
			other.append(s)
	for s in direct + other:
		var ns = apply(st, s)
		if ns == null:
			continue
		path.append(s)
		if _dfs(ns, path):
			return true
		path.pop_back()
		if nodes > budget:
			return false
	_dead[k] = true
	return false

## Smallest buffer size that still allows a full clear (-1 if none up to max_limit).
func min_buffer(st: Dictionary, max_limit: int) -> int:
	var keep := limit
	for l in range(0, max_limit + 1):
		limit = l
		if solve(st) != null:
			limit = keep
			return l
	limit = keep
	return -1

## Fraction of random play-throughs that clear the yard - how forgiving a level is.
func random_success(st: Dictionary, trials: int, rng: RandomNumberGenerator) -> float:
	var keep := need_chain
	need_chain = 0
	var wins := 0
	for t in trials:
		var cur := copy_state(st)
		while true:
			if is_goal(cur):
				wins += 1
				break
			var legal := []
			for s in cur["stacks"].size():
				var ns = apply(cur, s)
				if ns != null:
					legal.append(ns)
			if legal.is_empty():
				break
			cur = legal[rng.randi_range(0, legal.size() - 1)]
	need_chain = keep
	return float(wins) / float(trials)
