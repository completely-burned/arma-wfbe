private["_r","_a","_c","_n","_chunk","_chunk_last","_time_admit","_time_lost"];

//-- Время, которое Нужно учитывать.
_time_admit = _this select 0;

_a = gosa_fps_array;
_c = count _a;
_n = _c -1;

//-- Куски, первый и последний.
_chunk = _a select 0;
_chunk_last = _a select _n;

//-- Время, которое Можно учитывать.
_time_lost = ((_chunk_last select 0) - (_chunk select 0));

// Ошибки данных.
if (_time_admit >= _time_lost or _time_admit < 0 or _time_lost <= 0) then {
	_r = [_time_lost, (_chunk_last select 1) - (_chunk select 1)];

}else{
	private["_time_first"];
	//_n = round (_c - (_c*(_time_admit/_time_lost)));
		// Так с первой попытки нужный кусок найдется, нет.

	//-- Время, которое должно быть у начального куска.
		//-- Точное _time_first отсутствует в массиве _a обычно,
		//-- оно чуть меньше/больше начального куска.
	_time_first = ((_chunk_last select 0) - _time_admit);

	//-- Ищем начальный кусок.
	while {isNil "_r"} do {
		_chunk = _a select round _n;

		// TODO: Улучшить точность.
		if (_c > 1) then {
			_c = (_c/2);
			if (_time_first > (_chunk select 0)) then {
				_n = _n+_c;
			}else{
				_n = _n-_c;
			};
		}else{
			_r = [(_chunk_last select 0) - (_chunk select 0),
						(_chunk_last select 1) - (_chunk select 1)];
		};

	}; // while

};

_r;
