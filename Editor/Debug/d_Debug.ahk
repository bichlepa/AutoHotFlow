d_debug()
{
	global
	loop 100
	{
		if RunningIDs%A_Index%!=
			RunningIDs%A_Index%=
		if allElements%A_Index%!=
			allElements%A_Index%=
		if allTriggers%A_Index%!=
			allTriggers%A_Index%=
		if markedElements%A_Index%!=
			markedElements%A_Index%=
		if localVariables%A_Index%!=
			localVariables%A_Index%=
		if OldRunningIDs%A_Index%!=
			OldRunningIDs%A_Index%=
	}
	for count, temp in RunningIDs
	{
		RunningIDs%count%:=temp
	}
	for count, temp in allElements
	{
		allElements%count%:=temp
	}
	for count, temp in allTriggers
	{
		allTriggers%count%:=temp
	}
	for count, temp in markedElements
	{
		markedElements%count%:=temp
	}
	for count, temp in localVariables
	{
		localVariables%count%:=temp
	}
	for count, temp in OldRunningIDs
	{
		OldRunningIDs%count%:=temp
	}
	MsgBox,debugging
}

