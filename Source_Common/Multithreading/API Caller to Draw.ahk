;This file contains functions inside the main thread. Those functions call other functions in the thread "Draw"

API_Draw_Draw()
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_flows[FlowID].draw.mustDraw := true
	
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
}
