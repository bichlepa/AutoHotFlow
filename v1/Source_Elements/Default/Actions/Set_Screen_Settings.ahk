
;Name of the element
Element_getName_Action_Set_Screen_Settings()
{
	return x_lang("Set_Screen_Settings")
}

;Category of the element
Element_getCategory_Action_Set_Screen_Settings()
{
	return x_lang("Image")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Set_Screen_Settings()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Set_Screen_Settings()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Set_Screen_Settings()
{
	;"Stable" or "Experimental"
	return "Experimental"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Set_Screen_Settings(Environment)
{
	parametersToEdit:=Object()
	
	NumberOfMonitors := DllCall("user32.dll\GetSystemMetrics", "Int", 80)                  ; Get the number of display monitors on a desktop.

	parametersToEdit.push({type: "Label", label: x_lang("Which monitor")})
	parametersToEdit.push({type: "Checkbox", id: "AllMonitors", default: 0, label: x_lang("All monitors")})
	parametersToEdit.push({type: "edit", id: "MonitorNumber", default: 1, content: "positiveInteger", WarnIfEmpty: true, UseUpDown: true, range: "1-" NumberOfMonitors})
	
	parametersToEdit.push({type: "Label", label:  x_lang("Brightness")})
	parametersToEdit.push({type: "Checkbox", id: "WhetherChangeBrightness", default: 1, label: x_lang("Change brightness")})
	parametersToEdit.push({type: "Slider", id: "brightness", default: 100, content: "positiveNumber", options: "Range0-100 tooltip tickinterval10", AllowExpression: true})
	
	parametersToEdit.push({type: "Label", label:  x_lang("Contrast")})
	parametersToEdit.push({type: "Checkbox", id: "WhetherChangeContrast", default: 0, label: x_lang("Change contrast")})
	parametersToEdit.push({type: "Slider", id: "contrast", default: 50, content: "positiveNumber", options: "Range0-100 tooltip tickinterval10", AllowExpression: true})
	
	parametersToEdit.push({type: "Label", label:  x_lang("Color gain") })
	parametersToEdit.push({type: "Checkbox", id: "WhetherSetRedGain", default: 0, label: x_lang("Change red gain value")})
	parametersToEdit.push({type: "Slider", id: "RedGain", default: 128, content: "positiveNumber", options: "Range0-255 tooltip tickinterval10", AllowExpression: true})
	parametersToEdit.push({type: "Checkbox", id: "WhetherSetGreenGain", default: 0, label: x_lang("Change green gain value")})
	parametersToEdit.push({type: "Slider", id: "GreenGain", default: 128, content: "positiveNumber", options: "Range0-255 tooltip tickinterval10", AllowExpression: true})
	parametersToEdit.push({type: "Checkbox", id: "WhetherSetBlueGain", default: 0, label: x_lang("Change blue gain value")})
	parametersToEdit.push({type: "Slider", id: "BlueGain", default: 128, content: "positiveNumber", options: "Range0-255 tooltip tickinterval10", AllowExpression: true})
	
	parametersToEdit.push({type: "Label", label:  x_lang("Color drive") })
	parametersToEdit.push({type: "Checkbox", id: "WhetherSetRedDrive", default: 0, label: x_lang("Change red drive value")})
	parametersToEdit.push({type: "Slider", id: "RedDrive", default: 128, content: "positiveNumber", options: "Range0-255 tooltip tickinterval10", AllowExpression: true})
	parametersToEdit.push({type: "Checkbox", id: "WhetherSetGreenDrive", default: 0, label: x_lang("Change green drive value")})
	parametersToEdit.push({type: "Slider", id: "GreenDrive", default: 128, content: "positiveNumber", options: "Range0-255 tooltip tickinterval10", AllowExpression: true})
	parametersToEdit.push({type: "Checkbox", id: "WhetherSetBlueDrive", default: 0, label: x_lang("Change blue drive value")})
	parametersToEdit.push({type: "Slider", id: "BlueDrive", default: 128, content: "positiveNumber", options: "Range0-255 tooltip tickinterval10", AllowExpression: true})
	
	parametersToEdit.push({type: "Label", label:  x_lang("Color temperature")})
	parametersToEdit.push({type: "Checkbox", id: "WhetherChangeColorTemperature", default: 0, label: x_lang("Change color temperature")})
	parametersToEdit.push({type: "DropDown", id: "ColorTemperature", default: 1, choices: ["4000 K.", "5000 K.", "6500 K.", "7500 K.", "8200 K.", "9300 K.", "10000 K.", "115000 K."], result: "number"})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Set_Screen_Settings(Environment, ElementParameters)
{
	return x_lang("Set_Screen_Settings") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Set_Screen_Settings(Environment, ElementParameters, staticValues)
{	
	x_par_Enable("MonitorNumber", not ElementParameters.AllMonitors)
	x_par_Enable("brightness", ElementParameters.WhetherChangeBrightness)
	x_par_Enable("contrast", ElementParameters.WhetherChangeContrast)
	x_par_Enable("RedGain", ElementParameters.WhetherSetRedGain)
	x_par_Enable("GreenGain", ElementParameters.WhetherSetGreenGain)
	x_par_Enable("BlueGain", ElementParameters.WhetherSetBlueGain)
	x_par_Enable("RedDrive", ElementParameters.WhetherSetRedDrive)
	x_par_Enable("GreenDrive", ElementParameters.WhetherSetGreenDrive)
	x_par_Enable("BlueDrive", ElementParameters.WhetherSetBlueDrive)
	x_par_Enable("ColorTemperature", ElementParameters.WhetherChangeColorTemperature)
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Set_Screen_Settings(Environment, ElementParameters)
{
	; create list of required parameters
	requiredPars := []
	if (not ElementParameters.AllMonitors)
		requiredPars.push("MonitorNumber")
	if (ElementParameters.WhetherChangeBrightness)
		requiredPars.push("brightness")
	if (ElementParameters.WhetherSetRedGain)
		requiredPars.push("RedGain")
	if (ElementParameters.WhetherSetGreenGain)
		requiredPars.push("GreenGain")
	if (ElementParameters.WhetherSetBlueGain)
		requiredPars.push("BlueGain")
	if (ElementParameters.WhetherSetRedDrive)
		requiredPars.push("RedDrive")
	if (ElementParameters.WhetherSetGreenDrive)
		requiredPars.push("GreenDrive")
	if (ElementParameters.WhetherSetBlueDrive)
		requiredPars.push("BlueDrive")
	if (ElementParameters.WhetherChangeColorTemperature)
		requiredPars.push("ColorTemperature")

	; evaluate additional parameters
	x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, requiredPars)
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
	
	; loop through all monitors
	loop %NumberOfMonitors%
	{
		; handle this monitor if either allMonitors is set or MonitorNumber equals A_Index
		if (ElementParameters.AllMonitors or ElementParameters.MonitorNumber = A_Index)
		{
			if (ElementParameters.WhetherChangeBrightness)
			{
				; change brightness
				result := Default_Lib_class_monitor.SetMonitorBrightness(A_Index, ElementParameters.brightness)

				; check for errors
				if (substr(result, 1, 1) = "*")
				{
					result := substr(result, 2)
					x_finish(Environment, "exception", x_lang("Couldn't set screen setting '%1%' on screen %2%", x_lang("brightness"), displaynumber) ".`n" x_lang("Error code: %1% (%2%)", result, Format("0x{:X}", result)))
					return
				}
			}
			if (ElementParameters.WhetherChangecontrast)
			{
				; change contrast
				result := Default_Lib_class_monitor.SetMonitorContrast(A_Index, ElementParameters.contrast)
				
				; check for errors
				if (substr(result, 1, 1) = "*")
				{
					result := substr(result, 2)
					x_finish(Environment, "exception", x_lang("Couldn't set screen setting '%1%' on screen %2%", x_lang("contrast"), displaynumber) ".`n" x_lang("Error code: %1% (%2%)", result, Format("0x{:X}", result)))
					return
				}
			}
			
			if (ElementParameters.WhetherSetRedGain)
			{
				; change red gain
				result := Default_Lib_class_monitor.SetMonitorRedGreenOrBlueGain(A_Index, 0, ElementParameters.RedGain)
				
				; check for errors
				if (substr(result, 1, 1) = "*")
				{
					result := substr(result, 2)
					x_finish(Environment, "exception", x_lang("Couldn't set screen setting '%1%' on screen %2%", x_lang("red gain"), displaynumber) ".`n" x_lang("Error code: %1% (%2%)", result, Format("0x{:X}", result)))
					return
				}
			}
			if (ElementParameters.WhetherSetGreenGain)
			{
				; set green gain
				result := Default_Lib_class_monitor.SetMonitorRedGreenOrBlueGain(A_Index, 1, ElementParameters.GreenGain)
				
				; check for errors
				if (substr(result, 1, 1) = "*")
				{
					result := substr(result, 2)
					x_finish(Environment, "exception", x_lang("Couldn't set screen setting '%1%' on screen %2%", x_lang("green gain"), displaynumber) ".`n" x_lang("Error code: %1% (%2%)", result, Format("0x{:X}", result)))
					return
				}
			}
			if (ElementParameters.WhetherSetBlueGain)
			{
				; set blue gain
				result := Default_Lib_class_monitor.SetMonitorRedGreenOrBlueGain(A_Index, 2, ElementParameters.BlueGain)
				
				; check for errors
				if (substr(result, 1, 1) = "*")
				{
					result := substr(result, 2)
					x_finish(Environment, "exception", x_lang("Couldn't set screen setting '%1%' on screen %2%", x_lang("blue gain"), displaynumber) ".`n" x_lang("Error code: %1% (%2%)", result, Format("0x{:X}", result)))
					return
				}
			}
			if (ElementParameters.WhetherSetRedDrive)
			{
				; set red drive
				result := Default_Lib_class_monitor.SetMonitorRedGreenOrBlueDrive(A_Index, 0, ElementParameters.RedDrive)
				
				; check for errors
				if (substr(result, 1, 1) = "*")
				{
					result := substr(result, 2)
					x_finish(Environment, "exception", x_lang("Couldn't set screen setting '%1%' on screen %2%", x_lang("red drive"), displaynumber) ".`n" x_lang("Error code: %1% (%2%)", result, Format("0x{:X}", result)))
					return
				}
			}
			if (ElementParameters.WhetherSetGreenDrive)
			{
				; set green drive
				result := Default_Lib_class_monitor.SetMonitorRedGreenOrBlueDrive(A_Index, 1, ElementParameters.GreenDrive)
				
				; check for errors
				if (substr(result, 1, 1) = "*")
				{
					result := substr(result, 2)
					x_finish(Environment, "exception", x_lang("Couldn't set screen setting '%1%' on screen %2%", x_lang("green drive"), displaynumber) ".`n" x_lang("Error code: %1% (%2%)", result, Format("0x{:X}", result)))
					return
				}
			}
			if (ElementParameters.WhetherSetBlueDrive)
			{
				; set blue drive
				result := Default_Lib_class_monitor.SetMonitorRedGreenOrBlueDrive(A_Index, 2, ElementParameters.BlueDrive)
				
				; check for errors
				if (substr(result, 1, 1) = "*")
				{
					result := substr(result, 2)
					x_finish(Environment, "exception", x_lang("Couldn't set screen setting '%1%' on screen %2%", x_lang("blue drive"), displaynumber) ".`n" x_lang("Error code: %1% (%2%)", result, Format("0x{:X}", result)))
					return
				}
			}
			if (ElementParameters.WhetherChangeColorTemperature)
			{
				; set color temperature
				result := Default_Lib_class_monitor.SetMonitorColorTemperature(A_Index, ElementParameters.ColorTemperature)
				
				; check for errors
				if (substr(result, 1, 1) = "*")
				{
					result := substr(result, 2)
					x_finish(Environment, "exception", x_lang("Couldn't set screen setting '%1%' on screen %2%", x_lang("color temperature"), displaynumber) ".`n" x_lang("Error code: %1% (%2%)", result, Format("0x{:X}", result)))
					return
				}
			}
		}
	}
	
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Set_Screen_Settings(Environment, ElementParameters)
{
	
}






