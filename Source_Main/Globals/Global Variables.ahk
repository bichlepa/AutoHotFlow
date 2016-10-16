
init_GlobalVars()
{
	global
	_flows := CriticalObject()
	_settings := CriticalObject()
	_execution := CriticalObject()
	_GlobalVars := CriticalObject()
	_share := CriticalObject()
	_language := CriticalObject()
	
	_share.hwnds := Object()
	
	CriticalSection_Flows := CriticalSection()
}