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
	
	NumberOfMonitors := DllCall("user32.dll\GetSystemMetrics", "Int", 80)                  ; Get the number of display monitors on a desktop.

	parametersToEdit.push({type: "Label", label: x_lang("Which monitor")})
	parametersToEdit.push({type: "edit", id: "MonitorNumber", default: 1, content: "Expression", WarnIfEmpty: true, UseUpDown: true, range: "1-" NumberOfMonitors})
	
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
Element_CheckSettings_Action_Get_Screen_Settings(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Get_Screen_Settings(Environment, ElementParameters)
{
	NumberOfMonitors := DllCall("user32.dll\GetSystemMetrics", "Int", 80)  ; Get the number of displays on a desktop.
	
	evRes := x_evaluateExpression(Environment,ElementParameters.MonitorNumber)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", x_lang("An error occured while parsing expression '%1%'", ElementParameters.MonitorNumber) "`n`n" evRes.error) 
		return
	}
	MonitorNumber:=evRes.result
	if MonitorNumber is not integer
	{
		x_finish(Environment, "exception", x_lang("Screen number is not specified") )
	}
	if not (MonitorNumber >= 1 and MonitorNumber <= NumberOfMonitors)
	{
		x_finish(Environment, "exception", x_lang("Screen %1% does not exist", MonitorNumber) ) 
	}
	
	allVarNames:=["VarnameBrightness", "VarnameBrightnessMin", "VarnameBrightnessMax", "VarnameContrast", "VarnameContrastMin", "VarnameContrastMax", "VarnameRedGain", "VarnameRedGainMin", "VarnameRedGainMax", "VarnameGreenGain", "VarnameGreenGainMin", "VarnameGreenGainMax", "VarnameBlueGain", "VarnameBlueGainMin", "VarnameBlueGainMax", "VarnameReddrive", "VarnameReddriveMin", "VarnameReddriveMax", "VarnameGreendrive", "VarnameGreendriveMin", "VarnameGreendriveMax", "VarnameBluedrive", "VarnameBluedriveMin", "VarnameBluedriveMax", "VarnameColorTemperature"]
	
	anyVarNameSpecified:=False
	for oneindex, oneVarname in allVarNames
	{
		%oneVarname% := x_replaceVariables(Environment, ElementParameters[oneVarname])
		if (%oneVarname% != "")
		{
			if not x_CheckVariableName(%oneVarname%)
			{
				;On error, finish with exception and return
				x_finish(Environment, "exception", x_lang("%1% is not valid", x_lang("Ouput variable name '%1%'", %oneVarname%)))
				return
			}
			anyVarNameSpecified:=true
		}
	}
	
	if not (anyVarNameSpecified)
	{
		x_finish(Environment, "exception", x_lang("No variable name specified"))
		return
	}
	
	
	if (VarnameBrightness!="" or VarnameBrightnessMin!="" or VarnameBrightnessMax!="")
	{
		result:=class_monitor.GetMonitorBrightness(MonitorNumber)
		if (substr(result,1,1)="*")
		{
			x_finish(Environment, "exception", x_lang("Couldn't get screen setting: %1%",x_lang("Brightness")) ". " x_lang("Error code: %1%",result))
			return
		}
		if (VarnameBrightness!="")
			x_SetVariable(Environment,VarnameBrightness,result.Current)
		if (VarnameBrightnessmin!="")
			x_SetVariable(Environment,VarnameBrightnessMin,result.Minimum)
		if (VarnameBrightnessmax!="")
			x_SetVariable(Environment,VarnameBrightnessMax,result.Maximum)
	}
	
	if (VarnameContrast!="" or VarnameContrastMin!="" or VarnameContrastMax!="")
	{
		result:=class_monitor.GetMonitorContrast(MonitorNumber)
		if (substr(result,1,1)="*")
		{
			x_finish(Environment, "exception", x_lang("Couldn't get screen setting: %1%",x_lang("Contrast")) ". " x_lang("Error code: %1%",result))
			
			return
		}
		if (VarnameContrast!="")
			x_SetVariable(Environment,VarnameContrast,result.Current)
		if (VarnameContrastmin!="")
			x_SetVariable(Environment,VarnameContrastmin,result.Minimum)
		if (VarnameContrastmax!="")
			x_SetVariable(Environment,VarnameContrastmax,result.Maximum)
	}
	
	if (VarnameRedGain!="" or VarnameRedGainMin!="" or VarnameRedGainMax!="")
	{
		result:=class_monitor.GetMonitorRedGreenOrBlueGain(MonitorNumber,0)
		if (substr(result,1,1)="*")
		{
			x_finish(Environment, "exception", x_lang("Couldn't get screen setting: %1%",x_lang("Red gain")) ". " x_lang("Error code: %1%",result))
			return
		}
		if (VarnameRedGain!="")
			x_SetVariable(Environment,VarnameRedGain,result.Current)
		if (VarnameRedGainmin!="")
			x_SetVariable(Environment,VarnameRedGainmin,result.Minimum)
		if (VarnameRedGainmax!="")
			x_SetVariable(Environment,VarnameRedGainmax,result.Maximum)
	}
	if (VarnameGreenGain!="" or VarnameGreenGainMin!="" or VarnameGreenGainMax!="")
	{
		result:=class_monitor.GetMonitorRedGreenOrBlueGain(MonitorNumber,1)
		if (substr(result,1,1)="*")
		{
			x_finish(Environment, "exception", x_lang("Couldn't get screen setting: %1%",x_lang("Green gain")) ". " x_lang("Error code: %1%",result))
			return
		}
		if (VarnameGreenGain!="")
			x_SetVariable(Environment,VarnameGreenGain,result.Current)
		if (VarnameGreenGainmin!="")
			x_SetVariable(Environment,VarnameGreenGainmin,result.Minimum)
		if (VarnameGreenGainmax!="")
			x_SetVariable(Environment,VarnameGreenGainmax,result.Maximum)
	}
	if (VarnameBlueGain!="" or VarnameBlueGainMin!="" or VarnameBlueGainMax!="")
	{
		result:=class_monitor.GetMonitorRedGreenOrBlueGain(MonitorNumber,2)
		if (substr(result,1,1)="*")
		{
			x_finish(Environment, "exception", x_lang("Couldn't get screen setting: %1%",x_lang("Blue gain")) ". " x_lang("Error code: %1%",result))
			return
		}
		if (VarnameBlueGain!="")
			x_SetVariable(Environment,VarnameBlueGain,result.Current)
		if (VarnameBlueGainmin!="")
			x_SetVariable(Environment,VarnameBlueGainmin,result.Minimum)
		if (VarnameBlueGainmax!="")
			x_SetVariable(Environment,VarnameBlueGainmax,result.Maximum)
	}
	
	if (VarnameRedDrive!="" or VarnameRedDriveMin!="" or VarnameRedDriveMax!="")
	{
		result:=class_monitor.GetMonitorRedGreenOrBlueDrive(MonitorNumber,0)
		if (substr(result,1,1)="*")
		{
			x_finish(Environment, "exception", x_lang("Couldn't get screen setting: %1%",x_lang("Red drive")) ". " x_lang("Error code: %1%",result))
			return
		}
		if (VarnameRedDrive!="")
			x_SetVariable(Environment,VarnameRedDrive,result.Current)
		if (VarnameRedDrivemin!="")
			x_SetVariable(Environment,VarnameRedDrivemin,result.Minimum)
		if (VarnameRedDrivemax!="")
			x_SetVariable(Environment,VarnameRedDrivemax,result.Maximum)
	}
	if (VarnameGreenDrive!="" or VarnameGreenDriveMin!="" or VarnameGreenDriveMax!="")
	{
		result:=class_monitor.GetMonitorRedGreenOrBlueDrive(MonitorNumber,1)
		if (substr(result,1,1)="*")
		{
			x_finish(Environment, "exception", x_lang("Couldn't get screen setting: %1%",x_lang("Green drive")) ". " x_lang("Error code: %1%",result))
			return
		}
		if (VarnameGreenDrive!="")
			x_SetVariable(Environment,VarnameGreenDrive,result.Current)
		if (VarnameGreenDrivemin!="")
			x_SetVariable(Environment,VarnameGreenDrivemin,result.Minimum)
		if (VarnameGreenDrivemax!="")
			x_SetVariable(Environment,VarnameGreenDrivemax,result.Maximum)
	}
	if (VarnameBlueDrive!="" or VarnameBlueDriveMin!="" or VarnameBlueDriveMax!="")
	{
		result:=class_monitor.GetMonitorRedGreenOrBlueDrive(MonitorNumber,2)
		if (substr(result,1,1)="*")
		{
			x_finish(Environment, "exception", x_lang("Couldn't get screen setting: %1%",x_lang("Blue drive")) ". " x_lang("Error code: %1%",result))
			return
		}
		if (VarnameBlueDrive!="")
			x_SetVariable(Environment,VarnameBlueDrive,result.Current)
		if (VarnameBlueDrivemin!="")
			x_SetVariable(Environment,VarnameBlueDrivemin,result.Minimum)
		if (VarnameBlueDrivemax!="")
			x_SetVariable(Environment,VarnameBlueDrivemax,result.Maximum)
	}
	
	if (VarnameColorTemperature!="")
	{
		result:=class_monitor.GetMonitorColorTemperature(MonitorNumber)
		if (substr(result,1,1)="*")
		{
			x_finish(Environment, "exception", x_lang("Couldn't get screen setting: %1%",x_lang("Color temperature")) ". " x_lang("Error code: %1%",result))
			return
		}
			x_SetVariable(Environment,VarnameColorTemperature,result)
	}
	
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Get_Screen_Settings(Environment, ElementParameters)
{
	
}






