;Always add this element class name to the global list
x_RegisterElementClass("Action_Get_Control_Text")

;Element type of the element
Element_getElementType_Action_Get_Control_Text()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Get_Control_Text()
{
	return x_lang("Get_Control_Text")
}

;Category of the element
Element_getCategory_Action_Get_Control_Text()
{
	return x_lang("Window")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Get_Control_Text()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Get_Control_Text()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Get_Control_Text()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Get_Control_Text()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Get_Control_Text(Environment)
{
	parametersToEdit:=Object()

	parametersToEdit.push({type: "Label", label: x_lang("Output variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "ControlText", content: "VariableName"})
	
	parametersToEdit.push({type: "Label", label: x_lang("Control_Identification")})
	parametersToEdit.push({type: "Label", label: x_lang("Method_for_control_Identification"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "IdentifyControlBy", result: "enum", default: 2, choices: [x_lang("Text_in_control"), x_lang("Classname and instance number of the control"), x_lang("Unique control ID")], enum: ["Text", "Class", "ID"]})
	parametersToEdit.push({type: "Label", label: x_lang("Control_Identification"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "ControlTextMatchMode", default: 2, choices: [x_lang("Start_with"), x_lang("Contain_anywhere"), x_lang("Exactly")]})
	parametersToEdit.push({type: "Edit", id: "Control_identifier", content: "String", WarnIfEmpty: true})
	
	; call function which adds all the required fields for window identification
	windowFunctions_addWindowIdentificationParametrization(parametersToEdit)
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Get_Control_Text(Environment, ElementParameters)
{
	; generate window identification name
	nameString := windowFunctions_generateWindowIdentificationName(ElementParameters)
	
	return x_lang("Get_Control_Text") ": " nameString
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Get_Control_Text(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Get_Control_Text(Environment, ElementParameters)
{
	Varname := x_replaceVariables(Environment, ElementParameters.Varname)
	if not x_CheckVariableName(Varname)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", x_lang("%1% is not valid", x_lang("Ouput variable name '%1%'", Varname)))
		return
	}

	IdentifyControlBy := ElementParameters.IdentifyControlBy
	ControlTextMatchMode := ElementParameters.ControlTextMatchMode

	Control_identifier := x_replaceVariables(Environment,ElementParameters.Control_identifier)

	tempWinTitle:=x_replaceVariables(Environment, ElementParameters.Wintitle) 
	tempWinText:=x_replaceVariables(Environment, ElementParameters.winText)
	tempExcludeTitle:=EvaluatedParameters.ExcludeTitle
	tempExcludeText:=EvaluatedParameters.ExcludeText
	tempTitleMatchMode :=ElementParameters.TitleMatchMode
	tempahk_class:=x_replaceVariables(Environment, ElementParameters.ahk_class)
	tempahk_exe:=x_replaceVariables(Environment, ElementParameters.ahk_exe)
	tempahk_id:=x_replaceVariables(Environment, ElementParameters.ahk_id)
	tempahk_pid:=x_replaceVariables(Environment, ElementParameters.ahk_pid)
	
	tempwinstring:=tempWinTitle
	if tempahk_class
		tempwinstring:=tempwinstring " ahk_class " tempahk_class
	if tempahk_id
		tempwinstring:=tempwinstring " ahk_id " tempahk_id
	if tempahk_pid
		tempwinstring:=tempwinstring " ahk_pid " tempahk_pid
	if tempahk_exe
		tempwinstring:=tempwinstring " ahk_exe " tempahk_exe
	
	;If no window specified, error
	if (tempwinstring="" and tempWinText="")
	{
		x_enabled(Environment, "exception", x_lang("No window specified"))
		return
	}
	
	if ElementParameters.findhiddenwindow=0
		tempFindHiddenWindows = off
	else
		tempFindHiddenWindows = on
	if ElementParameters.findhiddentext=0
		tempfindhiddentext = off
	else
		tempfindhiddentext = on
	
	SetTitleMatchMode,%tempTitleMatchMode%
	DetectHiddenWindows,%tempFindHiddenWindows%
	DetectHiddenText,%tempfindhiddentext%
	
	tempWinid:=winexist(tempwinstring,tempWinText,tempExcludeTitle,tempExcludeText) ;Example code. Remove it
	if not tempWinid
	{
		x_finish(Environment, "exception", x_lang("Error! Seeked window does not exist")) 
		return
	}
	
	SetTitleMatchMode,%ControlTextMatchMode%
	controlget,tempControlID,hwnd,,% Control_identifier,ahk_id %tempWinid%
	if not tempControlID
	{
		x_finish(Environment, "exception", x_lang("Error! Seeked control does not exist in the specified windows")) 
		return
	}
	ControlGetText,tempText,,ahk_id %tempControlID%
	
	x_SetVariable(Environment,Varname,tempText)
	x_SetVariable(Environment,"A_WindowID",tempWinid,"Thread")
	x_SetVariable(Environment,"A_ControlID",tempControlID,"Thread")
	
	x_finish(Environment, "normal")
	return
	
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Get_Control_Text(Environment, ElementParameters)
{
	
}
