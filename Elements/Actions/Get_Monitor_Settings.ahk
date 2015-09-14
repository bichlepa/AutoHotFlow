iniAllActions.="Get_Monitor_Settings|" ;Add this action to list of all actions on initialisation

;already done in action set monitor settings
;~ ActionsWithMonitorDisplay := New Monitor()
;~ ActionsWithMonitorNumberOfMonitors := DllCall("user32.dll\GetSystemMetrics", "Int", 80)                  ; Get the number of display monitors on a desktop.

RunActionGet_Monitor_Settings(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempnumber
	local result
	
	local MonitorNumber:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%MonitorNumber) ;"URL" is the parameter ID
	if MonitorNumber is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Monitor number " MonitorNumber " is not a number")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% '%2%' is not a number.",lang("Monitor number"),%ElementID%MonitorNumber) )
		return
	}
	
	VarnameBrightness:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameBrightness) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameBrightness)) and VarnameBrightness!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameBrightness "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameBrightness)) )
		return
	}
	VarnameBrightnessMin:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameBrightnessMin) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameBrightnessMin)) and VarnameBrightnessMin!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameBrightnessMin "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameBrightnessMin)) )
		return
	}
	VarnameBrightnessMax:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameBrightnessMax) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameBrightnessMax)) and VarnameBrightnessMax!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameBrightnessMax "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameBrightnessMax)) )
		return
	}
	
	VarnameContrast:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameContrast) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameContrast)) and VarnameContrast!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameContrast "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameContrast)) )
		return
	}
	VarnameContrastMin:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameContrastMin) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameContrastMin)) and VarnameContrastMin!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameContrastMin "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameContrastMin)) )
		return
	}
	VarnameContrastMax:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameContrastMax) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameContrastMax)) and VarnameContrastMax!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameContrastMax "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameContrastMax)) )
		return
	}
	
	VarnameRedGain:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameRedGain) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameRedGain)) and VarnameRedGain!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameRedGain "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameRedGain)) )
		return
	}
	VarnameRedGainMin:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameRedGainMin) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameRedGainMin)) and VarnameRedGainMin!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameRedGainMin "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameRedGainMin)) )
		return
	}
	VarnameRedGainMax:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameRedGainMax) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameRedGainMax)) and VarnameRedGainMax!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameRedGainMax "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameRedGainMax)) )
		return
	}
	VarnameGreenGain:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameGreenGain) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameGreenGain)) and VarnameGreenGain!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameGreenGain "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameGreenGain)) )
		return
	}
	VarnameGreenGainMin:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameGreenGainMin) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameGreenGainMin)) and VarnameGreenGainMin!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameGreenGainMin "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameGreenGainMin)) )
		return
	}
	VarnameGreenGainMax:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameGreenGainMax) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameGreenGainMax)) and VarnameGreenGainMax!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameGreenGainMax "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameGreenGainMax)) )
		return
	}
	VarnameBlueGain:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameBlueGain) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameBlueGain)) and VarnameBlueGain!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameBlueGain "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameBlueGain)) )
		return
	}
	VarnameBlueGainMin:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameBlueGainMin) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameBlueGainMin)) and VarnameBlueGainMin!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameBlueGainMin "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameBlueGainMin)) )
		return
	}
	VarnameBlueGainMax:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameBlueGainMax) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameBlueGainMax)) and VarnameBlueGainMax!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameBlueGainMax "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameBlueGainMax)) )
		return
	}
	
	VarnameGamma:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameGamma) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameGamma)) and VarnameGamma!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameGamma "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameGamma)) )
		return
	}
	VarnameColorTemperature:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameColorTemperature) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameColorTemperature)) and VarnameColorTemperature!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameColorTemperature "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameColorTemperature)) )
		return
	}
	
	
	
	
	
	
	
	if (VarnameBrightness!="" or VarnameBrightnessMin!="" or VarnameBrightnessMax!="")
	{
		result:=ActionsWithMonitorDisplay.GetMonitorBrightness(MonitorNumber)
		if (substr(result,1,1)="*")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Couldn't get monitor brightness. Error code: " result)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Couldn't get monitor setting: %1%",lang("Brightness")) ". " lang("Error code: %1%",result))
			return
		}
		if (VarnameBrightness!="")
			v_SetVariable(InstanceID,ThreadID,VarnameBrightness,result.CurrentBrightness)
		if (VarnameBrightnessmin!="")
			v_SetVariable(InstanceID,ThreadID,VarnameBrightnessmin,result.MinimumBrightness)
		if (VarnameBrightnessmax!="")
			v_SetVariable(InstanceID,ThreadID,VarnameBrightnessmax,result.MaximumBrightness)
	}
	
	if (VarnameContrast!="" or VarnameContrastMin!="" or VarnameContrastMax!="")
	{
		result:=ActionsWithMonitorDisplay.GetMonitorContrast(MonitorNumber)
		if (substr(result,1,1)="*")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Couldn't get monitor contrast. Error code: " result)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Couldn't get monitor setting: %1%",lang("Contrast")) ". " lang("Error code: %1%",result))
			return
		}
		if (VarnameContrast!="")
			v_SetVariable(InstanceID,ThreadID,VarnameContrast,result.CurrentContrast)
		if (VarnameContrastmin!="")
			v_SetVariable(InstanceID,ThreadID,VarnameContrastmin,result.MinimumContrast)
		if (VarnameContrastmax!="")
			v_SetVariable(InstanceID,ThreadID,VarnameContrastmax,result.MaximumContrast)
	}
	
	if (VarnameRedGain!="" or VarnameRedGainMin!="" or VarnameRedGainMax!="")
	{
		result:=ActionsWithMonitorDisplay.GetMonitorRGBGain(MonitorNumber,0)
		if (substr(result,1,1)="*")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Couldn't get monitor red gain. Error code: " result)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Couldn't get monitor setting: %1%",lang("Red gain")) ". " lang("Error code: %1%",result))
			return
		}
		if (VarnameRedGain!="")
			v_SetVariable(InstanceID,ThreadID,VarnameRedGain,result.CurrentGain)
		if (VarnameRedGainmin!="")
			v_SetVariable(InstanceID,ThreadID,VarnameRedGainmin,result.MinimumGain)
		if (VarnameRedGainmax!="")
			v_SetVariable(InstanceID,ThreadID,VarnameRedGainmax,result.MaximumGain)
	}
	if (VarnameGreenGain!="" or VarnameGreenGainMin!="" or VarnameGreenGainMax!="")
	{
		result:=ActionsWithMonitorDisplay.GetMonitorRGBGain(MonitorNumber,1)
		if (substr(result,1,1)="*")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Couldn't get monitor green gain. Error code: " result)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Couldn't get monitor setting: %1%",lang("Green gain")) ". " lang("Error code: %1%",result))
			return
		}
		if (VarnameGreenGain!="")
			v_SetVariable(InstanceID,ThreadID,VarnameGreenGain,result.CurrentGain)
		if (VarnameGreenGainmin!="")
			v_SetVariable(InstanceID,ThreadID,VarnameGreenGainmin,result.MinimumGain)
		if (VarnameGreenGainmax!="")
			v_SetVariable(InstanceID,ThreadID,VarnameGreenGainmax,result.MaximumGain)
	}
	if (VarnameBlueGain!="" or VarnameBlueGainMin!="" or VarnameBlueGainMax!="")
	{
		result:=ActionsWithMonitorDisplay.GetMonitorRGBGain(MonitorNumber,2)
		if (substr(result,1,1)="*")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Couldn't get monitor blue gain. Error code: " result)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Couldn't get monitor setting: %1%",lang("Blue gain")) ". " lang("Error code: %1%",result))
			return
		}
		if (VarnameBlueGain!="")
			v_SetVariable(InstanceID,ThreadID,VarnameBlueGain,result.CurrentGain)
		if (VarnameBlueGainmin!="")
			v_SetVariable(InstanceID,ThreadID,VarnameBlueGainmin,result.MinimumGain)
		if (VarnameBlueGainmax!="")
			v_SetVariable(InstanceID,ThreadID,VarnameBlueGainmax,result.MaximumGain)
	}
	
	if (VarnameGamma!="")
	{
		result:=ActionsWithMonitorDisplay.GetDeviceGammaRamp()
		if (substr(result,1,1)="*")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Couldn't get monitor gamma. Error code: " result)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Couldn't get monitor setting: %1%",lang("Gamma")) ". " lang("Error code: %1%",result))
			return
		}
		v_SetVariable(InstanceID,ThreadID,VarnameGamma,result)
	}
	if (VarnameColorTemperature!="")
	{
		result:=ActionsWithMonitorDisplay.GetMonitorColorTemperature(MonitorNumber)
		if (substr(result,1,1)="*")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Couldn't get monitor color temperature. Error code: " result)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Couldn't get monitor setting: %1%",lang("Color temperature")) ". " lang("Error code: %1%",result))
			return
		}
		v_SetVariable(InstanceID,ThreadID,VarnameColorTemperature,result)
	}
	
	;~ MsgBox % strobj(ActionsWithMonitorDisplay.GetMonitorBrightness(MonitorNumber))
	;~ MsgBox % strobj(ActionsWithMonitorDisplay.GetMonitorRGBGain(MonitorNumber,2))
	
	if (substr(result,1,1)="*")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! An error occured. Error code: " result)
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("An error occured") ". " lang("Error code: %1%",result))
		return
	}
	else
	{
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	}
	return
}
getNameActionGet_Monitor_Settings()
{
	return lang("Get_Monitor_Settings")
}
getCategoryActionGet_Monitor_Settings()
{
	return lang("Image")
}

getParametersActionGet_Monitor_Settings()
{
	global
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Which monitor")})
	;~ parametersToEdit.push({type: "Checkbox", id: "AllMonitors", default: 0, label: lang("All monitors")})
	parametersToEdit.push({type: "edit", id: "MonitorNumber", default: 1, content: "Expression", WarnIfEmpty: true, UseUpDown: true, range: "1-"ActionsWithMonitorNumberOfMonitors})
	
	parametersToEdit.push({type: "Label", label:  lang("Output variables")})
	
	parametersToEdit.push({type: "Label", label:  lang("Brightness") ": " lang("Current value") " - " lang("Minimum") " - " lang("Maximum") , size: "small"})
	parametersToEdit.push({type: "Edit", id: ["VarnameBrightness", "VarnameBrightnessMin", "VarnameBrightnessMax"], default: ["Brightness","" ,"" ], content: "VariableName"})
	
	parametersToEdit.push({type: "Label", label:  lang("Contrast") ": " lang("Current value") " - " lang("Minimum") " - " lang("Maximum") , size: "small"})
	parametersToEdit.push({type: "Edit", id: ["VarnameContrast", "VarnameContrastMin", "VarnameContrastMax"], default: ["Contrast","" ,"" ], content: "VariableName"})
	
	parametersToEdit.push({type: "Label", label:  lang("Gamma") " (" lang("Not monitor specific") ")" , size: "small"})
	parametersToEdit.push({type: "Edit", id: "VarnameGamma", default: "Gamma", content: "VariableName"})
	
	parametersToEdit.push({type: "Label", label:  lang("Red gain") ": " lang("Current value") " - " lang("Minimum") " - " lang("Maximum") , size: "small" })
	parametersToEdit.push({type: "Edit", id: ["VarnameRedGain", "VarnameRedGainMin", "VarnameRedGainMax"], default: ["RedGain", "","" ], content: "VariableName"})
	parametersToEdit.push({type: "Label", label:  lang("Green gain") ": " lang("Current value") " - " lang("Minimum") " - " lang("Maximum") , size: "small" })
	parametersToEdit.push({type: "Edit", id: ["VarnameGreenGain", "VarnameGreenGainMin", "VarnameGreenGainMax"], default: ["GreenGain", "", ""], content: "VariableName"})
	parametersToEdit.push({type: "Label", label:  lang("Blue gain") ": " lang("Current value") " - " lang("Minimum") " - " lang("Maximum") , size: "small" })
	parametersToEdit.push({type: "Edit", id: ["VarnameBlueGain", "VarnameBlueGainMin", "VarnameBlueGainMax"], default: ["BlueGain","" , ""], content: "VariableName"})
	
	parametersToEdit.push({type: "Label", label:  lang("Color temperature"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "VarnameColorTemperature", default: "ColorTemperature", content: "VariableName"})

	return parametersToEdit
}

GenerateNameActionGet_Monitor_Settings(ID)
{
	global
	
	return lang("Get_Monitor_Settings") 
	
}


CheckSettingsActionGet_Monitor_Settings(ID)
{
	global

	
	if (GUISettingsOfElement%ID%WhetherChangeBrightness = 1)
	{
		GuiControl,Enable,GUISettingsOfElementSlideOf%ID%brightness
		GuiControl,Enable,GUISettingsOfElement%ID%brightness
	}
	else
	{
		GuiControl,Disable,GUISettingsOfElementSlideOf%ID%brightness
		GuiControl,Disable,GUISettingsOfElement%ID%brightness
	}
	
	if (GUISettingsOfElement%ID%WhetherChangeContrast = 1)
	{
		GuiControl,Enable,GUISettingsOfElementSlideOf%ID%contrast
		GuiControl,Enable,GUISettingsOfElement%ID%contrast
	}
	else
	{
		GuiControl,Disable,GUISettingsOfElementSlideOf%ID%contrast
		GuiControl,Disable,GUISettingsOfElement%ID%contrast
	}
	
	if (GUISettingsOfElement%ID%WhetherChangeGamma = 1)
	{
		GuiControl,Enable,GUISettingsOfElementSlideOf%ID%gamma
		GuiControl,Enable,GUISettingsOfElement%ID%gamma
	}
	else
	{
		GuiControl,Disable,GUISettingsOfElementSlideOf%ID%gamma
		GuiControl,Disable,GUISettingsOfElement%ID%gamma
	}
	
	if (GUISettingsOfElement%ID%WhetherChangeColorTemperature = 1)
	{
		GuiControl,Enable,GUISettingsOfElement%ID%ColorTemperature
	}
	else
	{
		GuiControl,Disable,GUISettingsOfElement%ID%ColorTemperature
	}
	
	
	
}