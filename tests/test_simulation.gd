extends SceneTree

const ParkScript = preload("res://scripts/sim/park_state.gd")
const DevelopedPark = preload("res://tests/populated_park.gd")
var park: Node
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	park = ParkScript.new()
	root.add_child(park)
	park.reset(31415)
	_test_starting_park()
	_test_placement_and_transactions()
	_test_relocation_and_rotation()
	_test_roads_and_services()
	_test_road_paths()
	_test_land_and_capacity()
	_test_economy_and_households()
	_test_events_and_repairs()
	_test_save_and_determinism()
	_test_malformed_saves()
	_test_park_names()
	_test_developed_park()
	if failures.is_empty():
		print("SIMULATION_TESTS_PASSED: %d checks" % checks)
	else:
		for failure: String in failures:
			push_error(failure)
		print("SIMULATION_TESTS_FAILED: %d of %d checks" % [failures.size(),checks])
	park.queue_free()
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _accepted(action: String, data: Dictionary) -> Dictionary:
	var result: Dictionary = park.apply_command(action,data,"Test manager")
	_check(bool(result.get("ok",false)), "%s should succeed: %s" % [action,str(result)])
	return result

func _rejected(action: String, data: Dictionary) -> void:
	var before: Dictionary = park.snapshot()
	var result: Dictionary = park.apply_command(action,data,"Test manager")
	_check(not bool(result.get("ok",true)), "%s should be rejected" % action)
	_check(park.snapshot()==before, "Rejected %s command must be transactional" % action)

func _test_starting_park() -> void:
	var info: Dictionary = park.metrics()
	_check(int(info.lots)==8 and int(info.occupied)==8,"Starting park has eight occupied homes")
	_check(int(info.power.capacity)==12 and int(info.water.capacity)==12 and int(info.sewage.capacity)==12,"Initial utility capacities serve twelve homes")
	_check(int(info.connected_lots)==8,"All starting homes have entrance-connected roads")
	_check(float(info.profit)>0.0,"Initial economy has a viable operating surplus")
	_check(park.connected_roads().size()==park.state.roads.size(),"Every initial road joins the entrance")
	for building: Dictionary in park.state.buildings:
		_check(bool(building.connected),"Each initial building has road access")
	var initial_save: Dictionary=park.snapshot()
	_check(park.restore(initial_save),"Fresh park state passes strict restore")

func _test_placement_and_transactions() -> void:
	park.reset(31415)
	var cash: float=float(park.state.cash)
	_accepted("place",{"kind":"tree","x":12,"z":3,"rotation":0})
	_check(float(park.state.cash)==cash-75.0,"Construction deducts exactly its catalog cost")
	_rejected("place",{"kind":"tree","x":12,"z":3,"rotation":0})
	_rejected("place",{"kind":"trailer","x":3,"z":3,"rotation":0})
	_rejected("place",{"kind":"tree","x":16,"z":3})
	_rejected("place",{"kind":"unknown","x":12,"z":5})
	_rejected("place",{"kind":"tree","x":-1,"z":5})
	_rejected("place",{"kind":"tree","x":12.5,"z":5})
	_rejected("place",{"kind":"tree","x":12,"z":5,"rotation":0.5})
	_rejected("place",{"kind":"tree","x":12,"z":5,"rotation":4})
	_rejected("place",{"kind":"store","x":11,"z":23})
	_rejected("loan",{"amount":-1000})
	_rejected("loan",{"amount":1500})
	_rejected("set_rent",{"value":NAN})
	_rejected("set_rent",{"value":INF})
	_rejected("speed",{"value":3})
	_rejected("rename",{"name":12})
	_rejected("unknown",{})
	var cash_before_unknown: float=float(park.state.cash)
	_accepted("place",{"kind":"tree","x":12,"z":9,"cash":999999,"owned":[0,1,2,3,4,5],"id":300})
	_check(float(park.state.cash)==cash_before_unknown-75.0 and park.state.owned==[0,3],"Unknown command fields cannot overwrite treasury or ownership")
	_accepted("set_rent",{"value":125,"debt":-10000,"cash":999999})
	_check(float(park.state.debt)==0.0 and not park.state.has("id"),"Only explicitly supported command fields are applied")
	park.state.cash=75.0
	_accepted("place",{"kind":"tree","x":12,"z":5})
	_rejected("place",{"kind":"tree","x":12,"z":7})
	_check(float(park.state.cash)==0.0,"Sequential simultaneous purchase requests cannot overspend")
	park.reset(31415)
	_rejected("place",{"kind":"trailer","x":10,"z":17,"rotation":0})

func _test_roads_and_services() -> void:
	park.reset(31415)
	_rejected("demolish",{"x":0,"z":18})
	_rejected("demolish",{"x":6,"z":19})
	_rejected("demolish",{"id":1})
	_accepted("place",{"kind":"road","x":15,"z":17})
	_accepted("demolish",{"x":15,"z":17})
	# An isolated home can be constructed but cannot attract a household.
	_accepted("place",{"kind":"trailer","x":11,"z":3})
	var home: Dictionary=park.building_at(11,3)
	_check(not bool(home.connected),"An isolated home has no road connection")
	for day: int in range(6): park.step_day()
	_check(not bool(home.occupied),"A disconnected home remains vacant")
	# Connect its lot to the main trunk along its lower edge.
	for x: int in range(7,14):
		_accepted("place",{"kind":"road","x":x,"z":5})
	_check(bool(home.connected),"A connected access road activates the home")
	_check(bool(home.services.power) and bool(home.services.water) and bool(home.services.sewage),"A road connection carries available utility services")
	for day: int in range(8): park.step_day()
	_check(bool(home.occupied),"A viable, affordable home attracts a household")
	var power: Dictionary={}
	for building: Dictionary in park.state.buildings:
		if str(building.kind)=="power": power=building; break
	power.condition=10.0
	park.apply_command("set_rent",{"value":125})
	_check(int(park.metrics().power.capacity)==0 and int(park.metrics().water.capacity)==0,"Power failure disables powered utilities")
	for day: int in range(5): park.step_day()
	_check(int(park.metrics().occupied)==0,"Persistent essential-service failure causes households to leave")
	_accepted("repair",{"id":int(power.id)})
	_check(int(park.metrics().water.capacity)>0,"Repairing power restores the water network")

func _test_relocation_and_rotation() -> void:
	park.reset(31415)
	_rejected("move",{"id":1,"x":3,"z":3,"rotation":0})
	_rejected("move",{"id":1,"x":7,"z":3,"rotation":0})
	_rejected("move",{"id":1,"x":11,"z":3,"rotation":0})
	_check(park.footprint("trailer",1)==Vector2i(2,3),"Quarter-turn rotation swaps lot footprint dimensions")
	_accepted("place",{"kind":"trailer","x":11,"z":21,"rotation":1})
	var home: Dictionary=park.building_at(11,23)
	_check(not home.is_empty() and int(home.rotation)==1,"Rotated footprint selects the full building")
	_check(park.building_at(13,21).is_empty(),"Rotated footprint does not occupy its original width")
	var id_value: int=int(home.id)
	_accepted("move",{"id":id_value,"x":11,"z":25,"rotation":0})
	_check(park.building_at(11,21).is_empty() and int(park.building_at(13,26).id)==id_value,"Relocation updates occupied cells and keeps the stable identifier")
	var preview: Dictionary=park.validate_move(id_value,12,25,0)
	_check(bool(preview.ok) and float(preview.cost)==278.0,"Move preview ignores the source footprint and quotes the relocation fee")
	_check(not bool(park.validate_move(id_value,15,25,1).ok),"Rotated relocation still rejects geometry outside purchased land")
	_accepted("move",{"id":id_value,"x":12,"z":25,"rotation":0})
	var projected: float=float(park.metrics().income)
	_accepted("upgrade",{"id":1})
	_check(is_equal_approx(float(park.metrics().income)-projected,15.0),"Upgraded home rent appears in projected income")
	_accepted("demolish",{"id":id_value})
	_check(park.building_at(11,25).is_empty(),"Eligible vacant buildings can be removed")

func _test_road_paths() -> void:
	park.reset(31415)
	var existing_path: Array=[{"x":0,"z":18},{"x":1,"z":18},{"x":2,"z":18}]
	var quoted: Dictionary=park.validate_road_path(existing_path)
	_check(bool(quoted.ok) and float(quoted.cost)==0.0 and int(quoted.count)==0,"Existing road cells are not charged again")
	var before: Dictionary=park.snapshot()
	_accepted("road_path",{"points":existing_path})
	_check(park.snapshot()==before,"An already-built road path does not change treasury, revision or ledger")
	_rejected("road_path",{"points":[{"x":15,"z":18},{"x":16,"z":18}]})
	_rejected("road_path",{"points":[{"x":6,"z":3},{"x":7,"z":3}]})
	_rejected("road_path",{"points":[{"x":12,"z":4},{"x":14,"z":4}]})
	_rejected("road_path",{"points":[{"x":12.5,"z":4}]})
	_rejected("road_path",{"points":[{"x":NAN,"z":4}]})
	_rejected("road_path",{"points":[{"x":12,"z":4},"not a cell"]})
	_rejected("road_path",{"points":[]})
	_rejected("road_path",{"points":"not a path"})
	var too_long: Array=[]
	for index: int in range(97): too_long.append({"x":0,"z":18})
	_rejected("road_path",{"points":too_long})
	_accepted("buy_land",{"parcel":4})
	var path: Array=[{"x":15,"z":18},{"x":16,"z":18},{"x":17,"z":18},{"x":17,"z":18}]
	quoted=park.validate_road_path(path)
	_check(bool(quoted.ok) and int(quoted.count)==2 and float(quoted.cost)==90.0,"Road preview quotes only distinct newly constructed cells")
	var cash: float=float(park.state.cash)
	_accepted("road_path",{"points":path})
	_check(float(park.state.cash)==cash-90.0 and park.connected_roads().has(Vector2i(17,18)),"Atomic road path charges once and extends the connected network")
	before=park.snapshot()
	_accepted("road_path",{"points":path})
	_check(park.snapshot()==before,"Retrying the same road path is an unchanged zero-cost success")
	park.state.cash=40.0
	_rejected("road_path",{"points":[{"x":17,"z":18},{"x":18,"z":18},{"x":19,"z":18}]})

func _test_land_and_capacity() -> void:
	park.reset(114)
	_rejected("buy_land",{"parcel":2})
	_accepted("buy_land",{"parcel":1})
	_check(park.is_owned(16,5),"Purchased land becomes buildable")
	_rejected("buy_land",{"parcel":1})
	# Extend a branch, build ten more homes, and observe capacity rather than a
	# cosmetic service checkbox: only twelve homes receive each essential service.
	for x: int in range(15,32):
		_accepted("place",{"kind":"road","x":x,"z":17})
	for z: int in range(3,17):
		_accepted("place",{"kind":"road","x":22,"z":z})
	for z: int in [3,6,9,12,15]:
		for x: int in [19,23]:
			_accepted("place",{"kind":"trailer","x":x,"z":z})
	var powered: int=0
	for building: Dictionary in park.state.buildings:
		if str(building.kind)=="trailer" and bool(building.services.power): powered+=1
	_check(int(park.metrics().lots)==18,"Expansion can support a larger neighborhood")
	_check(powered==12,"Utility capacity limits service allocation")
	var power_id: int=0
	for building: Dictionary in park.state.buildings:
		if str(building.kind)=="power": power_id=int(building.id); break
	_accepted("loan",{"amount":10000})
	_accepted("upgrade",{"id":power_id})
	_check(int(park.metrics().power.capacity)==20,"Utility upgrades increase capacity")
	_accepted("repay",{"amount":1000})
	_check(float(park.state.debt)==9000.0,"Repayment reduces outstanding principal")
	_rejected("repay",{"amount":10000})

func _test_economy_and_households() -> void:
	park.reset(31415)
	var cash: float=float(park.state.cash)
	park.step_day()
	_check(float(park.state.daily_income)>0.0 and float(park.state.daily_expenses)>0.0,"Rent collection and operating bills are both simulated")
	_check(is_equal_approx(float(park.state.cash),cash+float(park.state.daily_profit)),"Daily cash agrees with net operating result")
	_accepted("loan",{"amount":10000})
	var before_expenses: float=float(park.metrics().expenses)
	_accepted("repay",{"amount":10000})
	_check(is_equal_approx(before_expenses-float(park.metrics().expenses),10.0),"Loan interest is included in projected operating costs")
	_accepted("set_rent",{"value":350})
	for day: int in range(20): park.step_day()
	_check(int(park.metrics().occupied)<8,"Unaffordable rents lower satisfaction and occupancy")
	_accepted("speed",{"value":0})
	var before: Dictionary=park.snapshot()
	park.advance(50.0)
	_check(park.snapshot()==before,"Paused simulation does not advance")
	_accepted("speed",{"value":4})
	var day_before: int=int(park.state.day)
	park.advance(23.0)
	_check(int(park.state.day)>day_before,"Shared speed advances the simulation clock")

func _test_events_and_repairs() -> void:
	park.reset(31415)
	var home: Dictionary=park.building_at(3,3)
	var condition: float=float(home.condition)
	var cost: float=park.repair_cost(home)
	var cash: float=float(park.state.cash)
	_accepted("repair",{"id":int(home.id)})
	_check(float(home.condition)==100.0 and float(park.state.cash)==cash-cost,"Repairs restore condition and charge quoted cost")
	_rejected("repair",{"id":int(home.id)})
	_check(condition<100.0,"Starting homes include realistic maintenance needs")
	for day: int in range(4): park.step_day()
	_check(not park.state.events.is_empty(),"Authored situations arise during management")
	var event: Dictionary=park.state.events[0]
	var event_id: int=int(event.id)
	_rejected("resolve_event",{"id":event_id,"choice":99})
	_accepted("resolve_event",{"id":event_id,"choice":0})
	_rejected("resolve_event",{"id":event_id,"choice":0})
	_check(park.state.events.is_empty(),"A situation is resolved exactly once")

func _test_save_and_determinism() -> void:
	park.reset(937)
	for day: int in range(5): park.step_day()
	park.advance(4.25)
	var saved: Dictionary=park.snapshot()
	var json: String=JSON.stringify(saved)
	for day: int in range(8): park.step_day()
	var expected: Dictionary=park.snapshot()
	park.reset(41)
	var decoded: Variant=JSON.parse_string(json)
	_check(decoded is Dictionary and park.restore(decoded),"JSON-roundtripped saves restore successfully")
	for day: int in range(8): park.step_day()
	_check(_same_json_value(park.snapshot(),expected),"Saved random state reproduces future economy, events, wear and households")
	var copy: Dictionary=park.snapshot()
	copy.buildings[0].condition=0.0
	_check(float(park.state.buildings[0].condition)>0.0,"Snapshots do not alias live state")

func _test_malformed_saves() -> void:
	park.reset(31415)
	var valid: Dictionary=park.snapshot()
	var malformed: Array[Dictionary]=[]
	var data: Dictionary=valid.duplicate(true)
	data.cash=NAN; malformed.append(data)
	data=valid.duplicate(true); data.rng_state="not a generator state"; malformed.append(data)
	data=valid.duplicate(true); data.buildings[0].x=6; malformed.append(data)
	data=valid.duplicate(true); data.buildings[1].id=data.buildings[0].id; malformed.append(data)
	data=valid.duplicate(true); data.buildings[0].condition=-1; malformed.append(data)
	data=valid.duplicate(true); data.buildings[0].occupied="true"; malformed.append(data)
	data=valid.duplicate(true); data.roads.append(data.roads[0].duplicate()); malformed.append(data)
	data=valid.duplicate(true); data.owned=[0,0]; malformed.append(data)
	data=valid.duplicate(true); data.erase("rent"); malformed.append(data)
	data=valid.duplicate(true); data.schema=2; malformed.append(data)
	data=valid.duplicate(true); data.speed=100000; malformed.append(data)
	data=valid.duplicate(true); data.day_progress=INF; malformed.append(data)
	data=valid.duplicate(true); data.buildings[0].rotation=1.5; malformed.append(data)
	for invalid: Dictionary in malformed:
		var before: Dictionary=park.snapshot()
		_check(not park.restore(invalid),"Malformed saves are rejected")
		_check(park.snapshot()==before,"Rejected saves do not alter the live park")

func _same_json_value(a: Variant, b: Variant) -> bool:
	# JSON converts integer variants to doubles and can round the last binary
	# floating-point digit. Compare numerical values to absolute sub-cent precision.
	if (a is int or a is float) and (b is int or b is float):
		return absf(float(a)-float(b))<0.00000001
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _same_json_value(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i: int in range(a.size()):
			if not _same_json_value(a[i],b[i]): return false
		return true
	return a==b

func _test_park_names() -> void:
	park.reset(31415)
	_rejected("rename",{"name":"Moss\nPines"})
	_rejected("rename",{"name":"Moss\tPines"})
	_rejected("rename",{"name":"Moss"+String.chr(127)+"Pines"})
	_rejected("rename",{"name":"Moss"+String.chr(27)+"Pines"})
	_accepted("rename",{"name":"Moss & Maple — 松林"})
	var saved: Dictionary=park.snapshot()
	_check(park.restore(JSON.parse_string(JSON.stringify(saved))) and str(park.state.park_name)=="Moss & Maple — 松林","Unicode park names survive JSON restoration")
	var invalid: Dictionary=saved.duplicate(true)
	invalid.park_name="Moss\nPines"
	var before: Dictionary=park.snapshot()
	_check(not park.restore(invalid) and park.snapshot()==before,"Saved park names containing control characters are rejected transactionally")

func _test_developed_park() -> void:
	var developed: Dictionary=DevelopedPark.build(park,30)
	var info: Dictionary=park.metrics()
	print("DEVELOPED_PARK_METRICS: ",JSON.stringify(info))
	_check(int(info.lots)==40,"A developed park physically accommodates forty trailer footprints")
	_check(int(info.occupied)==40,"All forty viable homes attract and retain households over thirty days")
	_check(int(info.connected_lots)==40,"All forty developed lots connect to the entrance")
	_check(park.connected_roads().size()==park.state.roads.size(),"Every developed road branch is entrance-connected")
	_check(park.state.owned.size()==6,"Full development spans all six purchased land parcels")
	for service: String in ["power","water","sewage","trash","maintenance"]:
		_check(int(info[service].capacity)>=40,"Developed %s capacity meets household demand" % service)
	for building: Dictionary in park.state.buildings:
		if str(building.kind)=="trailer":
			_check(bool(building.services.power) and bool(building.services.water) and bool(building.services.sewage) and bool(building.services.trash) and bool(building.services.maintenance),"Every developed home receives all service allocations")
	_check(float(info.profit)>0.0 and float(info.happiness)>60.0,"Developed park has a working financial and household loop")
	_rejected("place",{"kind":"trailer","x":11,"z":29})
	var encoded: String=JSON.stringify(developed)
	_check(park.restore(JSON.parse_string(encoded)),"Full forty-home developed park passes save validation")
	_check(int(park.metrics().occupied)==40,"Developed occupancy survives JSON save and restore")
	for day: int in range(30): park.step_day()
	_check(int(park.metrics().occupied)==40 and float(park.metrics().profit)>0.0,"Developed park continues operating after restoration")
