/*
	AI Delegation Specific Functions.
	 Scope: Server.
*/

/*
	Delegate Town AI creation to client with failover.
	 Parameters:
		- Town
		- Side
		- Groups
		- Spawn positions
		- Groups
*/
WFBE_SE_FNC_DelegateAITown = {
	Private ["_groups", "_positions", "_side", "_teams", "_town", "_town_teams", "_town_vehicles"];

	_town = _this select 0;
	_side = _this select 1;
	_groups = +(_this select 2);
	_positions = +(_this select 3);
	_teams = +(_this select 4);

	_town_teams = [];
	_town_vehicles = [];

	_delegators = (count _groups) call WFBE_SE_FNC_GetDelegators; //--- Get the delegators.

	diag_log format["DEBUG DELEGATION::  DelegateAITown.sqf Delegators: %1", _delegators];

	//--- Delegate units and create units on the server if we don't have enough delegators.
	for '_i' from 0 to count(_groups)-1 do {
		if (_i < count _delegators) then {
			Private ["_uid"];
			_uid = getPlayerUID(_delegators select _i);
			if !(WF_A2_Vanilla) then {
				[_delegators select _i, "HandleSpecial", ['delegate-townai', _town, _side, [_groups select _i], [_positions select _i], [_teams select _i]]] Call WFBE_CO_FNC_SendToClient;
			} else {
				[_uid, "HandleSpecial", ['delegate-townai', _town, _side, [_groups select _i], [_positions select _i], [_teams select _i]]] Call WFBE_CO_FNC_SendToClients;
			};
			[_uid, "increment"] Call WFBE_SE_FNC_DelegationOperate; //--- Increment the group count for that client.
			[_uid, _teams select _i] Spawn WFBE_SE_FNC_DelegationTracker; //--- Track a group until it's nullification.
			["INFORMATION", Format["Server_DelegateAITown.sqf: [%1] Town [%2] Units [%3] in group [%4] were delegated to client [%5].", _side, _town, _groups select _i, _teams select _i, name (_delegators select _i)]] Call WFBE_CO_FNC_LogContent;

			_groups set [_i, "**NIL**"];
			_positions set [_i, "**NIL**"];
			_teams set [_i, "**NIL**"];
		};
	};

	_groups = _groups - ["**NIL**"];
	_positions = _positions - ["**NIL**"];
	_teams = _teams - ["**NIL**"];

	if (count _groups > 0) then { //--- Some units left for the server to create?
		_retVal = [_town, _side, _groups, _positions, _teams] call WFBE_CO_FNC_CreateTownUnits;
		_town_teams = _town_teams + (_retVal select 0);
		_town_vehicles = _town_vehicles + (_retVal select 1);
	};

	[_town_teams, _town_vehicles]
};

/*
	Operate a delegator groups count.
	 Parameters:
		- Client UID.
		- Operate (increment/decrement).
*/
WFBE_SE_FNC_DelegationOperate = {
	Private ["_delegator", "_get", "_uid"];

	_uid = _this select 0;
	_operation = _this select 1;

	_get = missionNamespace getVariable format["WFBE_AI_DELEGATION_%1", _uid];
	if !(isNil '_get') then {
		switch (_operation) do { //--- Operate.
			case "increment": {_get set [1, (_get select 1) + 1]};
			case "decrement": {_get set [1, if ((_get select 1) > 0) then {(_get select 1) - 1} else {0}]};
		};
		missionNamespace setVariable [format["WFBE_AI_DELEGATION_%1", _uid], _get];
	};
};

/*
	Track the delegation of a group.
	 Parameters:
		- Client UID.
		- Group.
*/
WFBE_SE_FNC_DelegationTracker = {
	Private ["_delegator", "_group", "_uid"];

	_uid = _this select 0;
	_group = _this select 1;
	_id = (_uid) Call WFBE_SE_FNC_GetDelegatorID;

	while {!isNull _group} do {sleep 5};

	if (_id == (_uid Call WFBE_SE_FNC_GetDelegatorID)) then { //--- Only decrement if the session ID is the same (make sure that the player didn't disconnect in the meanwhile).
		[_uid, "decrement"] Call WFBE_SE_FNC_DelegationOperate; //--- Increment the group count for that client.
	};
};

/*
	Return the session ID of a delegator.
	 Parameters:
		- Client UID.
*/
WFBE_SE_FNC_GetDelegatorID = {
	Private ["_get", "_id", "_uid"];

	_uid = _this;

	_get = missionNamespace getVariable format["WFBE_AI_DELEGATION_%1", _uid];
	_id = if !(isNil '_get') then {_get select 2} else {-1};

	_id
};

/*
	Get the available delegators.
	 Parameters:
		- Count.
*/
WFBE_SE_FNC_GetDelegators = {
	// TODO: Нужно учитывать растояние до игрока.
	// TODO: Уровни логирования.
	private["_amount","_count","_delegators","_cl_limit_fps","_get","_medium",
		"_cl_limit_grpoups","_unit","_units","_cl_fps_total","_hc_fps_total",
		"_sv_fps","_cl_units","_hc_units","_tmp","_must","_now","_new","_fps",
		"_hc","_obj"];

	//-- args
	_count = _this;

	//-- dynamic
	// TODO: _sv_fps = diag_fps временное решение, среднее значение fps нужно сделать должным образом.
	_sv_fps = diag_fps;
	//_sv_fps = [missionNamespace getVariable "WFBE_C_AI_DELEGATION_FPS_INTERVAL"] call gosa_fps_getAVG;
	_cl_limit_grpoups = missionNamespace getVariable "WFBE_C_AI_DELEGATION_GROUPS_MAX";
	_cl_limit_fps = missionNamespace getVariable "WFBE_C_AI_DELEGATION_FPS_MIN";

	//-- static
	_hc_fps_total = 0;
	_cl_fps_total = 0;
	_hc_units = [];
	_cl_units = [];
	_delegators = [];
	_amount = 1;

	//-- Подготовка.
		_units = if (isMultiplayer) then {playableUnits} else {switchableUnits};
		// Нужно узнать _fps_total для начала.
		for "_i" from 0 to (count _units -1) do {
			_unit = _units select _i;
			["INFORMATION", Format["gosa_SE_FNC_GetDelegators: unit:%1, uid:%2", _unit, getPlayerUID _unit]] Call WFBE_CO_FNC_LogContent;
			if (isPlayer _unit) then {
				_get = missionNamespace getVariable format["WFBE_AI_DELEGATION_%1",
					getPlayerUID _unit];
				if !(isNil '_get') then {
					["INFORMATION", Format["gosa_SE_FNC_GetDelegators: unit:%1, var:%2", _unit, _get]] Call WFBE_CO_FNC_LogContent;
					if (count _get > 3) then {
						if (_get select 3) then {
							_hc_fps_total = _hc_fps_total + (_get select 0);
							_tmp = [_unit, _get select 0, _get select 1, _get select 2, _get select 3];
							if (random 10 < 5) then {
								_hc_units set [count _hc_units, _tmp];
							}else{
								_hc_units = [_tmp] + _hc_units;
							};
						};
					}else{
						if ((_get select 0) >= _cl_limit_fps) then {
							_cl_fps_total = _cl_fps_total + (_get select 0);
							_tmp = [_unit, _get select 0, _get select 1, _get select 2, false];
							if (random 10 < 5) then {
								_cl_units set [count _cl_units, _tmp];
							}else{
								_cl_units = [_tmp] + _cl_units;
							};
						};
					};
				};
			};
		};
		["INFORMATION", Format["gosa_SE_FNC_GetDelegators: units: %1 -> %2+%3",_units,_hc_units,_cl_units]] Call WFBE_CO_FNC_LogContent;
		_units = _hc_units+_cl_units;

	//-- Среднее.
		_medium = (_hc_fps_total * gosa_load_balancing_hc)
			+ (_cl_fps_total * gosa_load_balancing_cl)
			+ (_sv_fps * gosa_load_balancing_sv);
		_medium = _medium / _count;
		["INFORMATION", Format["gosa_SE_FNC_GetDelegators: medium: %1, need: %2, sv: %3, hc: %4, cl: %5",
			_medium,_count,_sv_fps,[_hc_fps_total,count _hc_units],[_cl_fps_total,count _cl_units]]
			] Call WFBE_CO_FNC_LogContent;

	// TODO: Оптимизировать.
	while {count _units > 0 && count _delegators < _count
		//&& _amount <= _cl_limit_grpoups
	}do {
		["INFORMATION", Format["gosa_SE_FNC_GetDelegators: amount:%1",_amount]] Call WFBE_CO_FNC_LogContent;
		for '_i' from 0 to (count _units -1) do {
			_unit = _units select _i;
			["INFORMATION", Format["gosa_SE_FNC_GetDelegators: unit:%1", [_i,_unit]]] Call WFBE_CO_FNC_LogContent;
			_obj = _unit select 0;
			_fps = _unit select 1;
			_now = _unit select 2;
			_hc = _unit select 4;
			if (count _unit > 5) then {
				_must = _unit select 5;
			} else {
				if (_hc) then {
					_must = _fps * gosa_load_balancing_hc / _medium;
				} else {
					_must = _fps * gosa_load_balancing_cl / _medium;
				};
				["INFORMATION", Format["gosa_SE_FNC_GetDelegators: unit:%1, set must:%2", [_i,_unit], _must]] Call WFBE_CO_FNC_LogContent;
			};

			// TODO: Нужно учитывать float.

			if (count _unit > 6) then {
				_new = (_unit select 6);
			}else{
				_new = 0;
			};

			if ((_must > 0) && {((_now + _new) <= _cl_limit_grpoups)}) then {
				//if ((_get select 1) < _amount) then { //--- Progressive checks to prevent client overloading.
					_delegators set [count _delegators, _obj];
					["INFORMATION", Format["gosa_SE_FNC_GetDelegators: delegators+[%1]", _unit]] Call WFBE_CO_FNC_LogContent;
					_unit set [5, _must -1];
					_unit set [6, _new +1];
				//};
			} else {
				_units set [_i, "**NIL**"];
			};

			if (count _delegators >= _count) exitWith {
				["INFORMATION", Format["gosa_SE_FNC_GetDelegators: count _delegators >= _count exitWith", nil]] Call WFBE_CO_FNC_LogContent;
			};
		};// for

		_units = _units - ["**NIL**"];
		_amount = _amount + 1;
	};// while

	_delegators
};
