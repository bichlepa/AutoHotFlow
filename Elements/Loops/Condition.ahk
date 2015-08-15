iniAllLoops.="Condition|" ;Add this loop to list of all loops on initialisation

runLoopCondition(InstanceID,ThreadID,ElementID,ElementIDInInstance,HeadOrTail)
{
	global
	
	
	if HeadOrTail=Head ;Initialize loop
	{
		
		v_SetVariable(InstanceID,ThreadID,"A_Index",1,,c_SetLoopVar)
		if (%ElementID%EvaluateOnFirstIteration =0 || v_EvaluateExpression(InstanceID,ThreadID,%ElementID%Expression))
		{
			
			
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normalHead")
		}
		else
		{
			
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normalTail")
		}
		
	}
	else if HeadOrTail=tail ;Continue loop
	{
		tempindex:=v_GetVariable(InstanceID,ThreadID,"A_Index")
		v_SetVariable(InstanceID,ThreadID,"A_Index",tempindex+1,,c_SetLoopVar)
		
		if (v_EvaluateExpression(InstanceID,ThreadID,%ElementID%Expression)) ;If infinite loop or index has not reached the aim value
		{
			
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
getNameLoopCondition()
{
	return lang("Conditional loop") 
}
getCategoryLoopCondition()
{
	return lang("Variable") "|" lang("General")
}

getParametersLoopCondition()
{
	global
	
	parametersToEdit:=[ "Label|" lang("Condition"),"text|a_index <= 5|Expression", "Checkbox|1|EvaluateOnFirstIteration|" lang("Evaluate on first iteration")]
	return parametersToEdit
}

GenerateNameLoopCondition(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	return lang("Conditional loop") ": "  lang("Until") " " GUISettingsOfElement%id%Expression 
	
}


