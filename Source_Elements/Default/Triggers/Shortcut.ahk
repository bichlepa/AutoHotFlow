;Always add this element class name to the global list
x_RegisterElementClass("Trigger_Shortcut")

;Element type of the element
Element_getElementType_Trigger_Shortcut()
{
	return "Trigger"
}

;Name of the element
Element_getName_Trigger_Shortcut()
{
	return x_lang("Shortcut")
}

;Category of the element
Element_getCategory_Trigger_Shortcut()
{
	return x_lang("User_interaction")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Trigger_Shortcut()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Trigger_Shortcut()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Trigger_Shortcut()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Trigger_Shortcut()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Trigger_Shortcut(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Path of the Shortcut")})
	parametersToEdit.push({type: "File", id: "ShortCutPath", default: "%A_Desktop%\" x_lang("Flow") " " x_GetMyFlowName(Environment) ".lnk" , label: x_lang("Set_the_Shortcut_path"), options: 8, filter: x_lang("Shortcut") " (*.lnk)"})
	parametersToEdit.push({type: "Label", label: x_lang("Options")})
	parametersToEdit.push({type: "CheckBox", id: "RemoveShortcutOnDisabling", default: 1, label: x_lang("Remove_shortcut_when_disabling")})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Trigger_Shortcut(Environment, ElementParameters)
{
	return x_lang("Shortcut") "`n" ElementParameters.ShortCutPath
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Trigger_Shortcut(Environment, ElementParameters, staticValues)
{	
	
}

;Called when the trigger is activated
Element_enable_Trigger_Shortcut(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_enabled(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; get path of AHF exe. We will need to to set up the shortcut.
	ahfPath := x_GetAhfPath()
	if (ahfPath = "")
	{
		x_enabled(Environment, "exception", "AutoHotFlow.exe not found") 
		return
	}

	; create shortcut. It will call AHF with a command which will trigger this flow
	FileCreateShortcut, % ahfPath, % EvaluatedParameters.ShortCutPath,, % "AHFCommand ""Trigger|" x_GetMyFlowID(Environment) "|" x_GetMyElementID(Environment) """"
	if errorlevel
	{
		x_enabled(Environment, "exception", x_lang("Can't create shortcut in path '%1%'", EvaluatedParameters.ShortCutPath))
		return
	}
	
	x_enabled(Environment, "normal")
	; return true, if trigger was enabled
	return true
}

;Function which triggers the flow
Trigger_Shortcut_Trigger(environment, EvaluatedParameters)
{
	x_trigger(Environment)
}

;Called after the trigger has triggered.
;Here you can for example define the variables which are provided by the triggers.
Element_postTrigger_Trigger_Shortcut(Environment, ElementParameters, TriggerData)
{

}

;Called when the trigger should be disabled.
Element_disable_Trigger_Shortcut(Environment, ElementParameters)
{
	; check settings
	if (ElementParameters.RemoveShortcutOnDisabling)
	{
		; it is configured that the shortcut should be removed if it is disabled.
		EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
		if (EvaluatedParameters._error)
		{
			x_disabled(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		
		; delete the shortcut
		FileDelete, % EvaluatedParameters.shortcutPath
	}
	
	x_disabled(Environment, "normal")
}



