;Always add this element class name to the global list
x_RegisterElementClass("Action_Set_Screen_Settings")

;Element type of the element
Element_getElementType_Action_Set_Screen_Settings()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Set_Screen_Settings()
{
	return lang("Set_Screen_Settings")
}

;Category of the element
Element_getCategory_Action_Set_Screen_Settings()
{
	return lang("Image")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Set_Screen_Settings()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Set_Screen_Settings()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Set_Screen_Settings()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Set_Screen_Settings()
{
	;"Stable" or "Experimental"
	return "Experimental"
}

;Returns a list of all parameters of the element.
;Only those parameters will be saved.
Element_getParameters_Action_Set_Screen_Settings()
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({id: "AllMonitors"})
	parametersToEdit.push({id: "MonitorNumber"})
	parametersToEdit.push({id: "WhetherChangeBrightness"})
	parametersToEdit.push({id: "brightness"})
	parametersToEdit.push({id: "WhetherChangeContrast"})
	parametersToEdit.push({id: "contrast"})
	parametersToEdit.push({id: "WhetherSetRedGain"})
	parametersToEdit.push({id: "RedGain"})
	parametersToEdit.push({id: "WhetherSetGreenGain"})
	parametersToEdit.push({id: "GreenGain"})
	parametersToEdit.push({id: "WhetherSetBlueGain"})
	parametersToEdit.push({id: "BlueGain"})
	parametersToEdit.push({id: "WhetherSetRedDrive"})
	parametersToEdit.push({id: "RedDrive"})
	parametersToEdit.push({id: "WhetherSetGreenDrive"})
	parametersToEdit.push({id: "GreenDrive"})
	parametersToEdit.push({id: "WhetherSetBlueDrive"})
	parametersToEdit.push({id: "BlueDrive"})
	parametersToEdit.push({id: "WhetherChangeColorTemperature"})
	parametersToEdit.push({id: "ColorTemperature"})
	
	return parametersToEdit
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Set_Screen_Settings(Environment)
{
	parametersToEdit:=Object()
	
	NumberOfMonitors := DllCall("user32.dll\GetSystemMetrics", "Int", 80)                  ; Get the number of display monitors on a desktop.

	parametersToEdit.push({type: "Label", label: lang("Which monitor")})
	parametersToEdit.push({type: "Checkbox", id: "AllMonitors", default: 0, label: lang("All monitors")})
	parametersToEdit.push({type: "edit", id: "MonitorNumber", default: 1, content: "Expression", WarnIfEmpty: true, UseUpDown: true, range: "1-" NumberOfMonitors})
	
	parametersToEdit.push({type: "Label", label:  lang("Brightness")})
	parametersToEdit.push({type: "Checkbox", id: "WhetherChangeBrightness", default: 1, label: lang("Change brightness")})
	parametersToEdit.push({type: "Slider", id: "brightness", default: 100, options: "Range0-100 tooltip tickinterval10", AllowExpression: true})
	
	parametersToEdit.push({type: "Label", label:  lang("Contrast")})
	parametersToEdit.push({type: "Checkbox", id: "WhetherChangeContrast", default: 0, label: lang("Change contrast")})
	parametersToEdit.push({type: "Slider", id: "contrast", default: 50, options: "Range0-100 tooltip tickinterval10", AllowExpression: true})
	
	;~ parametersToEdit.push({type: "Label", label:  lang("Gamma") " (" lang("Affects all monitors") ")" })
	;~ parametersToEdit.push({type: "Checkbox", id: "WhetherChangeGamma", default: 0, label: lang("Change gamma")})
	;~ parametersToEdit.push({type: "Slider", id: "gamma", default: 128, options: "Range0-255 tooltip tickinterval128", AllowExpression: true})
	
	parametersToEdit.push({type: "Label", label:  lang("Color gain") })
	parametersToEdit.push({type: "Checkbox", id: "WhetherSetRedGain", default: 0, label: lang("Change red gain value")})
	parametersToEdit.push({type: "Slider", id: "RedGain", default: 128, options: "Range0-100 tooltip tickinterval10", AllowExpression: true})
	parametersToEdit.push({type: "Checkbox", id: "WhetherSetGreenGain", default: 0, label: lang("Change green gain value")})
	parametersToEdit.push({type: "Slider", id: "GreenGain", default: 128, options: "Range0-100 tooltip tickinterval10", AllowExpression: true})
	parametersToEdit.push({type: "Checkbox", id: "WhetherSetBlueGain", default: 0, label: lang("Change blue gain value")})
	parametersToEdit.push({type: "Slider", id: "BlueGain", default: 128, options: "Range0-100 tooltip tickinterval10", AllowExpression: true})
	
	parametersToEdit.push({type: "Label", label:  lang("Color drive") })
	parametersToEdit.push({type: "Checkbox", id: "WhetherSetRedDrive", default: 0, label: lang("Change red drive value")})
	parametersToEdit.push({type: "Slider", id: "RedDrive", default: 128, options: "Range0-100 tooltip tickinterval10", AllowExpression: true})
	parametersToEdit.push({type: "Checkbox", id: "WhetherSetGreenDrive", default: 0, label: lang("Change green drive value")})
	parametersToEdit.push({type: "Slider", id: "GreenDrive", default: 128, options: "Range0-100 tooltip tickinterval10", AllowExpression: true})
	parametersToEdit.push({type: "Checkbox", id: "WhetherSetBlueDrive", default: 0, label: lang("Change blue drive value")})
	parametersToEdit.push({type: "Slider", id: "BlueDrive", default: 128, options: "Range0-100 tooltip tickinterval10", AllowExpression: true})
	
	parametersToEdit.push({type: "Label", label:  lang("Color temperature")})
	parametersToEdit.push({type: "Checkbox", id: "WhetherChangeColorTemperature", default: 0, label: lang("Change color temperature")})
	parametersToEdit.push({type: "DropDown", id: "ColorTemperature", default: 1, choices: ["4000 K.", "5000 K.", "6500 K.", "7500 K.", "8200 K.", "9300 K.", "10000 K.", "115000 K."], result: "number"})
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Set_Screen_Settings(Environment, ElementParameters)
{
	return lang("Set_Screen_Settings") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Set_Screen_Settings(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Set_Screen_Settings(Environment, ElementParameters)
{
	NumberOfMonitors := DllCall("user32.dll\GetSystemMetrics", "Int", 80)  ; Get the number of displays on a desktop.
	
	AllMonitors:=ElementParameters.AllMonitors
	if not (AllMonitors)
	{
		evRes := x_evaluateExpression(Environment,ElementParameters.MonitorNumber)
		if (evRes.error)
		{
			;On error, finish with exception and return
			x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.MonitorNumber) "`n`n" evRes.error) 
			return
		}
		MonitorNumber:=evRes.result
		if MonitorNumber is not integer
		{
			x_finish(Environment, "exception", lang("Screen number is not a number") )
			return
		}
		if not (MonitorNumber >= 1 and MonitorNumber <= NumberOfMonitors)
		{
			x_finish(Environment, "exception", lang("Screen %1% does not exist", MonitorNumber) ) 
			return
		}
	}
	
	allParameterBoolNames:=["WhetherChangeBrightness", "WhetherChangeContrast", "WhetherSetRedGain", "WhetherSetGreenGain", "WhetherSetBlueGain", "WhetherSetRedDrive", "WhetherSetGreenDrive", "WhetherSetBlueDrive", "WhetherChangeColorTemperature"]
	allParameterNames:=["brightness", "contrast", "RedGain", "GreenGain", "BlueGain", "RedDrive", "GreenDrive", "BlueDrive", "ColorTemperature"]
	allParameterNamesForLang:=["brightness", "contrast", "red gain", "green gain", "blue gain", "red drive", "green drive", "blue drive", "color temperature"]
	
	anyVarNameSpecified:=False
	for oneindex, oneBoolValue in allParameterBoolNames
	{
		oneParValue:=allParameterNames[oneindex]
		oneParNameString:=allParameterNamesForLang[oneindex]
		%oneBoolValue%:=ElementParameters[oneBoolValue]
		if (%oneBoolValue%)
		{
			evRes := x_evaluateExpression(Environment,ElementParameters[oneParValue])
			if (evRes.error)
			{
				;On error, finish with exception and return
				x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters[oneParValue]) "`n`n" evRes.error) 
				return
			}
			%oneParValue%:=evRes.result
			if %oneParValue% is not number
			{
				;On error, finish with exception and return
				x_finish(Environment, "exception", lang("%1% '%2%' is not a number.",lang(oneParNameString), %oneParValue%))
				return
			}
			
			anyVarNameSpecified:=True
		}
		
	}
	
	if not (anyVarNameSpecified)
	{
		x_finish(Environment, "exception", lang("No value specified"))
		return
	}
	
	loop %NumberOfMonitors%
	{
		if not AllMonitors
			displaynumber:=MonitorNumber
		else
			displaynumber:=A_Index
		
		if WhetherChangeBrightness
		{
			result:=class_monitor.SetMonitorBrightness(displaynumber,brightness)
			if (substr(result,1,1)="*")
			{
				x_finish(Environment, "exception", lang("Couldn't set screen setting '%1%' on screen %2%",lang("brightness"), displaynumber) ".`n" lang("Error code: %1%",result))
				return
			}
		}
		if WhetherChangecontrast
		{
			result:=class_monitor.SetMonitorContrast(displaynumber,contrast)
			if (substr(result,1,1)="*")
			{
				x_finish(Environment, "exception", lang("Couldn't set screen setting '%1%' on screen %2%",lang("contrast"), displaynumber) ".`n" lang("Error code: %1%",result))
				return
			}
		}
		
		if WhetherSetRedGain
		{
			result:=class_monitor.SetMonitorRedGreenOrBlueGain(displaynumber,0,RedGain)
			if (substr(result,1,1)="*")
			{
				x_finish(Environment, "exception", lang("Couldn't set screen setting '%1%' on screen %2%",lang("red gain"), displaynumber) ".`n" lang("Error code: %1%",result))
				return
			}
		}
		if WhetherSetGreenGain
		{
			result:=class_monitor.SetMonitorRedGreenOrBlueGain(displaynumber,1,GreenGain)
			if (substr(result,1,1)="*")
			{
				x_finish(Environment, "exception", lang("Couldn't set screen setting '%1%' on screen %2%",lang("green gain"), displaynumber) ".`n" lang("Error code: %1%",result))
				return
			}
		}
		if WhetherSetBlueGain
		{
			result:=class_monitor.SetMonitorRedGreenOrBlueGain(displaynumber,2,BlueGain)
			if (substr(result,1,1)="*")
			{
				x_finish(Environment, "exception", lang("Couldn't set screen setting '%1%' on screen %2%",lang("blue gain"), displaynumber) ".`n" lang("Error code: %1%",result))
				return
			}
		}
		if WhetherSetRedDrive
		{
			result:=class_monitor.SetMonitorRedGreenOrBlueDrive(displaynumber,0,RedDrive)
			if (substr(result,1,1)="*")
			{
				x_finish(Environment, "exception", lang("Couldn't set screen setting '%1%' on screen %2%",lang("red drive"), displaynumber) ".`n" lang("Error code: %1%",result))
				return
			}
		}
		if WhetherSetGreenDrive
		{
			result:=class_monitor.SetMonitorRedGreenOrBlueDrive(displaynumber,1,GreenDrive)
			if (substr(result,1,1)="*")
			{
				x_finish(Environment, "exception", lang("Couldn't set screen setting '%1%' on screen %2%",lang("green drive"), displaynumber) ".`n" lang("Error code: %1%",result))
				return
			}
		}
		if WhetherSetBlueDrive
		{
			result:=class_monitor.SetMonitorRedGreenOrBlueDrive(displaynumber,2,BlueDrive)
			if (substr(result,1,1)="*")
			{
				x_finish(Environment, "exception", lang("Couldn't set screen setting '%1%' on screen %2%",lang("blue drive"), displaynumber) ".`n" lang("Error code: %1%",result))
				return
			}
		}
		if WhetherChangeColorTemperature
		{
			result:=class_monitor.SetMonitorColorTemperature(displaynumber,ColorTemperature)
			if (substr(result,1,1)="*")
			{
				x_finish(Environment, "exception", lang("Couldn't set screen setting '%1%' on screen %2%",lang("color temperature"), displaynumber) ".`n" lang("Error code: %1%",result))
				return
			}
		}
		if not AllMonitors
			break
	}
	
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Set_Screen_Settings(Environment, ElementParameters)
{
	
}






