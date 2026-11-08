extends RefCounted
## Reproducible developed-park fixture for simulation, rendering and networking
## checks. The development grant is fixture-only; normal play starts at $28,000.

static func build(park: Node, days: int = 30) -> Dictionary:
	park.reset(64040)
	park.state.cash = 250000.0
	park.state.park_name = "Gravel Pines · Developed"
	for parcel: int in [1,2,4,5]:
		_require(park,"buy_land",{"parcel":parcel})
	for x: int in range(48):
		_road(park,x,18)
	for x: int in [6,22,38]:
		for z: int in range(2,34):
			_road(park,x,z)
	for x: int in [3,7]:
		_require(park,"place",{"kind":"trailer","x":x,"z":33})
	for z: int in [3,7,11,15,21,25,29,33]:
		for x: int in [19,23]:
			_require(park,"place",{"kind":"trailer","x":x,"z":z})
	for z: int in [3,7,11,15,21,25,29]:
		for x: int in [35,39]:
			_require(park,"place",{"kind":"trailer","x":x,"z":z})
	# Existing utilities reach 28 homes at level three, plus twelve from each
	# new facility. Services reach 32 plus sixteen, covering all forty homes.
	for building: Dictionary in park.state.buildings.duplicate():
		if ["power","water","sewage","trash","maintenance"].has(str(building.kind)):
			_require(park,"upgrade",{"id":int(building.id)})
			_require(park,"upgrade",{"id":int(building.id)})
	for facility: Array in [["power",36,33],["water",39,33],["sewage",43,19],["trash",46,19],["maintenance",43,16],["laundry",27,19]]:
		_require(park,"place",{"kind":str(facility[0]),"x":int(facility[1]),"z":int(facility[2])})
	for day: int in range(maxi(days,8)):
		park.step_day()
	_require(park,"place",{"kind":"store","x":27,"z":16})
	for item: Array in [["tree",12,4],["tree",12,8],["lamp",10,17],["lamp",26,17],["lamp",42,17],["tree",29,4],["tree",45,4],["tree",29,26],["tree",45,26],["fence",10,3],["fence",26,3],["fence",42,3]]:
		_require(park,"place",{"kind":str(item[0]),"x":int(item[1]),"z":int(item[2])})
	return park.snapshot()

static func _road(park: Node, x: int, z: int) -> void:
	for road: Dictionary in park.state.roads:
		if int(road.x)==x and int(road.z)==z:
			return
	_require(park,"place",{"kind":"road","x":x,"z":z})

static func _require(park: Node, action: String, data: Dictionary) -> void:
	var result: Dictionary = park.apply_command(action,data,"Development fixture")
	assert(bool(result.get("ok",false)),"Developed fixture command failed: %s %s — %s" % [action,str(data),str(result)])
