iniAllActions.="New_date|" ;Add this action to list of all actions on initialisation

runActionNew_date(InstanceID,ElementID,ElementIDInInstance)
{
	global
	
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)

	v_SetVariable(InstanceID,v_replaceVariables(InstanceID,%ElementID%Varname),v_replaceVariables(InstanceID,%ElementID%Date),"Date")
	

	MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionNew_date()
{
	return lang("New_date")
}
getCategoryActionNew_date()
{
	return lang("Variable")
}

getParametersActionNew_date()
{
	global
	parametersToEdit:=["Label|" lang("Variable_name"),"VariableName|NewDate|Varname","Label| " lang("Date"),"Dateandtime||Date"]
	
	return parametersToEdit
}

GenerateNameActionNew_date(ID)
{
	global
	
	return % lang("New_date") "`n" GUISettingsOfElement%ID%Varname " = " v_exportVariable(GUISettingsOfElement%ID%Date,"Time")
	
}