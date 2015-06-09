iniAllLoops.="SimpleLoop|" ;Add this loop to list of all loops on initialisation

runLoopSimpleLoop(InstanceID,ThreadID,ElementID,ElementIDInInstance,HeadOrTail)
{
	global

	if HeadOrTail=Head ;Initialize loop
	{
		
		
		v_SetVariable(InstanceID,ThreadID,"A_Index",1,,true)
		
		
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normalHead")
	}
	else if HeadOrTail=tail ;Continue loop
	{
		tempindex:=v_GetVariable(InstanceID,ThreadID,"A_Index")
		
		if (%ElementID%Infinite =1 || tempindex < v_EvaluateExpression(InstanceID,ThreadID,%ElementID%repeatCount)) ;If infinite loop or index has not reached the aim value
		{
			v_SetVariable(InstanceID,ThreadID,"A_Index",tempindex+1,,true)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normalHead")
		}
		else
		{
			
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normalTail")
		}
		
		
		
		
	}
	else if HeadOrTail=break ;Break loop
	{
		
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normalTail")
		
	}
	else
		MsgBox Internal Error. Loop should be executed but there is no information about the connection lead into head or tail.

	

	return
}
getNameLoopSimpleLoop()
{
	return lang("Simple loop")
}
getCategoryLoopSimpleLoop()
{
	return lang("General")
}

getParametersLoopSimpleLoop()
{
	global
	
	parametersToEdit:=["Checkbox|0|Infinite|" lang("Infinite loop") , "Label|" lang("Repeats"),"text|5|repeatCount"]
	return parametersToEdit
}

GenerateNameLoopSimpleLoop(ID)
{
	global
	;MsgBox % %ID%text_to_show
	if GUISettingsOfElement%id%Infinite
		return lang("Simple loop") ": " lang("Infinite loop") 
	else
		return lang("Simple loop") ": " GUISettingsOfElement%id%repeatCount " " lang("Repeats") 
	
}


