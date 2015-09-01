iniAllActions.="Get_Volume|" ;Add this action to list of all actions on initialisation

runActionGet_Volume(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	
	local Varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varname)) )
		return
	}
	
	SoundGet,temp

	v_setVariable(InstanceID,ThreadID,Varname,round(temp,1))
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return

}
getNameActionGet_Volume()
{
	return lang("Get_Volume")
}
getCategoryActionGet_Volume()
{
	return lang("Sound")
}

getParametersActionGet_Volume()
{
	global
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "Volume", content: "VariableName", WarnIfEmpty: true})

	
	return parametersToEdit
}

GenerateNameActionGet_Volume(ID)
{
	global
	
	return lang("Get_Volume")
}


