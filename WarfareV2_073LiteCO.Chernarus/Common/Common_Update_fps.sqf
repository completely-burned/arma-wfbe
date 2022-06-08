/*
	Среднее значение FPS.
	TODO: Нужна проверка.
*/

private["_interval","_sleep","_uid","_hc","_fnc","_f"];

gosa_fps_array = [[time, diag_frameno]];
gosa_fps_array_size = 256;

_interval = missionNamespace getVariable "WFBE_C_AI_DELEGATION_FPS_INTERVAL";
_sleep = 15;

if (isServer) then {
	waitUntil{!isNil "serverInitComplete"};
	waitUntil{serverInitComplete};
	_fnc = {
		missionNamespace setVariable ["WFBE_AI_DELEGATION_SERVER", _this];
	};
} else {
	_uid = getPlayerUID player;
	_hc = !hasInterface;
	waitUntil{!isNil "clientInitComplete"};
	waitUntil{clientInitComplete};
	_fnc = {
		["RequestSpecial",
			["update-clientfps", _uid, _this, _hc]
		] Call WFBE_CO_FNC_SendToServer;
	};
};

["INITIALIZATION", "Common_Update_fps.sqf: is loaded."] Call WFBE_CO_FNC_LogContent;

while{true}do{
	sleep _sleep;
	[time,diag_frameno] call gosa_FNC_AddFPS;
	_f = [_interval] call gosa_FNC_GetFPS;
	_f = round((_f select 1) / (_f select 0));
	_f call _fnc;
};
