iniAllLoops.="Parse_a_string|" ;Add this loop to list of all loops on initialisation

runLoopParse_a_string(InstanceID,ThreadID,ElementID,ElementIDInInstance,HeadOrTail)
{
	global
	local tempVarname
	local OptionOmitChars
	local OptionDelimiters
	local tempError
	local tempFound
	local tempList
	local tempOneElement
	
	
	if HeadOrTail=Head ;Initialize loop
	{
		
		
		tempVarname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
		if %ElementID%expression=1
			temp:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarValue)
		else
			temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
		
		
		
		OptionOmitChars:=v_replaceVariables(InstanceID,ThreadID,%ElementID%OmitChars) 
		OptionDelimiters:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Delimiters) 
		
		tempList:=Object()
		tempFound:=false
		loop,parse,temp,%OptionDelimiters%,%OptionOmitChars%
		{
			tempFound:=true
			tempList.Insert(A_LoopField)
		}
		
		
		
		
		if tempError
		{
			
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
		}
		else if tempFound
		{
			v_SetVariable(InstanceID,ThreadID,"A_LoopCurrentList",tempList,,true)
			v_SetVariable(InstanceID,ThreadID,"A_Index",1,,true)
			
			tempOneElement:=tempList[1]
			tempList.remove(1)
			v_SetVariable(InstanceID,ThreadID,"A_LoopField",tempOneElement,,true)
			
			
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
		tempindex++
		v_SetVariable(InstanceID,ThreadID,"A_Index",tempindex,,true)
		
		tempList:=v_GetVariable(InstanceID,ThreadID,"A_LoopCurrentList")
		
		if tempList.MaxIndex()<1
		{
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normalTail")
			
		}
		else
		{
			tempOneElement:=tempList[1]
			tempList.remove(1)
			v_SetVariable(InstanceID,ThreadID,"A_LoopField",tempOneElement,,true)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normalHead")
			
			
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
getNameLoopParse_a_string()
{
	return lang("Parse_a_string")
}
getCategoryLoopParse_a_string()
{
	return lang("Variable")
}

getParametersLoopParse_a_string()
{
	global
	
	parametersToEdit:=["Label| " lang("Input string"),"Radio|1|expression|" lang("This is a string") ";" lang("This is a variable name or expression") ,"Text|Hello real world, Hello virtual world|VarValue", "Label|" lang("Delimiter characters"),"Text|,|Delimiters","Label|" lang("Omit characters"),"Text|%a_space%%a_tab%|OmitChars"]
	return parametersToEdit
}

GenerateNameLoopParse_a_string(ID)
{
	global
	;MsgBox % %ID%text_to_show
	return lang("Parse_a_string") ": " GUISettingsOfElement%id%repeatCount " " lang("Repeats") 
	
}


