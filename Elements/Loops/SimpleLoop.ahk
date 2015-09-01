iniAllLoops.="SimpleLoop|" ;Add this loop to list of all loops on initialisation

runLoopSimpleLoop(InstanceID,ThreadID,ElementID,ElementIDInInstance,HeadOrTail)
{
	global

	if HeadOrTail=Head ;Initialize loop
	{
		
		
		v_SetVariable(InstanceID,ThreadID,"A_Index",1,,c_SetLoopVar)
		
		
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normalHead")
	}
	else if HeadOrTail=tail ;Continue loop
	{
		tempindex:=v_GetVariable(InstanceID,ThreadID,"A_Index")
		
		if (%ElementID%Infinite =1 || tempindex < v_EvaluateExpression(InstanceID,ThreadID,%ElementID%repeatCount)) ;If infinite loop or index has not reached the aim value
		{
			v_SetVariable(InstanceID,ThreadID,"A_Index",tempindex+1,,c_SetLoopVar)
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
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Unexpected Error! No information whether the connection lead into head or tail")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("No information whether the connection lead into head or tail") )
		return
	}

	

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
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Repeats")})
	parametersToEdit.push({type: "Checkbox", id: "Infinite", default: 0, label: lang("Endless loop")})
	parametersToEdit.push({type: "Edit", id: "repeatCount", default: 5, content: "Expression", WarnIfEmpty: true})

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


CheckSettingsLoopSimpleLoop(ID)
{
	if (GUISettingsOfElement%ID%Infinite = 1)
	{
		GuiControl,Disable,GUISettingsOfElement%ID%repeatCount
		
	}
	else
	{
		GuiControl,Enable,GUISettingsOfElement%ID%repeatCount
	}
	
}