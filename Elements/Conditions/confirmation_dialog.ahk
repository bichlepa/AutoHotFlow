iniAllConditions.="Confirmation_Dialog|" ;Add this condition to list of all conditions on initialisation

runConditionConfirmation_Dialog(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%question,"normal")
	local tempTitle:=v_replaceVariables(InstanceID,ThreadID,%ElementID%title,"normal")
	
	if (!IsObject(ConditionConfirmation_DialogAllGUIs))
		ConditionConfirmation_DialogAllGUIs:=Object()
	
	local tempNew:=Object() ;create object that will contain all settings of the current element
	tempNew.insert("instanceID",InstanceID)
	tempNew.insert("ThreadID",ThreadID)
	tempNew.insert("ElementID",ElementID)
	tempNew.insert("ElementIDInInstance",ElementIDInInstance)
	tempNew.insert("Text",tempText)
	tempNew.insert("Title",tempTitle)
	
	;Create a gui label. This label will always be unique. 
	local tempGUILabel:="GUI_Confirmation_Dialog_" instanceID "_" ThreadID "_" ElementID "_" ElementIDInInstance 
	
	
	;Create GUI
	gui,%tempGUILabel%:+LabelConfirmation_DialogGUI ;This label leads to a jump label beneath. It's needed if user closes the window
	gui,%tempGUILabel%:add,text,x10 w320 h100, % tempText
	gui,%tempGUILabel%:add,button,x10 w150 h30 gConditionConfirmation_DialogButtonYes,% lang("Yes")
	gui,%tempGUILabel%:add,button,X+10 yp w150 h30 gConditionConfirmation_DialogButtonNo,% lang("No")
	gui,%tempGUILabel%:show,w330 h150 ,% tempTitle
	
	;Add the label to the list of all GUI labels, so it can be found.
	ConditionConfirmation_DialogAllGUIs.insert(tempGUILabel,tempNew)
	
	return
	
	ConditionConfirmation_DialogButtonYes:
	ConditionConfirmation_DialogButtonNo:
	gui,%a_gui%:destroy
	
	;Get the parameter list for the current GUI from the list of all GUIs
	tempConfirmation_DialogBut:=ConditionConfirmation_DialogAllGUIs[a_gui]
	
	;~ MsgBox % a_gui " - " temp.instanceID
	if A_ThisLabel=ConditionConfirmation_DialogButtonYes
		MarkThatElementHasFinishedRunning(tempConfirmation_DialogBut.instanceID,tempConfirmation_DialogBut.threadid,tempConfirmation_DialogBut.ElementID,tempConfirmation_DialogBut.ElementIDInInstance,"yes")
	else
		MarkThatElementHasFinishedRunning(tempConfirmation_DialogBut.instanceID,tempConfirmation_DialogBut.threadid,tempConfirmation_DialogBut.ElementID,tempConfirmation_DialogBut.ElementIDInInstance,"no")
	
	;Remove this GUI from the list of all GUIs
	ConditionConfirmation_DialogAllGUIs.Remove(a_gui)
	
	return
	
	Confirmation_DialogGUIclose:
	
	gui,%a_gui%:destroy
	
	;Get the parameter list for the current GUI from the list of all GUIs
	tempConfirmation_DialogBut:=ConditionConfirmation_DialogAllGUIs[a_gui]
	
	;~ MsgBox % a_gui " - " temp.instanceID
	MarkThatElementHasFinishedRunning(tempConfirmation_DialogBut.instanceID,tempConfirmation_DialogBut.threadid,tempConfirmation_DialogBut.ElementID,tempConfirmation_DialogBut.ElementIDInInstance,"exception")

	
	ConditionConfirmation_DialogAllGUIs.Remove(a_gui)
	return
	
	
	
}

stopConditionConfirmation_Dialog(ID)
{
	global
	;Go through all GUI Labels that are in the list of all GUIs
	for tempConditionConfirmation_DialogGuiLabel, tempConditionConfirmation_DialogSettings in ConditionConfirmation_DialogAllGUIs
	{
		gui,%tempConditionConfirmation_DialogGuiLabel%:destroy ;Close the window
		
	}
	
	ConditionConfirmation_DialogAllGUIs:=Object() ;Delete all elements from the list of all GUIs
	
	gui,%ID%:default
	gui,destroy
}



getParametersConditionConfirmation_Dialog()
{
	
	parametersToEdit:=["Label|" lang("Title"),"text|" lang("Question")" |title","Label|" lang("Question"),"text|" lang("Do_you_agree?") "|question"]
	
	return parametersToEdit
}

getNameConditionConfirmation_Dialog()
{
	return lang("Confirmation_Dialog")
}
getCategoryConditionConfirmation_Dialog()
{
	return lang("User_interaction")
}

GenerateNameConditionConfirmation_Dialog(ID)
{
	return lang("Confirmation_Dialog") ": " GUISettingsOfElement%ID%title " - " GUISettingsOfElement%ID%question
	
}