iniAllActions.="Date_Calculation|" ;Add this action to list of all actions on initialisation

runActionDate_Calculation(InstanceID,ElementID,ElementIDInInstance)
{
	global
	
	local tempVarName:=v_replaceVariables(InstanceID,%ElementID%varname)
	local tempTime:=v_GetVariable(InstanceID,tempVarName,"Date")
	local tempCount:=v_replaceVariables(InstanceID,%ElementID%Units)
	
	local tempUnit
	if %ElementID%Unit=1
		tempUnit=Seconds
	else if %ElementID%Unit=2
		tempUnit=Minutes
	else if %ElementID%Unit=3
		tempUnit=Hours
	else if %ElementID%Unit=4
		tempUnit=Days
	
	if tempTime is time
	{
		envadd,tempTime,%tempCount%,%tempUnit%
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)
	
		v_SetVariable(InstanceID,tempVarName,tempTime,"Date")
		
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
	}
	else
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"Exception")
	

	
	return
}
getNameActionDate_Calculation()
{
	return lang("Date_Calculation")
}
getCategoryActionDate_Calculation()
{
	return lang("Variable")
}

getParametersActionDate_Calculation()
{
	global
	parametersToEdit:=["Label|" lang("Variable_name"),"VariableName||Varname","Label| " lang("How many units to add"),"Text||Units","Radio|1|Unit|" lang("Seconds") ";" lang("Minutes") ";" lang("Hours") ";" lang("Days")]
	
	return parametersToEdit
}

GenerateNameActionDate_Calculation(ID)
{
	global
	local tempstring
	local tempstringUnit
	
	if GUISettingsOfElement%ID%Unit1=1
		tempstringUnit:= lang("Seconds")
	else if GUISettingsOfElement%ID%Unit2=1
		tempstringUnit:= lang("Minutes")
	else if GUISettingsOfElement%ID%Unit3=1
		tempstringUnit:= lang("Hours")
	else if GUISettingsOfElement%ID%Unit4=1
		tempstringUnit:= lang("Days")
	
	if GUISettingsOfElement%ID%Units>0
		tempstring:= lang("Add %1% to %2%",GUISettingsOfElement%ID%Units " " tempstringUnit,GUISettingsOfElement%ID%Varname )
	else if GUISettingsOfElement%ID%Units<0
		tempstring:= lang("Subtract %1% from %2%",-GUISettingsOfElement%ID%Units " " tempstringUnit,GUISettingsOfElement%ID%Varname )
	return % lang("Date_Calculation") "`n" tempstring
	
}