private["_enabled","_lastsent","_fps","_fps_count"];
_enabled = if ((missionNamespace getVariable "WFBE_C_AI_DELEGATION") > 0) then {true} else {false};
_lastsent = time;
_fps = 0;
_fps_count = 0;
if (_enabled) then {
  while{!gameOver}do{
    sleep 5;
    _fps = _fps + diag_fps;
    _fps_count = _fps_count + 1;
    if (time - _lastsent > (missionNamespace getVariable "WFBE_C_AI_DELEGATION_FPS_INTERVAL")) then { //--- Send the FPS Avg to the server.
      ["RequestSpecial", ["update-clientfps", getPlayerUID(player), round(_fps / _fps_count), true]] Call WFBE_CO_FNC_SendToServer;
      _lastsent = time;
      _fps_count = 0;
      _fps = 0;
    };
  };
};
