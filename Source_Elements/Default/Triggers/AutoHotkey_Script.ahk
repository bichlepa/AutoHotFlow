;Always add this element class name to the global list
x_RegisterElementClass("Trigger_AutoHotkey_Script")

;Element type of the element
Element_getElementType_Trigger_AutoHotkey_Script()
{
	return "Trigger"
}

;Name of the element
Element_getName_Trigger_AutoHotkey_Script()
{
	return x_lang("AutoHotkey_Script")
}

;Category of the element
Element_getCategory_Trigger_AutoHotkey_Script()
{
	return x_lang("Expert")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Trigger_AutoHotkey_Script()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Trigger_AutoHotkey_Script()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Programmer"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Trigger_AutoHotkey_Script()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Trigger_AutoHotkey_Script()
{
	;"Stable" or "Experimental"
	return "Experimental"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Trigger_AutoHotkey_Script(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("AutoHotKey_script"), WarnIfEmpty: true})
	parametersToEdit.push({type: "multilineEdit", id: "Script", default: "loop`n{`n  sleep 10000`n  x_trigger()`n}", WarnIfEmpty: false})
	parametersToEdit.push({type: "Label", label: x_lang("Variables that should be imported to script before enabling")})
	parametersToEdit.push({type: "edit", id: "ImportVariables", multiline: true})
	parametersToEdit.push({type: "Label", label: x_lang("Variables that should be exported from script on trigger")})
	parametersToEdit.push({type: "edit", id: "ExportVariables", multiline: true})
	
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Trigger_AutoHotkey_Script(Environment, ElementParameters)
{
	return x_lang("AutoHotkey_Script") "`n" substr(ElementParameters.script, 1, 50)
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Trigger_AutoHotkey_Script(Environment, ElementParameters)
{	
	
}



;Called when the trigger is activated
Element_enable_Trigger_AutoHotkey_Script(Environment, ElementParameters)
{
	ImportVariables := x_replaceVariables(Environment,ElementParameters.ImportVariables)
	ExportVariables := x_replaceVariables(Environment, ElementParameters.ExportVariables)
	script := ElementParameters.script

    ;Write all local variables in the script
	inputVars:=Object()
	loop,parse,ImportVariables,|`,`n%a_space%
	{
		if not A_LoopField
			continue
		
		inputVars[A_LoopField] := x_GetVariable(Environment, A_LoopField)
	}

	;Get all local variables from the script
	outputVars:=Object()
	loop,parse,ExportVariables,|`,`n%a_space%
	{
		if not A_LoopField
			continue
		outputVars.push(A_LoopField)
	}
	
	x_TriggerInNewAHKThread(Environment, script, inputVars, outputVars)
	x_enabled(Environment, "normal")
	
	; return true, if trigger was enabled
	return true
}


;Called after the trigger has triggered.
;Here you can for example define the variables which are provided by the triggers.
Element_postTrigger_Trigger_AutoHotkey_Script(Environment, ElementParameters, TriggerData)
{
	exportedValues := x_TriggerInNewAHKThread_GetExportedValues(Environment)
	x_ImportInstanceVars(Environment, exportedValues)
}

;Called when the trigger should be disabled.
Element_disable_Trigger_AutoHotkey_Script(Environment, ElementParameters)
{
	x_TriggerInNewAHKThread_Stop(Environment)
	x_disabled(Environment, "normal")
}



