;Always add this element class name to the global list
x_RegisterElementClass("Action_Get_Screen_Settings")

;Element type of the element
Element_getElementType_Action_Get_Screen_Settings()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Get_Screen_Settings()
{
	return x_lang("Get_Screen_Settings")
}

;Category of the element
Element_getCategory_Action_Get_Screen_Settings()
{
	return x_lang("Image")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Get_Screen_Settings()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Get_Screen_Settings()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Get_Screen_Settings()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Get_Screen_Settings()
{
	;"Stable" or "Experimental"
	return "Experimental"
}


;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Get_Screen_Settings(Environment)
{
	parametersToEdit:=Object()
	
	; get count of screens
	NumberOfMonitors := DllCall("user32.dll\GetSystemMetrics", "Int", 80)

	parametersToEdit.push({type: "Label", label: x_lang("Which screen")})
	parametersToEdit.push({type: "edit", id: "MonitorNumber", default: 1, content: "positiveInteger", WarnIfEmpty: true, UseUpDown: true, range: "1-" NumberOfMonitors})
	
	parametersToEdit.push({type: "Label", label:  x_lang("Output variables")})
	
	parametersToEdit.push({type: "Label", label:  x_lang("Brightness") ": " x_lang("Current value") " - " x_lang("Minimum") " - " x_lang("Maximum") , size: "small"})
	parametersToEdit.push({type: "Edit", id: ["VarnameBrightness", "VarnameBrightnessMin", "VarnameBrightnessMax"], default: ["Brightness","" ,"" ], content: "VariableName"})
	
	parametersToEdit.push({type: "Label", label:  x_lang("Contrast") ": " x_lang("Current value") " - " x_lang("Minimum") " - " x_lang("Maximum") , size: "small"})
	parametersToEdit.push({type: "Edit", id: ["VarnameContrast", "VarnameContrastMin", "VarnameContrastMax"], default: ["Contrast","" ,"" ], content: "VariableName"})
	
	parametersToEdit.push({type: "Label", label:  x_lang("Red gain") ": " x_lang("Current value") " - " x_lang("Minimum") " - " x_lang("Maximum") , size: "small" })
	parametersToEdit.push({type: "Edit", id: ["VarnameRedGain", "VarnameRedGainMin", "VarnameRedGainMax"], default: ["RedGain", "","" ], content: "VariableName"})
	parametersToEdit.push({type: "Label", label:  x_lang("Green gain") ": " x_lang("Current value") " - " x_lang("Minimum") " - " x_lang("Maximum") , size: "small" })
	parametersToEdit.push({type: "Edit", id: ["VarnameGreenGain", "VarnameGreenGainMin", "VarnameGreenGainMax"], default: ["GreenGain", "", ""], content: "VariableName"})
	parametersToEdit.push({type: "Label", label:  x_lang("Blue gain") ": " x_lang("Current value") " - " x_lang("Minimum") " - " x_lang("Maximum") , size: "small" })
	parametersToEdit.push({type: "Edit", id: ["VarnameBlueGain", "VarnameBlueGainMin", "VarnameBlueGainMax"], default: ["BlueGain","" , ""], content: "VariableName"})
	
	parametersToEdit.push({type: "Label", label:  x_lang("Red drive") ": " x_lang("Current value") " - " x_lang("Minimum") " - " x_lang("Maximum") , size: "small" })
	parametersToEdit.push({type: "Edit", id: ["VarnameReddrive", "VarnameReddriveMin", "VarnameReddriveMax"], default: ["RedDrive", "","" ], content: "VariableName"})
	parametersToEdit.push({type: "Label", label:  x_lang("Green drive") ": " x_lang("Current value") " - " x_lang("Minimum") " - " x_lang("Maximum") , size: "small" })
	parametersToEdit.push({type: "Edit", id: ["VarnameGreendrive", "VarnameGreendriveMin", "VarnameGreendriveMax"], default: ["GreenDrive", "", ""], content: "VariableName"})
	parametersToEdit.push({type: "Label", label:  x_lang("Blue drive") ": " x_lang("Current value") " - " x_lang("Minimum") " - " x_lang("Maximum") , size: "small" })
	parametersToEdit.push({type: "Edit", id: ["VarnameBluedrive", "VarnameBluedriveMin", "VarnameBluedriveMax"], default: ["BlueDrive","" , ""], content: "VariableName"})
	
	parametersToEdit.push({type: "Label", label:  x_lang("Color temperature"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "VarnameColorTemperature", default: "ColorTemperature", content: "VariableName"})

	; request that the result of this function is never cached (because of the screen number value)
	parametersToEdit.updateOnEdit := true

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Get_Screen_Settings(Environment, ElementParameters)
{
	return x_lang("Get_Screen_Settings") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Get_Screen_Settings(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Get_Screen_Settings(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters, ["varnameRGB", "varnameR", "varnameG", "varnameB"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; Get the count of screens
	NumberOfMonitors := DllCall("user32.dll\GetSystemMetrics", "Int", 80)
	; check whether the screen exists
	if not (EvaluatedParameters.MonitorNumber >= 1 and EvaluatedParameters.MonitorNumber <= NumberOfMonitors)
	{
		x_finish(Environment, "exception", x_lang("Screen %1% does not exist", EvaluatedParameters.MonitorNumber)) 
	}
	
	if (EvaluatedParameters.VarnameBrightness != "" or EvaluatedParameters.VarnameBrightnessMin != "" or EvaluatedParameters.VarnameBrightnessMax != "")
	{
		; we need to get the screen brightness
		result := class_monitor.GetMonitorBrightness(EvaluatedParameters.MonitorNumber)

		; check for errors
		if (substr(result, 1, 1) = "*")
		{
			result := substr(result, 2)
			x_finish(Environment, "exception", x_lang("Couldn't get screen setting: %1%", x_lang("Brightness")) ". " x_lang("Error code: %1% (%2%)", result, Format("0x{:X}", result)))
			return
		}

		; set output variables
		if (EvaluatedParameters.VarnameBrightness != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameBrightness, result.Current)
		if (EvaluatedParameters.VarnameBrightnessmin != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameBrightnessMin, result.Minimum)
		if (EvaluatedParameters.VarnameBrightnessmax != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameBrightnessMax, result.Maximum)
	}
	
	if (EvaluatedParameters.VarnameContrast != "" or EvaluatedParameters.VarnameContrastMin != "" or EvaluatedParameters.VarnameContrastMax != "")
	{
		; we need to get the screen contrast
		result := class_monitor.GetMonitorContrast(EvaluatedParameters.MonitorNumber)
		
		; check for errors
		if (substr(result, 1, 1) = "*")
		{
			result := substr(result, 2)
			x_finish(Environment, "exception", x_lang("Couldn't get screen setting: %1%", x_lang("Contrast")) ". " x_lang("Error code: %1% (%2%)", result, Format("0x{:X}", result)))
			return
		}

		; set output variables
		if (EvaluatedParameters.VarnameContrast != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameContrast, result.Current)
		if (EvaluatedParameters.VarnameContrastmin != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameContrastmin, result.Minimum)
		if (EvaluatedParameters.VarnameContrastmax != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameContrastmax, result.Maximum)
	}
	
	if (EvaluatedParameters.VarnameRedGain != "" or EvaluatedParameters.VarnameRedGainMin != "" or EvaluatedParameters.VarnameRedGainMax != "")
	{
		; we need to get the red gain
		result := class_monitor.GetMonitorRedGreenOrBlueGain(EvaluatedParameters.MonitorNumber, 0)

		; check for errors
		if (substr(result, 1, 1) = "*")
		{
			result := substr(result, 2)
			x_finish(Environment, "exception", x_lang("Couldn't get screen setting: %1%", x_lang("Red gain")) ". " x_lang("Error code: %1% (%2%)", result, Format("0x{:X}", result)))
			return
		}

		; set output variables
		if (EvaluatedParameters.VarnameRedGain != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameRedGain, result.Current)
		if (EvaluatedParameters.VarnameRedGainmin != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameRedGainmin, result.Minimum)
		if (EvaluatedParameters.VarnameRedGainmax != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameRedGainmax, result.Maximum)
	}
	if (EvaluatedParameters.VarnameGreenGain != "" or EvaluatedParameters.VarnameGreenGainMin != "" or EvaluatedParameters.VarnameGreenGainMax != "")
	{
		; we need to get the green gain
		result := class_monitor.GetMonitorRedGreenOrBlueGain(EvaluatedParameters.MonitorNumber, 1)

		; check for errors
		if (substr(result, 1, 1) = "*")
		{
			result := substr(result, 2)
			x_finish(Environment, "exception", x_lang("Couldn't get screen setting: %1%", x_lang("Green gain")) ". " x_lang("Error code: %1% (%2%)", result, Format("0x{:X}", result)))
			return
		}

		; set output variables
		if (EvaluatedParameters.VarnameGreenGain != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameGreenGain, result.Current)
		if (EvaluatedParameters.VarnameGreenGainmin != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameGreenGainmin, result.Minimum)
		if (EvaluatedParameters.VarnameGreenGainmax != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameGreenGainmax, result.Maximum)
	}
	if (VarnameBlueGain != "" or VarnameBlueGainMin != "" or VarnameBlueGainMax!="")
	{
		; we need to get the blue gain
		result := class_monitor.GetMonitorRedGreenOrBlueGain(EvaluatedParameters.MonitorNumber, 2)

		; check for errors
		if (substr(result, 1, 1) = "*")
		{
			result := substr(result, 2)
			x_finish(Environment, "exception", x_lang("Couldn't get screen setting: %1%", x_lang("Blue gain")) ". " x_lang("Error code: %1% (%2%)", result, Format("0x{:X}", result)))
			return
		}

		; set output variables
		if (EvaluatedParameters.VarnameBlueGain != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameBlueGain, result.Current)
		if (EvaluatedParameters.VarnameBlueGainmin != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameBlueGainmin, result.Minimum)
		if (EvaluatedParameters.VarnameBlueGainmax!="")
			x_SetVariable(Environment, EvaluatedParameters.VarnameBlueGainmax, result.Maximum)
	}
	
	if (EvaluatedParameters.VarnameRedDrive != "" or EvaluatedParameters.VarnameRedDriveMin != "" or EvaluatedParameters.VarnameRedDriveMax != "")
	{
		; we need to get the red drive
		result := class_monitor.GetMonitorRedGreenOrBlueDrive(EvaluatedParameters.MonitorNumber, 0)

		; check for errors
		if (substr(result, 1, 1) = "*")
		{
			result := substr(result, 2)
			x_finish(Environment, "exception", x_lang("Couldn't get screen setting: %1%", x_lang("Red drive")) ". " x_lang("Error code: %1% (%2%)", result, Format("0x{:X}", result)))
			return
		}

		; set output variables
		if (EvaluatedParameters.VarnameRedDrive != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameRedDrive, result.Current)
		if (EvaluatedParameters.VarnameRedDrivemin != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameRedDrivemin, result.Minimum)
		if (EvaluatedParameters.VarnameRedDrivemax != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameRedDrivemax, result.Maximum)
	}
	if (EvaluatedParameters.VarnameGreenDrive != "" or EvaluatedParameters.VarnameGreenDriveMin != "" or EvaluatedParameters.VarnameGreenDriveMax != "")
	{
		; we need to get the green drive
		result := class_monitor.GetMonitorRedGreenOrBlueDrive(EvaluatedParameters.MonitorNumber, 1)

		; check for errors
		if (substr(result, 1, 1) = "*")
		{
			result := substr(result, 2)
			x_finish(Environment, "exception", x_lang("Couldn't get screen setting: %1%", x_lang("Green drive")) ". " x_lang("Error code: %1% (%2%)", result, Format("0x{:X}", result)))
			return
		}

		; set output variables
		if (EvaluatedParameters.VarnameGreenDrive != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameGreenDrive, result.Current)
		if (EvaluatedParameters.VarnameGreenDrivemin != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameGreenDrivemin, result.Minimum)
		if (EvaluatedParameters.VarnameGreenDrivemax != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameGreenDrivemax, result.Maximum)
	}
	if (EvaluatedParameters.VarnameBlueDrive != "" or EvaluatedParameters.VarnameBlueDriveMin != "" or EvaluatedParameters.VarnameBlueDriveMax != "")
	{
		; we need to get the blue drive
		result := class_monitor.GetMonitorRedGreenOrBlueDrive(EvaluatedParameters.MonitorNumber, 2)

		; check for errors
		if (substr(result, 1, 1) = "*")
		{
			result := substr(result, 2)
			x_finish(Environment, "exception", x_lang("Couldn't get screen setting: %1%", x_lang("Blue drive")) ". " x_lang("Error code: %1% (%2%)", result, Format("0x{:X}", result)))
			return
		}

		; set output variables
		if (EvaluatedParameters.VarnameBlueDrive != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameBlueDrive, result.Current)
		if (EvaluatedParameters.VarnameBlueDrivemin != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameBlueDrivemin, result.Minimum)
		if (EvaluatedParameters.VarnameBlueDrivemax != "")
			x_SetVariable(Environment, EvaluatedParameters.VarnameBlueDrivemax, result.Maximum)
	}
	
	if (EvaluatedParameters.VarnameColorTemperature != "")
	{
		; we need to get the color temperature
		result := class_monitor.GetMonitorColorTemperature(EvaluatedParameters.MonitorNumber)

		; check for errors
		if (substr(result, 1, 1) = "*")
		{
			result := substr(result, 2)
			x_finish(Environment, "exception", x_lang("Couldn't get screen setting: %1%",x_lang("Color temperature")) ". " x_lang("Error code: %1% (%2%)", result, Format("0x{:X}", result)))
			return
		}

		; set output variable
		x_SetVariable(Environment, EvaluatedParameters.VarnameColorTemperature, result)
	}
	
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Get_Screen_Settings(Environment, ElementParameters)
{
	
}






