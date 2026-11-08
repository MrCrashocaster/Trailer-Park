extends Node
## Authoritative, render-independent park simulation. All money and placement changes
## enter through apply_command; rejected commands leave the saved state untouched.

signal changed()

const GRID_W: int = 48
const GRID_H: int = 36
const CELL_SIZE: float = 6.0
const DAY_SECONDS: float = 90.0
const MAX_LOTS: int = 40
const MAX_DEBT: int = 50000
const PARCEL_COST: int = 6500
const CATALOG: Dictionary = {
	"road": {"name":"Gravel road", "cost":45, "upkeep":1, "footprint":[1,1], "category":"Roads", "description":"Connect lots and services to the park entrance."},
	"trailer": {"name":"Single-wide trailer", "cost":1850, "upkeep":12, "footprint":[3,2], "category":"Homes", "description":"One household. Needs road access, power, water and sewage."},
	"power": {"name":"Power substation", "cost":2800, "upkeep":48, "footprint":[2,2], "category":"Utilities", "capacity":12, "description":"Supplies 12 road-connected households. Upgrade for more capacity."},
	"water": {"name":"Water tower", "cost":2400, "upkeep":36, "footprint":[2,2], "category":"Utilities", "capacity":12, "description":"Water for 12 households; requires a working power network."},
	"sewage": {"name":"Septic works", "cost":2200, "upkeep":32, "footprint":[2,2], "category":"Utilities", "capacity":12, "description":"Sewage treatment for 12 households; requires power."},
	"trash": {"name":"Waste collection", "cost":1600, "upkeep":30, "footprint":[2,2], "category":"Services", "capacity":16, "description":"Collects trash from up to 16 connected homes."},
	"maintenance": {"name":"Maintenance shed", "cost":1900, "upkeep":36, "footprint":[2,2], "category":"Services", "capacity":16, "description":"Slows wear at 16 homes and supports park repairs."},
	"laundry": {"name":"Laundromat", "cost":2600, "upkeep":28, "footprint":[3,2], "category":"Business", "description":"Earns customer income and improves household satisfaction."},
	"store": {"name":"Corner store", "cost":3200, "upkeep":35, "footprint":[3,2], "category":"Business", "description":"Park convenience shop. Unlocked at 12 occupied homes."},
	"office": {"name":"Park office", "cost":1500, "upkeep":24, "footprint":[3,2], "category":"Services", "description":"A meeting place and administrative home for the park."},
	"lamp": {"name":"Street light", "cost":120, "upkeep":1, "footprint":[1,1], "category":"Grounds", "description":"Lights the neighborhood and improves nearby household satisfaction."},
	"tree": {"name":"Shade tree", "cost":75, "upkeep":0, "footprint":[1,1], "category":"Grounds", "description":"Adds shade and improves nearby household satisfaction."},
	"fence": {"name":"Yard fence", "cost":55, "upkeep":0, "footprint":[1,1], "category":"Grounds", "description":"A modest yard boundary and privacy improvement."}
}
const NAMES: Array = ["Avery", "Bell", "Brooks", "Carter", "Dawson", "Ellis", "Finch", "Gibbs", "Harper", "Irwin", "Jensen", "Kerr", "Lane", "Moss", "Nash", "Owens", "Parker", "Quinn", "Reed", "Sawyer", "Tate", "Vega", "Wells", "York"]
const EVENT_TEMPLATES: Array = [
	{"title":"A roadside mountain of junk", "description":"Someone has left a sofa, three tires and a suspicious freezer beside the entrance. Residents want it gone.", "choices":[{"label":"Arrange collection", "cost":350, "effect":"clean"}, {"label":"Community cleanup", "cost":80, "effect":"volunteer"}, {"label":"Leave it for now", "cost":0, "effect":"ignore"}]},
	{"title":"An unlicensed yard business", "description":"A household is repairing appliances in its yard. Neighbors complain about the noise, but the work brings in money.", "choices":[{"label":"Issue a modest permit", "cost":-150, "effect":"permit"}, {"label":"Offer a quieter workspace", "cost":450, "effect":"support"}, {"label":"Close it down", "cost":0, "effect":"enforce"}]},
	{"title":"Rent is running late", "description":"A resident lost a week of work after their car broke down. Their rent has fallen behind.", "choices":[{"label":"Agree a payment plan", "cost":120, "effect":"support"}, {"label":"Grant a short extension", "cost":200, "effect":"volunteer"}, {"label":"Apply the late fee", "cost":-60, "effect":"enforce"}]},
	{"title":"The pump is making that noise", "description":"The water pump is rattling again. A proper service would prevent a more expensive failure.", "choices":[{"label":"Service the pump", "cost":500, "effect":"service"}, {"label":"Patch it for now", "cost":180, "effect":"patch"}, {"label":"Keep it running", "cost":0, "effect":"breakdown"}]}
]

var state: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _notify_elapsed: float = 0.0

func _ready() -> void:
	if state.is_empty():
		reset()

func reset(seed_value: int = 41721) -> void:
	_rng.seed = seed_value
	state = {"schema":1, "park_name":"Gravel Pines", "seed":seed_value, "rng_state":str(_rng.state), "revision":0, "day":1, "day_progress":0.28, "speed":1, "cash":28000.0, "debt":0.0, "rent":125.0, "buildings":[], "roads":[], "owned":[0,3], "events":[], "ledger":[], "stats":{}, "next_id":1, "next_event":1, "reputation":58.0, "level":1, "lifetime_income":0.0, "daily_income":0.0, "daily_expenses":0.0, "daily_profit":0.0, "days_played":0}
	for z: int in range(2, 34):
		state.roads.append({"x":6, "z":z})
	for x: int in range(16):
		if x != 6:
			state.roads.append({"x":x, "z":18})
	for z: int in [3,7,11,15]:
		for x: int in [3,7]:
			var home: Dictionary = _new_building("trailer", x, z, 0)
			home.occupied = true
			home.household = str(NAMES[(int(home.id) - 1) % NAMES.size()]) + " household"
			home.budget = 145.0 + float(_rng.randi_range(0, 40))
			home.happiness = float(_rng.randi_range(61, 80))
			home.condition = float(_rng.randi_range(74, 95))
			state.buildings.append(home)
	for facility: Array in [["power",4,21],["water",4,25],["sewage",4,29],["office",7,21],["trash",7,25],["maintenance",7,29]]:
		state.buildings.append(_new_building(str(facility[0]), int(facility[1]), int(facility[2]), 0))
	state.rng_state = str(_rng.state)
	_record("Welcome to Gravel Pines. Eight households, a working utility network, and room to grow.", 0.0, "Park")
	_recalculate()
	_notify_elapsed = 0.0
	changed.emit()

func snapshot() -> Dictionary:
	return state.duplicate(true)

func restore(data: Dictionary) -> bool:
	if not _valid_saved_state(data):
		return false
	state = data.duplicate(true)
	# JSON represents integer fields as floats. Normalize identifiers before use.
	for key: String in ["schema","seed","revision","day","speed","next_id","next_event","level","days_played"]:
		state[key] = int(state[key])
	for building: Dictionary in state.buildings:
		for key: String in ["id","x","z","rotation","level","vacant_days","unhappy_days"]:
			building[key] = int(building[key])
	for road: Dictionary in state.roads:
		road.x = int(road.x)
		road.z = int(road.z)
	for i: int in range(state.owned.size()):
		state.owned[i] = int(state.owned[i])
	for event: Dictionary in state.events:
		event.id = int(event.id)
	_rng.seed = int(state.seed)
	_rng.state = int(state.rng_state)
	_notify_elapsed = 0.0
	_recalculate()
	changed.emit()
	return true

func footprint(kind: String, rotation: int = 0) -> Vector2i:
	if not CATALOG.has(kind):
		return Vector2i.ONE
	var size: Array = CATALOG[kind].footprint
	return Vector2i(int(size[1]), int(size[0])) if posmod(rotation, 2) == 1 else Vector2i(int(size[0]), int(size[1]))

func parcel_at(x: int, z: int) -> int:
	return int(x / 16) + int(z / 18) * 3

func is_owned(x: int, z: int) -> bool:
	return x >= 0 and x < GRID_W and z >= 0 and z < GRID_H and state.owned.has(parcel_at(x,z))

func building_at(x: int, z: int) -> Dictionary:
	for building: Dictionary in state.buildings:
		var size: Vector2i = footprint(str(building.kind), int(building.rotation))
		if Rect2i(int(building.x), int(building.z), size.x, size.y).has_point(Vector2i(x,z)):
			return building
	return {}

func connected_roads() -> Dictionary:
	var available: Dictionary = {}
	for road: Dictionary in state.roads:
		available[Vector2i(int(road.x), int(road.z))] = true
	var found: Dictionary = {}
	var entry: Vector2i = Vector2i(0,18)
	if not available.has(entry):
		return found
	var queue: Array[Vector2i] = [entry]
	found[entry] = true
	var cursor: int = 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var neighbor: Vector2i = cell + offset
			if available.has(neighbor) and not found.has(neighbor):
				found[neighbor] = true
				queue.append(neighbor)
	return found

func validate_placement(kind: String, x: int, z: int, rotation: int = 0) -> Dictionary:
	return _placement(kind,x,z,rotation,-1)

func validate_move(id_value: int, x: int, z: int, rotation: int = 0) -> Dictionary:
	var building: Dictionary = _by_id(id_value)
	if building.is_empty(): return _failure("That building no longer exists.")
	if x==int(building.x) and z==int(building.z) and rotation==int(building.rotation): return _failure("Choose a different location or rotation.")
	var check: Dictionary = _placement(str(building.kind),x,z,rotation,id_value)
	if not bool(check.ok): return check
	if bool(building.occupied) and not bool(check.connected): return _failure("An occupied home needs a road-connected destination.")
	var cost: float = move_cost(building)
	if float(state.cash)<cost: return {"ok":false,"message":"Relocation costs $%d." % int(cost),"cost":cost}
	check.cost=cost
	check.message="Ready to relocate for $%d." % int(cost)
	return check

func validate_road_path(points: Array) -> Dictionary:
	if points.is_empty() or points.size()>96 or not _safe_value(points):
		return _failure("Choose a road path of 1–96 grid cells.")
	var existing: Dictionary={}
	for road: Dictionary in state.roads:
		existing[Vector2i(int(road.x),int(road.z))]=true
	var unique: Dictionary={}
	var cells: Array=[]
	var previous: Vector2i=Vector2i(-999,-999)
	for raw: Variant in points:
		if not raw is Dictionary or not _coordinates(raw): return _failure("Road paths need valid integer grid coordinates.")
		var cell: Vector2i=Vector2i(int(raw.x),int(raw.z))
		if previous.x!=-999 and absi(cell.x-previous.x)+absi(cell.y-previous.y)>1:
			return _failure("Road paths must connect through neighboring grid cells.")
		previous=cell
		if not is_owned(cell.x,cell.y): return _failure("Purchase every land parcel crossed by this road first.")
		if not building_at(cell.x,cell.y).is_empty(): return _failure("This road would overlap an existing building.")
		if not unique.has(cell):
			unique[cell]=true
			if not existing.has(cell): cells.append({"x":cell.x,"z":cell.y})
	var cost: float=float(cells.size())*float(CATALOG.road.cost)
	if cost>0.0 and float(state.cash)<cost: return {"ok":false,"message":"This road costs $%d; the park has insufficient funds." % int(cost),"cost":cost,"count":cells.size(),"cells":cells}
	return {"ok":true,"message":"Build %d road segments for $%d." % [cells.size(),int(cost)] if not cells.is_empty() else "This road is already built.","cost":cost,"count":cells.size(),"cells":cells}

func _placement(kind: String, x: int, z: int, rotation: int, ignore_id: int) -> Dictionary:
	if not CATALOG.has(kind):
		return _failure("Unknown building type.")
	if rotation < 0 or rotation > 3:
		return _failure("Rotation must be a quarter turn from 0 to 3.")
	var size: Vector2i = footprint(kind,rotation)
	for cx: int in range(x, x + size.x):
		for cz: int in range(z, z + size.y):
			if not is_owned(cx,cz):
				return _failure("Purchase this land parcel before building here.")
			var other: Dictionary = building_at(cx,cz)
			if not other.is_empty() and int(other.id) != ignore_id:
				return _failure("Another building occupies this space.")
			if _road_exists(cx,cz):
				return _failure("This space is occupied by a road.")
	if kind == "trailer" and ignore_id < 0 and int(state.stats.get("lots",0)) >= MAX_LOTS:
		return _failure("This park has reached its 40-home planning limit.")
	if kind == "store" and int(state.level) < 2:
		return _failure("The corner store unlocks at 12 occupied homes.")
	return {"ok":true, "message":"Ready to build.", "cost":int(CATALOG[kind].cost), "connected":_touches_road(x,z,size,connected_roads())}

func apply_command(action: String, data: Dictionary, actor: String = "Host") -> Dictionary:
	if state.is_empty():
		return _failure("The park has not been created.")
	if not _safe_value(data):
		return _failure("Invalid command data.")
	actor = actor.strip_edges().left(32)
	var result: Dictionary
	match action:
		"place": result = _place(data,actor)
		"road_path": result = _road_path(data,actor)
		"demolish": result = _demolish(data,actor)
		"move": result = _move(data,actor)
		"repair": result = _repair(data,actor)
		"upgrade": result = _upgrade(data,actor)
		"set_rent":
			if not _number_in(data.get("value"),25.0,350.0): return _failure("Daily rent must be between $25 and $350.")
			state.rent = snappedf(float(data.value),1.0)
			_record("Daily rent set to $%d." % int(state.rent),0.0,actor)
			result = _ok("Daily rent updated.")
		"buy_land": result = _buy_land(data,actor)
		"loan": result = _loan(data,actor)
		"repay": result = _repay(data,actor)
		"speed":
			if not _is_int(data.get("value")) or not [0,1,2,4].has(int(data.value)): return _failure("Choose pause, 1x, 2x or 4x speed.")
			state.speed = int(data.value)
			result = _ok("Park paused." if int(state.speed) == 0 else "Simulation speed updated.")
		"resolve_event": result = _resolve_event(data,actor)
		"rename":
			if not data.get("name") is String: return _failure("Enter a park name.")
			if _has_name_control(str(data.name)): return _failure("Park names cannot contain line breaks or control characters.")
			var park_name: String = str(data.name).strip_edges()
			if park_name.length() < 2 or park_name.length() > 32: return _failure("Park names need 2–32 characters.")
			state.park_name = park_name
			result = _ok("Park renamed.")
		_: return _failure("Unknown park command.")
	if bool(result.get("ok",false)) and not bool(result.get("unchanged",false)):
		state.revision = int(state.revision) + 1
		_recalculate()
		changed.emit()
	return result

func _road_path(data: Dictionary, actor: String) -> Dictionary:
	if not data.get("points") is Array: return _failure("Choose the connected cells for this road.")
	var check: Dictionary=validate_road_path(data.points)
	if not bool(check.ok): return check
	if int(check.count)==0: return {"ok":true,"message":str(check.message),"unchanged":true}
	state.cash=float(state.cash)-float(check.cost)
	for cell: Dictionary in check.cells: state.roads.append(cell)
	_record("Built %d connected road segments." % int(check.count),-float(check.cost),actor)
	return _ok("Built %d road segments for $%d." % [int(check.count),int(check.cost)])

func _place(data: Dictionary, actor: String) -> Dictionary:
	if not data.get("kind") is String or not _coordinates(data): return _failure("Choose a building and a valid grid position.")
	var kind: String = str(data.kind)
	var rotation: int = int(data.get("rotation",0))
	var check: Dictionary = _placement(kind,int(data.x),int(data.z),rotation,-1)
	if not bool(check.ok): return check
	var cost: float = float(CATALOG[kind].cost)
	if float(state.cash) < cost: return _failure("Not enough park funds for this purchase.")
	state.cash = float(state.cash) - cost
	if kind == "road":
		state.roads.append({"x":int(data.x),"z":int(data.z)})
	else:
		state.buildings.append(_new_building(kind,int(data.x),int(data.z),rotation))
	_record("Built " + str(CATALOG[kind].name) + ".", -cost,actor)
	return _ok(str(CATALOG[kind].name) + " built.")

func _demolish(data: Dictionary, actor: String) -> Dictionary:
	if data.has("id"):
		if not _is_int(data.id): return _failure("Invalid building identifier.")
		var building: Dictionary = _by_id(int(data.id))
		if building.is_empty(): return _failure("That building no longer exists.")
		if bool(building.occupied): return _failure("Occupied homes cannot be demolished. Lower demand or relocate the home instead.")
		var refund: float = floor(float(CATALOG[str(building.kind)].cost) * 0.25)
		state.buildings.erase(building)
		state.cash = float(state.cash) + refund
		_record("Removed " + str(CATALOG[str(building.kind)].name) + ".",refund,actor)
		return _ok("Building removed; salvaged $%d." % int(refund))
	if not _coordinates(data): return _failure("Select a building or road to remove.")
	var cell: Vector2i = Vector2i(int(data.x),int(data.z))
	if cell == Vector2i(0,18): return _failure("The park entrance must remain connected.")
	var road_index: int = -1
	for i: int in range(state.roads.size()):
		var road: Dictionary = state.roads[i]
		if int(road.x) == cell.x and int(road.z) == cell.y: road_index = i; break
	if road_index < 0: return _failure("There is no road here.")
	var before: Dictionary = connected_roads()
	var road_copy: Dictionary = state.roads[road_index].duplicate(true)
	state.roads.remove_at(road_index)
	var after: Dictionary = connected_roads()
	for building: Dictionary in state.buildings:
		var size: Vector2i = footprint(str(building.kind),int(building.rotation))
		if _touches_road(int(building.x),int(building.z),size,before) and not _touches_road(int(building.x),int(building.z),size,after):
			state.roads.insert(road_index,road_copy)
			return _failure("Removing this road would disconnect an existing building.")
	_record("Removed a gravel road segment.",0.0,actor)
	return _ok("Road removed.")

func _move(data: Dictionary, actor: String) -> Dictionary:
	if not _is_int(data.get("id")) or not _coordinates(data): return _failure("Select a building and its new position.")
	var building: Dictionary = _by_id(int(data.id))
	if building.is_empty(): return _failure("That building no longer exists.")
	var rotation: int = int(data.get("rotation",building.rotation))
	var check: Dictionary = validate_move(int(building.id),int(data.x),int(data.z),rotation)
	if not bool(check.ok): return check
	var cost: float = float(check.cost)
	state.cash = float(state.cash) - cost
	building.x = int(data.x)
	building.z = int(data.z)
	building.rotation = rotation
	_record("Relocated " + str(CATALOG[str(building.kind)].name) + ".",-cost,actor)
	return _ok("Building relocated.")

func _repair(data: Dictionary, actor: String) -> Dictionary:
	if not _is_int(data.get("id")): return _failure("Select a building to repair.")
	var building: Dictionary = _by_id(int(data.id))
	if building.is_empty(): return _failure("That building no longer exists.")
	if float(building.condition) >= 99.9: return _failure("This building is already in excellent condition.")
	var cost: float = repair_cost(building)
	if float(state.cash) < cost: return _failure("Repairs cost $%d." % int(cost))
	state.cash = float(state.cash) - cost
	building.condition = 100.0
	_record("Repaired " + str(CATALOG[str(building.kind)].name) + ".",-cost,actor)
	return _ok("Repairs complete.")

func repair_cost(building: Dictionary) -> float:
	return ceil((100.0 - float(building.get("condition",100.0))) / 100.0 * float(CATALOG[str(building.kind)].cost) * 0.4)

func move_cost(building: Dictionary) -> float:
	return ceil(float(CATALOG[str(building.kind)].cost)*0.15)

func upgrade_cost(building: Dictionary) -> float:
	return ceil(float(CATALOG[str(building.kind)].cost) * 0.55 * float(building.get("level",1)))

func _upgrade(data: Dictionary, actor: String) -> Dictionary:
	if not _is_int(data.get("id")): return _failure("Select a building to upgrade.")
	var building: Dictionary = _by_id(int(data.id))
	if building.is_empty(): return _failure("That building no longer exists.")
	if int(building.level) >= 3: return _failure("This building is fully upgraded.")
	if ["tree","fence","lamp"].has(str(building.kind)): return _failure("This item has no upgrades.")
	var cost: float = upgrade_cost(building)
	if float(state.cash) < cost: return _failure("The upgrade costs $%d." % int(cost))
	state.cash = float(state.cash) - cost
	building.level = int(building.level) + 1
	building.condition = 100.0
	_record("Upgraded " + str(CATALOG[str(building.kind)].name) + " to level %d." % int(building.level),-cost,actor)
	return _ok("Upgrade complete.")

func _buy_land(data: Dictionary, actor: String) -> Dictionary:
	if not _is_int(data.get("parcel")): return _failure("Choose a land parcel.")
	var parcel: int = int(data.parcel)
	if parcel < 0 or parcel > 5 or state.owned.has(parcel): return _failure("That land is unavailable or already owned.")
	var adjacent: bool = false
	for owned: Variant in state.owned:
		if abs((int(owned) % 3) - (parcel % 3)) + abs(int(int(owned) / 3) - int(parcel / 3)) == 1: adjacent = true
	if not adjacent: return _failure("Buy a parcel adjoining the park first.")
	if float(state.cash) < PARCEL_COST: return _failure("This parcel costs $%d." % PARCEL_COST)
	state.cash = float(state.cash) - PARCEL_COST
	state.owned.append(parcel)
	_record("Purchased land parcel %d." % (parcel+1),-float(PARCEL_COST),actor)
	return _ok("New land is ready for development.")

func _loan(data: Dictionary, actor: String) -> Dictionary:
	if not _is_int(data.get("amount")) or int(data.amount) < 1000 or int(data.amount) % 1000 != 0: return _failure("Borrow in increments of $1,000.")
	var amount: float = float(data.amount)
	if amount + float(state.debt) > MAX_DEBT: return _failure("The park's credit limit is $50,000.")
	state.cash = float(state.cash) + amount
	state.debt = float(state.debt) + amount
	_record("Park loan received; daily interest is 0.1%.",amount,actor)
	return _ok("Loan received.")

func _repay(data: Dictionary, actor: String) -> Dictionary:
	if not _number_in(data.get("amount"),1.0,MAX_DEBT): return _failure("Choose a positive repayment amount.")
	var amount: float = float(data.amount)
	if amount > float(state.debt): return _failure("Repayment exceeds the outstanding debt.")
	if amount > float(state.cash): return _failure("Not enough funds for this repayment.")
	state.cash = float(state.cash) - amount
	state.debt = float(state.debt) - amount
	_record("Repaid park loan.",-amount,actor)
	return _ok("Loan repayment complete.")

func _resolve_event(data: Dictionary, actor: String) -> Dictionary:
	if not _is_int(data.get("id")) or not _is_int(data.get("choice")): return _failure("Choose a response to this situation.")
	var event: Dictionary = {}
	for candidate: Dictionary in state.events:
		if int(candidate.id) == int(data.id): event = candidate; break
	if event.is_empty(): return _failure("That situation has already been handled.")
	var index: int = int(data.choice)
	if index < 0 or index >= event.choices.size(): return _failure("Unknown response.")
	var choice: Dictionary = event.choices[index]
	var cost: float = float(choice.cost)
	if cost > float(state.cash): return _failure("That response costs $%d." % int(cost))
	state.cash = float(state.cash) - cost
	match str(choice.effect):
		"clean","support","service":
			state.reputation = minf(100.0,float(state.reputation)+4.0)
			_adjust_happiness(5.0)
			if str(choice.effect) == "service": _adjust_facility_condition("water",20.0)
		"volunteer": _adjust_happiness(3.0)
		"permit": state.reputation = minf(100.0,float(state.reputation)+1.0)
		"enforce": _adjust_happiness(-3.0)
		"ignore": state.reputation = maxf(0.0,float(state.reputation)-5.0); _adjust_happiness(-7.0)
		"patch": _adjust_facility_condition("water",5.0)
		"breakdown": _adjust_facility_condition("water",-55.0)
	state.events.erase(event)
	_record(str(event.title) + ": " + str(choice.label) + ".",-cost,actor)
	return _ok("Situation resolved.")

func advance(delta: float) -> void:
	if state.is_empty() or not is_finite(delta) or delta <= 0.0 or int(state.speed) == 0:
		return
	state.day_progress = float(state.day_progress) + minf(delta,3600.0) * float(state.speed) / DAY_SECONDS
	var completed_day: bool = false
	while float(state.day_progress) >= 1.0:
		state.day_progress = float(state.day_progress) - 1.0
		_simulate_day()
		completed_day = true
	_notify_elapsed += delta
	if completed_day or _notify_elapsed >= 1.0:
		_notify_elapsed = 0.0
		state.revision = int(state.revision) + 1
		changed.emit()

func step_day() -> void:
	_simulate_day()
	state.revision = int(state.revision) + 1
	changed.emit()

func _simulate_day() -> void:
	state.day = int(state.day) + 1
	state.days_played = int(state.days_played) + 1
	_recalculate()
	var income: float = 0.0
	var expenses: float = float(state.roads.size()) + float(state.debt) * 0.001
	var occupied: int = int(state.stats.occupied)
	for building: Dictionary in state.buildings:
		var kind: String = str(building.kind)
		var maintained: bool = bool(building.get("services",{}).get("maintenance",false))
		var wear: float = _rng.randf_range(0.25,0.8) * (0.45 if maintained else 1.0)
		if not ["tree","fence","lamp"].has(kind): building.condition = maxf(0.0,float(building.condition)-wear)
		expenses += float(CATALOG[kind].upkeep) * (1.0 + 0.2 * float(int(building.level)-1))
		if kind == "trailer":
			var all_services: bool = _home_viable(building)
			var target: float = 30.0 + float(building.condition)*0.3 + (20.0 if all_services else -25.0)
			target += 8.0 if bool(building.services.trash) else -12.0
			target += _amenity_bonus(building)
			target -= maxf(0.0,float(state.rent)-float(building.budget)) * 0.45
			target += float(int(building.level)-1)*4.0
			building.happiness = clampf(lerpf(float(building.happiness),target,0.22),0.0,100.0)
			if bool(building.occupied):
				var effective_rent: float = float(state.rent) * (1.0 + float(int(building.level)-1)*0.12)
				if _rng.randf() < (0.06 if float(building.happiness) > 35.0 else 0.20):
					building.arrears = float(building.arrears) + effective_rent
				else:
					var recovery: float = minf(float(building.arrears),effective_rent*0.2)
					income += effective_rent + recovery
					building.arrears = float(building.arrears)-recovery
				if float(building.happiness) < 32.0 or not all_services:
					building.unhappy_days = int(building.unhappy_days)+1
				else: building.unhappy_days = 0
				if int(building.unhappy_days) >= 4:
					building.occupied = false
					building.vacant_days = 0
					_record(str(building.household) + " moved out after persistent problems.",0.0,"Residents")
			else:
				building.vacant_days = int(building.vacant_days)+1
				var attraction: float = clampf((float(state.reputation)+float(building.happiness))/200.0,0.1,0.9)
				if all_services and float(state.rent) <= float(building.budget)*1.15 and _rng.randf() < attraction:
					building.occupied = true
					building.unhappy_days = 0
					building.household = str(NAMES[_rng.randi_range(0,NAMES.size()-1)]) + " household"
					building.happiness = maxf(58.0,float(building.happiness))
					_record(str(building.household) + " moved into lot %d." % int(building.id),0.0,"Residents")
		elif ["laundry","store"].has(kind) and bool(building.connected) and float(building.condition) >= 25.0 and float(state.stats.power.capacity) > 0.0:
			income += float(occupied) * (9.0 if kind == "laundry" else 12.0) * float(building.level)
	state.daily_income = snappedf(income,0.01)
	state.daily_expenses = snappedf(expenses,0.01)
	state.daily_profit = snappedf(income-expenses,0.01)
	state.cash = snappedf(float(state.cash)+income-expenses,0.01)
	state.lifetime_income = float(state.lifetime_income)+income
	state.reputation = clampf(lerpf(float(state.reputation),float(state.stats.happiness),0.06),0.0,100.0)
	if int(state.day) % 4 == 0 and state.events.size() < 3:
		var event: Dictionary = EVENT_TEMPLATES[_rng.randi_range(0,EVENT_TEMPLATES.size()-1)].duplicate(true)
		event.id = int(state.next_event)
		event.day = int(state.day)
		state.next_event = int(state.next_event)+1
		state.events.append(event)
	if int(state.day) % 7 == 0:
		_record("Weekly review: $%d income, $%d expenses today." % [int(income),int(expenses)],income-expenses,"Accounts")
	state.rng_state = str(_rng.state)
	_recalculate()
	var new_level: int = 3 if int(state.stats.occupied) >= 24 else (2 if int(state.stats.occupied) >= 12 else 1)
	if new_level > int(state.level):
		state.level = new_level
		var grant: float = 1500.0 * float(new_level)
		state.cash = float(state.cash)+grant
		_record("Park milestone reached. Development grant awarded.",grant,"Council")
	_recalculate()

func metrics() -> Dictionary:
	return state.get("stats",{}).duplicate(true)

func _recalculate() -> void:
	var roads: Dictionary = connected_roads()
	var capacities: Dictionary = {"power":0,"water":0,"sewage":0,"trash":0,"maintenance":0}
	var lots: int = 0
	var occupied: int = 0
	var happiness: float = 0.0
	var demand: int = 0
	for building: Dictionary in state.buildings:
		building.connected = _touches_road(int(building.x),int(building.z),footprint(str(building.kind),int(building.rotation)),roads)
		building.services = {"road":building.connected,"power":false,"water":false,"sewage":false,"trash":false,"maintenance":false}
		var kind: String = str(building.kind)
		if capacities.has(kind) and bool(building.connected) and float(building.condition) >= 25.0:
			capacities[kind] = int(capacities[kind])+int(CATALOG[kind].capacity)+8*(int(building.level)-1)
	if int(capacities.power) == 0:
		capacities.water = 0
		capacities.sewage = 0
	var assigned: Dictionary = {"power":0,"water":0,"sewage":0,"trash":0,"maintenance":0}
	for building: Dictionary in state.buildings:
		if str(building.kind) != "trailer": continue
		lots += 1
		if bool(building.connected):
			demand += 1
			for service: String in capacities:
				if int(assigned[service]) < int(capacities[service]):
					building.services[service] = true
					assigned[service] = int(assigned[service])+1
		if bool(building.occupied):
			occupied += 1
			happiness += float(building.happiness)
	var service_states: Dictionary = {}
	for service: String in capacities:
		service_states[service] = {"used":demand,"capacity":int(capacities[service])}
	var income: float = 0.0
	var expenses: float = float(state.roads.size())+float(state.debt)*0.001
	for building: Dictionary in state.buildings:
		expenses += float(CATALOG[str(building.kind)].upkeep)*(1.0+0.2*float(int(building.level)-1))
		if str(building.kind)=="trailer" and bool(building.occupied):
			income += float(state.rent)*(1.0+float(int(building.level)-1)*0.12)
		if ["laundry","store"].has(str(building.kind)) and bool(building.connected) and float(building.condition) >= 25.0 and int(capacities.power)>0:
			income += float(occupied)*(9.0 if str(building.kind)=="laundry" else 12.0)*float(building.level)
	state.stats = {"cash":state.cash,"debt":state.debt,"rent":state.rent,"lots":lots,"occupied":occupied,"vacant":lots-occupied,"occupancy":float(occupied)/maxf(1.0,float(lots)),"happiness":happiness/maxf(1.0,float(occupied)),"reputation":state.reputation,"power":service_states.power,"water":service_states.water,"sewage":service_states.sewage,"trash":service_states.trash,"maintenance":service_states.maintenance,"trash_coverage":minf(1.0,float(capacities.trash)/maxf(1.0,float(demand))),"maintenance_coverage":minf(1.0,float(capacities.maintenance)/maxf(1.0,float(demand))),"income":income,"expenses":expenses,"profit":income-expenses,"land_owned":state.owned.size(),"level":state.level,"connected_lots":demand,"max_lots":MAX_LOTS}

func _new_building(kind: String, x: int, z: int, rotation: int) -> Dictionary:
	var building: Dictionary = {"id":int(state.next_id),"kind":kind,"x":x,"z":z,"rotation":rotation,"condition":100.0,"occupied":false,"household":"Vacant","happiness":62.0,"budget":155.0,"arrears":0.0,"level":1,"vacant_days":0,"unhappy_days":0,"connected":false,"services":{}}
	state.next_id = int(state.next_id)+1
	return building

func _by_id(id_value: int) -> Dictionary:
	for building: Dictionary in state.buildings:
		if int(building.id) == id_value: return building
	return {}

func _road_exists(x: int, z: int) -> bool:
	for road: Dictionary in state.roads:
		if int(road.x) == x and int(road.z) == z: return true
	return false

func _touches_road(x: int, z: int, size: Vector2i, roads: Dictionary) -> bool:
	for cx: int in range(x,x+size.x):
		if roads.has(Vector2i(cx,z-1)) or roads.has(Vector2i(cx,z+size.y)): return true
	for cz: int in range(z,z+size.y):
		if roads.has(Vector2i(x-1,cz)) or roads.has(Vector2i(x+size.x,cz)): return true
	return false

func _home_viable(building: Dictionary) -> bool:
	return bool(building.connected) and bool(building.services.power) and bool(building.services.water) and bool(building.services.sewage) and float(building.condition)>=25.0

func _amenity_bonus(home: Dictionary) -> float:
	var result: float = 0.0
	for building: Dictionary in state.buildings:
		if not ["tree","lamp","fence","laundry","store"].has(str(building.kind)): continue
		var distance: float = Vector2(float(home.x),float(home.z)).distance_to(Vector2(float(building.x),float(building.z)))
		if distance<=7.0: result += 2.0 if ["tree","lamp","fence"].has(str(building.kind)) else 5.0
	return minf(result,16.0)

func _adjust_happiness(amount: float) -> void:
	for building: Dictionary in state.buildings:
		if str(building.kind)=="trailer": building.happiness=clampf(float(building.happiness)+amount,0.0,100.0)

func _adjust_facility_condition(kind: String, amount: float) -> void:
	for building: Dictionary in state.buildings:
		if str(building.kind)==kind:
			building.condition=clampf(float(building.condition)+amount,0.0,100.0)
			return

func _record(text: String, amount: float, actor: String) -> void:
	state.ledger.push_front({"day":int(state.day),"text":text,"amount":snappedf(amount,0.01),"actor":actor})
	if state.ledger.size()>80: state.ledger.resize(80)

func _coordinates(data: Dictionary) -> bool:
	return _is_int(data.get("x")) and _is_int(data.get("z")) and _is_int(data.get("rotation",0)) and int(data.x)>=0 and int(data.x)<GRID_W and int(data.z)>=0 and int(data.z)<GRID_H and int(data.get("rotation",0))>=0 and int(data.get("rotation",0))<=3

func _is_int(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and absf(float(value))<1.0e12

func _number_in(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high

func _has_name_control(value: String) -> bool:
	for index: int in range(value.length()):
		var codepoint: int=value.unicode_at(index)
		if codepoint<32 or codepoint==127: return true
	return false

func _safe_value(value: Variant, depth: int = 0) -> bool:
	if depth>8: return false
	if value is float: return is_finite(value)
	if value is String: return value.length()<=4096
	if value is Dictionary:
		if value.size()>100: return false
		for key: Variant in value:
			if not key is String or not _safe_value(value[key],depth+1): return false
		return true
	if value is Array:
		if value.size()>2048: return false
		for item: Variant in value:
			if not _safe_value(item,depth+1): return false
		return true
	return value==null or value is int or value is bool

func _valid_saved_state(data: Dictionary) -> bool:
	if not _safe_value(data): return false
	for key: String in ["schema","seed","revision","day","speed","next_id","next_event","level","days_played"]:
		if not _is_int(data.get(key)): return false
	if int(data.schema)!=1 or int(data.day)<1 or int(data.revision)<0 or not [0,1,2,4].has(int(data.speed)): return false
	if int(data.next_id)<1 or int(data.next_event)<1 or int(data.level)<1 or int(data.level)>3 or int(data.days_played)<0: return false
	for key: String in ["cash","debt","rent","day_progress","reputation","lifetime_income","daily_income","daily_expenses","daily_profit"]:
		if not (data.get(key) is int or data.get(key) is float) or not is_finite(float(data[key])): return false
	if not _number_in(data.debt,0,MAX_DEBT) or not _number_in(data.rent,25,350) or not _number_in(data.day_progress,0,0.999999999999) or not _number_in(data.reputation,0,100): return false
	if absf(float(data.cash))>1.0e10 or float(data.lifetime_income)<0.0: return false
	if not data.get("park_name") is String or str(data.park_name).strip_edges().length()<2 or str(data.park_name).length()>32 or _has_name_control(str(data.park_name)): return false
	if not data.get("rng_state") is String or not str(data.rng_state).is_valid_int(): return false
	if not data.get("buildings") is Array or data.buildings.size()>1024 or not data.get("roads") is Array or data.roads.size()>GRID_W*GRID_H: return false
	if not data.get("owned") is Array or data.owned.is_empty() or data.owned.size()>6: return false
	if not data.get("events") is Array or data.events.size()>3 or not data.get("ledger") is Array or data.ledger.size()>80 or not data.get("stats") is Dictionary: return false
	var owned: Dictionary = {}
	for parcel: Variant in data.owned:
		if not _is_int(parcel) or int(parcel)<0 or int(parcel)>5 or owned.has(int(parcel)): return false
		owned[int(parcel)]=true
	var occupied_cells: Dictionary = {}
	var road_cells: Dictionary = {}
	for road: Variant in data.roads:
		if not road is Dictionary or not _coordinates(road): return false
		var cell: Vector2i=Vector2i(int(road.x),int(road.z))
		if road_cells.has(cell) or not owned.has(parcel_at(cell.x,cell.y)): return false
		road_cells[cell]=true
	if not road_cells.has(Vector2i(0,18)): return false
	var ids: Dictionary = {}
	var homes: int = 0
	for building: Variant in data.buildings:
		if not building is Dictionary or not _coordinates(building): return false
		if not building.get("kind") is String or not CATALOG.has(str(building.kind)) or str(building.kind)=="road": return false
		if not _is_int(building.get("id")) or int(building.id)<1 or ids.has(int(building.id)) or int(building.id)>=int(data.next_id): return false
		ids[int(building.id)]=true
		for key: String in ["level","vacant_days","unhappy_days"]:
			if not _is_int(building.get(key)) or int(building[key])<0: return false
		if int(building.level)<1 or int(building.level)>3: return false
		for key: String in ["condition","happiness"]:
			if not _number_in(building.get(key),0,100): return false
		if not _number_in(building.get("budget"),25,1000) or not _number_in(building.get("arrears"),0,1.0e9): return false
		if not building.get("occupied") is bool or not building.get("household") is String or not building.get("connected") is bool or not building.get("services") is Dictionary: return false
		if str(building.kind)!="trailer" and bool(building.occupied): return false
		if str(building.kind)=="trailer": homes+=1
		var size: Vector2i=footprint(str(building.kind),int(building.rotation))
		for cx: int in range(int(building.x),int(building.x)+size.x):
			for cz: int in range(int(building.z),int(building.z)+size.y):
				var cell: Vector2i=Vector2i(cx,cz)
				if cx>=GRID_W or cz>=GRID_H or not owned.has(parcel_at(cx,cz)) or occupied_cells.has(cell) or road_cells.has(cell): return false
				occupied_cells[cell]=true
	if homes>MAX_LOTS: return false
	var event_ids: Dictionary={}
	for event: Variant in data.events:
		if not event is Dictionary or not _is_int(event.get("id")) or int(event.id)<1 or int(event.id)>=int(data.next_event) or event_ids.has(int(event.id)): return false
		event_ids[int(event.id)]=true
		if not event.get("title") is String or not event.get("description") is String or not event.get("choices") is Array or event.choices.size()!=3: return false
		for choice: Variant in event.choices:
			if not choice is Dictionary or not choice.get("label") is String or not choice.get("effect") is String or not _number_in(choice.get("cost"),-10000,10000): return false
			if not ["clean","support","service","volunteer","permit","enforce","ignore","patch","breakdown"].has(str(choice.effect)): return false
	for entry: Variant in data.ledger:
		if not entry is Dictionary or not _is_int(entry.get("day")) or not entry.get("text") is String or not entry.get("actor") is String or not _number_in(entry.get("amount"),-1.0e10,1.0e10): return false
	return true

func _ok(message: String) -> Dictionary:
	return {"ok":true,"message":message}

func _failure(message: String) -> Dictionary:
	return {"ok":false,"message":message}
