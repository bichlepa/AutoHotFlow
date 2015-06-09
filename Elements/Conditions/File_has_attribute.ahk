iniAllConditions.="File_has_attribute|" ;Add this condition to list of all conditions on initialisation

runConditionFile_has_attribute(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempattribute
	local tempcompare
	
	FileGetAttrib,tempattribute,% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if ErrorLevel
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	else
	{
		if %ElementID%Attribute=1
			tempcompare=R
		else if %ElementID%Attribute=2
			tempcompare=A
		else if %ElementID%Attribute=3
			tempcompare=S
		else if %ElementID%Attribute=4
			tempcompare=H
		else if %ElementID%Attribute=5
			tempcompare=N
		else if %ElementID%Attribute=6
			tempcompare=D
		else if %ElementID%Attribute=7
			tempcompare=O
		else if %ElementID%Attribute=8
			tempcompare=C
		else if %ElementID%Attribute=9
			tempcompare=T
		;MsgBox %tempcompare%
		IfInString,tempattribute,%tempcompare%
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"yes")
		else
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"no")
	}
	
	
	
	
}

stopConditionFile_has_attribute(ID)
{
	
	return
}


getParametersConditionFile_has_attribute()
{
	
	parametersToEdit:=["Label|" lang("Select file"),"File||file|" lang("Select a file") "|","Label|" lang("Whitch attribute"),"Radio|1|Attribute|" lang("Read only") ";" lang("Archive") ";" lang("System") ";" lang("Hidden") ";" lang("Normal") ";" lang("Directory") ";" lang("Offline") ";" lang("Compressed") ";" lang("Temporary")]
	
	return parametersToEdit
}

getNameConditionFile_has_attribute()
{
	return lang("File_has_attribute")
}

getCategoryConditionFile_has_attribute()
{
	return lang("Files")
}

GenerateNameConditionFile_has_attribute(ID)
{
	if GUISettingsOfElement%ID%Attribute1=1
		tempcompare:=lang("Read only")
	else if GUISettingsOfElement%ID%Attribute2=1
		tempcompare:=lang("Archive")
	else if GUISettingsOfElement%ID%Attribute3=1
		tempcompare:=lang("System")
	else if GUISettingsOfElement%ID%Attribute4=1
		tempcompare:=lang("Hidden")
	else if GUISettingsOfElement%ID%Attribute5=1
		tempcompare:=lang("Normal")
	else if GUISettingsOfElement%ID%Attribute6=1
		tempcompare:=lang("Directory")
	else if GUISettingsOfElement%ID%Attribute7=1
		tempcompare:=lang("Offline")
	else if GUISettingsOfElement%ID%Attribute8=1
		tempcompare:=lang("Compressed")
	else if GUISettingsOfElement%ID%Attribute9=1
		tempcompare:=lang("Temporary")
	
	return lang("File_has_attribute") " " tempcompare ": " GUISettingsOfElement%ID%file
	
}