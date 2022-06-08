private["_a","_c","_l"];
// Копия, чтобы `_a set [0,-1];` не влиял на глобальную переменную. TODO: Нужно оптимизировать.
_a =+ gosa_fps_array;
_c = count _a;
_l = _a select (_c -1);

// Можно не добавлять если разница во времени очень мала.
if ((_l select 0)+0.5 < (_this select 0)) then {
	//private["_s"];
	// `2^n` поск использует `/2`.
	//_s = 2048;
	if (_c >= gosa_fps_array_size) then {
		_a set [0,-1];
		_a = _a -[-1];
		_c = _c -1;
	};

	//-- Добавляем в конец.
	_a set [_c, _this];
	gosa_fps_array = _a;
};
