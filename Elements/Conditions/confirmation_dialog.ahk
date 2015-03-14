iniAllConditions.="Confirmation_Dialog|" ;Add this condition to list of all conditions on initialisation

runConditionConfirmation_Dialog(InstanceID,ElementID,ElementIDInInstance)
{
	global
	if (!IsObject(ConditionConfirmation_DialogToStart))
		ConditionConfirmation_DialogToStart:=Object()
	
	tempInstanceString:="Instance_" InstanceID "_" ElementID "_" ElementIDInInstance
	ConditionConfirmation_DialogToStart.insert(tempInstanceString)
	
	if (Confirmation_DialogStarted=true)
		return
	
	

	ConditionConfirmation_Dialog_StartNextQuestion:
	Confirmation_DialogStarted:=false
	for count, tempcConfirmation_DialogidToStart in ConditionConfirmation_DialogToStart ;get the first element
	{
		StringSplit,tempElement,tempcConfirmation_DialogidToStart,_
		; tempElement1 = word "instance"
		; tempElement2 = instance id
		; tempElement3 = element id
		; tempElement4 = element id in the instance
		ConditionConfirmation_DialogToStart_Element_ID:=tempElement3
		
		
		;gui,%tempcConfirmation_DialogidToStart%:default
		
		;gui,10:-SysMenu 
		
		gui,10:add,text,x10 w320 h100, % v_replaceVariables(InstanceID,%ConditionConfirmation_DialogToStart_Element_ID%question)
		gui,10:add,button,x10 w150 h30 gConditionConfirmation_DialogButtonYes,% lang("Yes")
		gui,10:add,button,X+10 yp w150 h30 gConditionConfirmation_DialogButtonNo,% lang("No")
		gui,10:show,w330 h150 ,% v_replaceVariables(InstanceID,%ConditionConfirmation_DialogToStart_Element_ID%title)
		
		ConditionConfirmation_DialogStart_Current:=tempcConfirmation_DialogidToStart
		Confirmation_DialogStarted:=true
		break
		
	}
	
	if (Confirmation_DialogStarted)
		ConditionConfirmation_DialogToStart.remove(1) ;Remove the shown question
	
	return
	
	ConditionConfirmation_DialogButtonYes:
	
	gui,10:destroy
	
	MarkThatElementHasFinishedRunningOneVar(ConditionConfirmation_DialogStart_Current,"yes")
	
	goto,ConditionConfirmation_Dialog_StartNextQuestion
	
	
		
	
	
	ConditionConfirmation_DialogButtonNo:
	gui,10:destroy
	
	MarkThatElementHasFinishedRunningOneVar(ConditionConfirmation_DialogStart_Current,"no")

	goto,ConditionConfirmation_Dialog_StartNextQuestion
	
	10guiclose:
	gui,10:destroy
	
	MarkThatElementHasFinishedRunningOneVar(ConditionConfirmation_DialogStart_Current,"exception")
	
	
	goto,ConditionConfirmation_Dialog_StartNextQuestion
}

stopConditionConfirmation_Dialog(ID)
{
	
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