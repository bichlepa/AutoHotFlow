API_Call_Draw_Draw()
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	retval := Draw()
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}