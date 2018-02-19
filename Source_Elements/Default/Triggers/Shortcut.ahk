;Always add this element class name to the global list
AllElementClasses.push("Trigger_Shortcut")

;Element type of the element
Element_getElementType_Trigger_Shortcut()
{
	return "Trigger"
}

;Name of the element
Element_getName_Trigger_Shortcut()
{
	return lang("Shortcut")
}

;Category of the element
Element_getCategory_Trigger_Shortcut()
{
	return lang("User_interaction")
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
	
	parametersToEdit.push({type: "Label", label: lang("Path of the Shortcut")})
	parametersToEdit.push({type: "File", id: "ShortCutPath", default: "%A_Desktop%\" lang("Flow") " " x_GetMyFlowName(Environment) ".lnk" , label: lang("Set_the_Shortcut_path"), options: 8, filter: lang("Shortcut") " (*.lnk)"})
	parametersToEdit.push({type: "Label", label: lang("Options")})
	parametersToEdit.push({type: "CheckBox", id: "RemoveShortcutOnDisabling", default: 1, label: lang("Remove_shortcut_when_disabling")})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Trigger_Shortcut(Environment, ElementParameters)
{
	return lang("Shortcut") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Trigger_Shortcut(Environment, ElementParameters)
{	
	
}



;Called when the trigger is activated
Element_enable_Trigger_Shortcut(Environment, ElementParameters)
{
	
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_enabled(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	ahfPath:=x_GetAhfPath()
	if (ahfPath = "")
	{
		x_enabled(Environment, "exception", "AutoHotFlow.exe not found") 
		return
	}
	
	FileCreateShortcut,% ahfPath,% EvaluatedParameters.ShortCutPath,,% "AHFCommand ""Trigger|" x_GetMyFlowID(Environment) "|" x_GetMyElementID(Environment) """"
	if errorlevel
	{
		x_enabled(Environment, "exception", lang("Can't create shortcut in path '%1%'", ShortCutPath))
		return
	}
	
	x_enabled(Environment, "normal")
}

;Function which triggers the flow
Trigger_Shortcut_Trigger(environment, EvaluatedParameters)
{
	x_trigger(Environment)
}

;Called after the trigger has triggered.
;Here you can for example define the variables which are provided by the triggers.
Element_postTrigger_Trigger_Shortcut(Environment, ElementParameters)
{

}

;Called when the trigger should be disabled.
Element_disable_Trigger_Shortcut(Environment, ElementParameters)
{
	if (ElementParameters.RemoveShortcutOnDisabling)
	{
		EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
		if (EvaluatedParameters._error)
		{
			x_disabled(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		
		shortcutPath:=x_GetFullPath(Environment, EvaluatedParameters.ShortCutPath)
		FileDelete,%shortcutPath%
	}
	
	x_disabled(Environment, "normal")
}



