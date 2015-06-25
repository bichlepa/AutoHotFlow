iniAllActions.="Message_Box|" ;Add this action to list of all actions on initialisation

runActionMessage_Box(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%text,"normal")
	local tempTitle:=v_replaceVariables(InstanceID,ThreadID,%ElementID%title,"normal")
	
	if (!IsObject(ActionMessage_BoxAllGUIs)) ;On first run, create object that will contain all current openen windows
		ActionMessage_BoxAllGUIs:=Object()
	
	local tempNew:=Object() ;create object that will contain all settings of the current element
	tempNew.insert("instanceID",InstanceID)
	tempNew.insert("ThreadID",ThreadID)
	tempNew.insert("ElementID",ElementID)
	tempNew.insert("ElementIDInInstance",ElementIDInInstance)
	tempNew.insert("Text",tempText)
	tempNew.insert("Title",tempTitle)
	
	;Create a gui label. This label will always be unique. 
	local tempGUILabel:="GUI_MessageBox_" instanceID "_" ThreadID "_" ElementID "_" ElementIDInInstance 
	
	
	;Create GUI
	gui,%tempGUILabel%:+LabelMessageBoxGUI ;This label leads to a jump label beneath. It's needed if user closes the window
	gui,%tempGUILabel%:add,text,, % tempText
	gui,%tempGUILabel%:add,button,x10 w150 h30 gActionMessage_BoxButtonOK Default,% lang("OK")
	gui,%tempGUILabel%:show,,% tempTitle
	
	;Add the label to the list of all GUI labels, so it can be found.
	ActionMessage_BoxAllGUIs.insert(tempGUILabel,tempNew)
	
	return
	
	

	
	
	ActionMessage_BoxButtonOK:
	
	gui,%a_gui%:destroy
	
	;Get the parameter list for the current GUI from the list of all GUIs
	tempMessageBoxBut:=ActionMessage_BoxAllGUIs[a_gui]
	
	;~ MsgBox % a_gui " - " temp.instanceID
	MarkThatElementHasFinishedRunning(tempMessageBoxBut.instanceID,tempMessageBoxBut.threadid,tempMessageBoxBut.ElementID,tempMessageBoxBut.ElementIDInInstance,"normal")
	
	;Remove this GUI from the list of all GUIs
	ActionMessage_BoxAllGUIs.Remove(a_gui)
	
	return
	
	MessageBoxGUIclose:
	
	gui,%a_gui%:destroy
	
	;Get the parameter list for the current GUI from the list of all GUIs
	tempMessageBoxBut:=ActionMessage_BoxAllGUIs[a_gui]
	
	;~ MsgBox % a_gui " - " temp.instanceID
	MarkThatElementHasFinishedRunning(tempMessageBoxBut.instanceID,tempMessageBoxBut.threadid,tempMessageBoxBut.ElementID,tempMessageBoxBut.ElementIDInInstance,"exception")

	
	ActionMessage_BoxAllGUIs.Remove(a_gui)
	return
}

stopActionMessage_Box(ID)
{
	global
	;Go through all GUI Labels that are in the list of all GUIs
	for tempActionMessageBoxGuiLabel, tempActionMessageBoxSettings in ActionMessage_BoxAllGUIs
	{
		gui,%tempActionMessageBoxGuiLabel%:destroy ;Close the window
		
	}
	
	ActionMessage_BoxAllGUIs:=Object() ;Delete all elements from the list of all GUIs
	
}



getParametersActionMessage_Box()
{
	
	parametersToEdit:=["Label|" lang("Title"),"text|" lang("Title")" |title","Label|" lang("Message"),"multilinetext|" lang("Message") "|text"]
	
	return parametersToEdit
}

getNameActionMessage_Box()
{
	return lang("Message_Box")
}
getCategoryActionMessage_Box()
{
	return lang("User_interaction")
}

GenerateNameActionMessage_Box(ID)
{
	return lang("Message_Box") ": " GUISettingsOfElement%ID%title " - " GUISettingsOfElement%ID%text
	
}