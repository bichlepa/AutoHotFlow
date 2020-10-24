;Always add this element class name to the global list
x_RegisterElementClass("Trigger_Window_Gets_Active")

;Element type of the element
Element_getElementType_Trigger_Window_Gets_Active()
{
	return "trigger"
}

;Name of the element
Element_getName_Trigger_Window_Gets_Active()
{
	return lang("Window_Gets_Active")
}

;Category of the element
Element_getCategory_Trigger_Window_Gets_Active()
{
	return lang("Window")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Trigger_Window_Gets_Active()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Trigger_Window_Gets_Active()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Trigger_Window_Gets_Active()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Trigger_Window_Gets_Active()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Trigger_Window_Gets_Active(Environment)
{
	
	parametersToEdit := Object()
	parametersToEdit.push({type: "Label", label: lang("Title_of_Window")})
	parametersToEdit.push({type: "Radio", id: "TitleMatchMode", default: 1, choices: [lang("Start_with"), lang("Contain_anywhere"), lang("Exactly")]})
	parametersToEdit.push({type: "Edit", id: "Wintitle", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Exclude_title")})
	parametersToEdit.push({type: "Edit", id: "excludeTitle", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Text_of_a_control_in_Window")})
	parametersToEdit.push({type: "Edit", id: "winText", content: "String"})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenText", default: 0, label: lang("Detect hidden text")})
	parametersToEdit.push({type: "Label", label: lang("Exclude_text_of_a_control_in_window")})
	parametersToEdit.push({type: "Edit", id: "ExcludeText", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Window_Class")})
	parametersToEdit.push({type: "Edit", id: "ahk_class", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Process_Name")})
	parametersToEdit.push({type: "Edit", id: "ahk_exe", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Unique_window_ID")})
	parametersToEdit.push({type: "Edit", id: "ahk_id", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Unique_Process_ID")})
	parametersToEdit.push({type: "Edit", id: "ahk_pid", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Hidden window")})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenWindow", default: 0, label: lang("Detect hidden window")})
	parametersToEdit.push({type: "Label", label: lang("Get_parameters")})
	parametersToEdit.push({type: "button", goto: "Trigger_Window_Exists_ButtonWindowAssistant", label: lang("Get_Parameters")})

	parametersToEdit.push({type: "Label", label: lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "NotTriggerOnEnable", default: 1, label: lang("Do not trigger if a matching window exists when enabling the trigger")})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Trigger_Window_Gets_Active(Environment, ElementParameters)
{
	global
	local tempNameString
	if (ElementParameters.Wintitle)
	{
		if (ElementParameters.TitleMatchMode=1)
			tempNameString:=tempNameString "`n" lang("Title begins with") ": " ElementParameters.Wintitle
		else if (ElementParameters.TitleMatchMode=2)
			tempNameString:=tempNameString "`n" lang("Title includes") ": " ElementParameters.Wintitle
		else if (ElementParameters.TitleMatchMode=3)
			tempNameString:=tempNameString "`n" lang("Title is exatly") ": " ElementParameters.Wintitle
	}
	if (ElementParameters.excludeTitle)
		tempNameString:=tempNameString "`n" lang("Exclude_title") ": " ElementParameters.excludeTitle
	if (ElementParameters.winText)
		tempNameString:=tempNameString "`n" lang("Control_text") ": " ElementParameters.winText
	if (ElementParameters.ExcludeText)
		tempNameString:=tempNameString "`n" lang("Exclude_control_text") ": " ElementParameters.ExcludeText
	if (ElementParameters.ahk_class)
		tempNameString:=tempNameString "`n" lang("Window_Class") ": " ElementParameters.ahk_class
	if (ElementParameters.ahk_exe)
		tempNameString:=tempNameString "`n" lang("Process") ": " ElementParameters.ahk_exe
	if (ElementParameters.ahk_id)
		tempNameString:=tempNameString "`n" lang("Window_ID") ": " ElementParameters.ahk_id
	if (ElementParameters.ahk_pid)
		tempNameString:=tempNameString "`n" lang("Process_ID") ": " ElementParameters.ahk_pid
	
	return lang("Window_Gets_Active") ": " tempNameString
	
	
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Trigger_Window_Gets_Active(Environment, ElementParameters)
{	
	
}

;Called when the trigger is activated
Element_enable_Trigger_Window_Gets_Active(Environment, ElementParameters)
{
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	tempWinTitle:=EvaluatedParameters.Wintitle
	tempWinText:=EvaluatedParameters.winText
	tempExcludeTitle:=EvaluatedParameters.ExcludeTitle
	tempExcludeText:=EvaluatedParameters.ExcludeText
	tempTitleMatchMode :=EvaluatedParameters.TitleMatchMode
	tempahk_class:=EvaluatedParameters.ahk_class
	tempahk_exe:=EvaluatedParameters.ahk_exe
	tempahk_id:= EvaluatedParameters.ahk_id
	tempahk_pid:= EvaluatedParameters.ahk_pid
	
	tempwinstring=%tempWinTitle%
	if tempahk_class<>
		tempwinstring=%tempwinstring% ahk_class %tempahk_class%
	if tempahk_id<>
		tempwinstring=%tempwinstring% ahk_id %tempahk_id%
	if tempahk_pid<>
		tempwinstring=%tempwinstring% ahk_pid %tempahk_pid%
	if tempahk_exe<>
		tempwinstring=%tempwinstring% ahk_exe %tempahk_exe%
	
	;If no window specified, error
	if (tempwinstring="" and tempWinText="")
	{
		x_enabled(Environment, "exception", lang("No window specified"))
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
	
	inputVars:={winstring: tempwinstring, wintext: tempWinText, excludeTitle: tempExcludeTitle, excludeText: tempExcludeText, titlematchmode: tempTitleMatchMode, findhiddenwindow: tempFindHiddenWindows, findhiddentext: tempfindhiddentext, NotTriggerOnEnable: ElementParameters.NotTriggerOnEnable}
	outputVars:=["windowID"]
	code =
	( ` , LTrim %
	
		SetTitleMatchMode,%titlematchmode%
		DetectHiddenText,%findhiddentext%
		DetectHiddenWindows,%findhiddenwindow%
		if (NotTriggerOnEnable)
		{
			WinWaitNotActive %winstring%, %wintext%, , %excludeTitle%, %excludeText%
		}
		loop
		{
			WinWaitActive,%winstring%, %wintext%, , %excludeTitle%, %excludeText%
			winget,windowID,ID
			x_trigger()
			WinWaitNotActive %winstring%, %wintext%, , %excludeTitle%, %excludeText%
			
		}
	
	)
	
	
	x_TriggerInNewAHKThread(Environment, code, inputVars, outputVars)
	
	x_enabled(Environment, "normal", lang("Waiting for defined window to appear.",temphotkey))

}

;Called after the trigger has triggered.
;Here you can for example define the variables which are provided by the triggers.
Element_postTrigger_Trigger_Window_Gets_Active(Environment, ElementParameters)
{
	exportedValues:=x_TriggerInNewAHKThread_GetExportedValues(Environment)
	x_SetVariable(Environment, "a_WindowID", exportedValues.windowID, "Thread")
}


;Called when the trigger should be disabled.
Element_disable_Trigger_Window_Gets_Active(Environment, ElementParameters)
{
	x_TriggerInNewAHKThread_Stop(Environment)
	x_disabled(Environment, "normal", lang("Stopped."))
}


; opens the assistant for getting window information
Trigger_Window_Exists_ButtonWindowAssistant()
{
	x_assistant_windowParameter({wintitle: "Wintitle", excludeTitle: "excludeTitle", winText: "winText", FindHiddenText: "FindHiddenText", ExcludeText: "ExcludeText", ahk_class: "ahk_class", ahk_exe: "ahk_exe", ahk_id: "ahk_id", ahk_pid: "ahk_pid", FindHiddenWindow: "FindHiddenWindow"})
}
