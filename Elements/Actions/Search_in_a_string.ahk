iniAllActions.="Search_in_a_string|" ;Add this action to list of all actions on initialisation

runActionSearch_in_a_string(InstanceID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local tempVarname
	local tempSearchText
	local OccurenceNumber
	local Offset
	local Result
	local Options
	
	tempVarname:=v_replaceVariables(InstanceID,%ElementID%Varname)
	
	if %ElementID%expression=1
		temp:=v_replaceVariables(InstanceID,%ElementID%VarValue)
	else
		temp:=v_EvaluateExpression(InstanceID,%ElementID%VarValue)
	if %ElementID%IsExpressionSearchText=1
		tempSearchText:=v_replaceVariables(InstanceID,%ElementID%SearchText)
	else
		tempSearchText:=v_EvaluateExpression(InstanceID,%ElementID%SearchText)
	
	OccurenceNumber:=v_replaceVariables(InstanceID,%ElementID%OccurenceNumber)
	Offset:=v_replaceVariables(InstanceID,%ElementID%Offset)
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)
	if %ElementID%CaseSensitive=2
	{
		StringCaseSense,on
	}
	
	
	if %ElementID%LeftOrRight=1 ;Left
	{
		Options=L%OccurenceNumber%
	}
	else ;Right
	{
		Options=R%OccurenceNumber%
	}
		
	StringGetPos,Result,temp,% tempSearchText,%Options%,%Offset%
	StringCaseSense,off
	if errorlevel=1 ;If no string was found
	{
		v_SetVariable(InstanceID,tempVarname,Result+1)
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
	}
	else
	{
		v_SetVariable(InstanceID,tempVarname,Result+1)
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
	}
	
	
	
	
	
	return
}
getNameActionSearch_in_a_string()
{
	return lang("Search_in_a_string")
}
getCategoryActionSearch_in_a_string()
{
	return lang("Variable")
}

getParametersActionSearch_in_a_string()
{
	global
	parametersToEdit:=["Label|" lang("Name of the variable that will contain the result"),"VariableName|NewPosition|Varname","Label| " lang("Input string"),"Radio|1|expression|" lang("This is a string") ";" lang("This is a variable name or expression") ,"Text|Hello World|VarValue","Label| " lang("Text to search"),"Radio|1|IsExpressionSearchText|" lang("This is a string") ";" lang("This is a variable name or expression") ,"Text|World|SearchText","Label|" lang("Whitch occurence"),"Text|1|OccurenceNumber","Radio|1|LeftOrRight|" lang("From left") ";" lang("From right"),"Label|" lang("Start position"),"Text|1|Offset","Label|" lang("Case sensitivity"),"Radio|1|CaseSensitive|" lang("Case insensitive") ";" lang("Case sensitive")]
	
	return parametersToEdit
}

GenerateNameActionSearch_in_a_string(ID)
{
	global
	
	return % lang("Search_in_a_string") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}

CheckSettingsActionSearch_in_a_string(ID)
{
	static previousLeftSide=0
	static previousRightSide=0
	
	
}