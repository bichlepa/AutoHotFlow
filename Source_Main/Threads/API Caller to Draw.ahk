;This file contains functions inside the main thread. Those functions call other functions in the thread "Draw"

API_Draw_Draw()
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	retvalue := AhkThreadDraw.ahkFunction("API_Call_Draw_Draw")
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
}
