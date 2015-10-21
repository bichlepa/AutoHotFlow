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
	
	VarnameRedDrive:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameRedDrive) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameRedDrive)) and VarnameRedDrive!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameRedDrive "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameRedDrive)) )
		return
	}
	VarnameRedDriveMin:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameRedDriveMin) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameRedDriveMin)) and VarnameRedDriveMin!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameRedDriveMin "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameRedDriveMin)) )
		return
	}
	VarnameRedDriveMax:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameRedDriveMax) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameRedDriveMax)) and VarnameRedDriveMax!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameRedDriveMax "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameRedDriveMax)) )
		return
	}
	VarnameGreenDrive:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameGreenDrive) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameGreenDrive)) and VarnameGreenDrive!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameGreenDrive "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameGreenDrive)) )
		return
	}
	VarnameGreenDriveMin:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameGreenDriveMin) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameGreenDriveMin)) and VarnameGreenDriveMin!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameGreenDriveMin "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameGreenDriveMin)) )
		return
	}
	VarnameGreenDriveMax:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameGreenDriveMax) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameGreenDriveMax)) and VarnameGreenDriveMax!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameGreenDriveMax "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameGreenDriveMax)) )
		return
	}
	VarnameBlueDrive:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameBlueDrive) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameBlueDrive)) and VarnameBlueDrive!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameBlueDrive "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameBlueDrive)) )
		return
	}
	VarnameBlueDriveMin:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameBlueDriveMin) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameBlueDriveMin)) and VarnameBlueDriveMin!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameBlueDriveMin "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameBlueDriveMin)) )
		return
	}
	VarnameBlueDriveMax:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameBlueDriveMax) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameBlueDriveMax)) and VarnameBlueDriveMax!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameBlueDriveMax "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameBlueDriveMax)) )
		return
	}
	
	VarnameColorTemperature:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameColorTemperature) ;"varname" is the parameter ID
	if ((not v_CheckVariableName(VarnameColorTemperature)) and VarnameColorTemperature!="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameColorTemperature "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameColorTemperature)) )
		return
	}
	
	;~ VarnameGamma:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarnameGamma) ;"varname" is the parameter ID
	;~ if ((not v_CheckVariableName(VarnameGamma)) and VarnameGamma!="")
	;~ {
		;~ logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" VarnameGamma "' is not valid")
		;~ MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",VarnameGamma)) )
		;~ return
	;~ }
	
	
	
	
	
	
	
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
			v_SetVariable(InstanceID,ThreadID,VarnameBrightness,result.Current)
		if (VarnameBrightnessmin!="")
			v_SetVariable(InstanceID,ThreadID,VarnameBrightnessmin,result.Minimum)
		if (VarnameBrightnessmax!="")
			v_SetVariable(InstanceID,ThreadID,VarnameBrightnessmax,result.Maximum)
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
			v_SetVariable(InstanceID,ThreadID,VarnameContrast,result.Current)
		if (VarnameContrastmin!="")
			v_SetVariable(InstanceID,ThreadID,VarnameContrastmin,result.Minimum)
		if (VarnameContrastmax!="")
			v_SetVariable(InstanceID,ThreadID,VarnameContrastmax,result.Maximum)
	}
	
	if (VarnameRedGain!="" or VarnameRedGainMin!="" or VarnameRedGainMax!="")
	{
		result:=ActionsWithMonitorDisplay.GetMonitorRedGreenOrBlueGain(MonitorNumber,0)
		if (substr(result,1,1)="*")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Couldn't get monitor red gain. Error code: " result)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Couldn't get monitor setting: %1%",lang("Red gain")) ". " lang("Error code: %1%",result))
			return
		}
		if (VarnameRedGain!="")
			v_SetVariable(InstanceID,ThreadID,VarnameRedGain,result.Current)
		if (VarnameRedGainmin!="")
			v_SetVariable(InstanceID,ThreadID,VarnameRedGainmin,result.Minimum)
		if (VarnameRedGainmax!="")
			v_SetVariable(InstanceID,ThreadID,VarnameRedGainmax,result.Maximum)
	}
	if (VarnameGreenGain!="" or VarnameGreenGainMin!="" or VarnameGreenGainMax!="")
	{
		result:=ActionsWithMonitorDisplay.GetMonitorRedGreenOrBlueGain(MonitorNumber,1)
		if (substr(result,1,1)="*")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Couldn't get monitor green gain. Error code: " result)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Couldn't get monitor setting: %1%",lang("Green gain")) ". " lang("Error code: %1%",result))
			return
		}
		if (VarnameGreenGain!="")
			v_SetVariable(InstanceID,ThreadID,VarnameGreenGain,result.Current)
		if (VarnameGreenGainmin!="")
			v_SetVariable(InstanceID,ThreadID,VarnameGreenGainmin,result.Minimum)
		if (VarnameGreenGainmax!="")
			v_SetVariable(InstanceID,ThreadID,VarnameGreenGainmax,result.Maximum)
	}
	if (VarnameBlueGain!="" or VarnameBlueGainMin!="" or VarnameBlueGainMax!="")
	{
		result:=ActionsWithMonitorDisplay.GetMonitorRedGreenOrBlueGain(MonitorNumber,2)
		if (substr(result,1,1)="*")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Couldn't get monitor blue gain. Error code: " result)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Couldn't get monitor setting: %1%",lang("Blue gain")) ". " lang("Error code: %1%",result))
			return
		}
		if (VarnameBlueGain!="")
			v_SetVariable(InstanceID,ThreadID,VarnameBlueGain,result.Current)
		if (VarnameBlueGainmin!="")
			v_SetVariable(InstanceID,ThreadID,VarnameBlueGainmin,result.Minimum)
		if (VarnameBlueGainmax!="")
			v_SetVariable(InstanceID,ThreadID,VarnameBlueGainmax,result.Maximum)
	}
	
	if (VarnameRedDrive!="" or VarnameRedDriveMin!="" or VarnameRedDriveMax!="")
	{
		result:=ActionsWithMonitorDisplay.GetMonitorRedGreenOrBlueDrive(MonitorNumber,0)
		if (substr(result,1,1)="*")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Couldn't get monitor red drive. Error code: " result)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Couldn't get monitor setting: %1%",lang("Red drive")) ". " lang("Error code: %1%",result))
			return
		}
		if (VarnameRedDrive!="")
			v_SetVariable(InstanceID,ThreadID,VarnameRedDrive,result.Current)
		if (VarnameRedDrivemin!="")
			v_SetVariable(InstanceID,ThreadID,VarnameRedDrivemin,result.Minimum)
		if (VarnameRedDrivemax!="")
			v_SetVariable(InstanceID,ThreadID,VarnameRedDrivemax,result.Maximum)
	}
	if (VarnameGreenDrive!="" or VarnameGreenDriveMin!="" or VarnameGreenDriveMax!="")
	{
		result:=ActionsWithMonitorDisplay.GetMonitorRedGreenOrBlueDrive(MonitorNumber,1)
		if (substr(result,1,1)="*")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Couldn't get monitor green drive. Error code: " result)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Couldn't get monitor setting: %1%",lang("Green drive")) ". " lang("Error code: %1%",result))
			return
		}
		if (VarnameGreenDrive!="")
			v_SetVariable(InstanceID,ThreadID,VarnameGreenDrive,result.Current)
		if (VarnameGreenDrivemin!="")
			v_SetVariable(InstanceID,ThreadID,VarnameGreenDrivemin,result.Minimum)
		if (VarnameGreenDrivemax!="")
			v_SetVariable(InstanceID,ThreadID,VarnameGreenDrivemax,result.Maximum)
	}
	if (VarnameBlueDrive!="" or VarnameBlueDriveMin!="" or VarnameBlueDriveMax!="")
	{
		result:=ActionsWithMonitorDisplay.GetMonitorRedGreenOrBlueDrive(MonitorNumber,2)
		if (substr(result,1,1)="*")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Couldn't get monitor blue drive. Error code: " result)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Couldn't get monitor setting: %1%",lang("Blue drive")) ". " lang("Error code: %1%",result))
			return
		}
		if (VarnameBlueDrive!="")
			v_SetVariable(InstanceID,ThreadID,VarnameBlueDrive,result.Current)
		if (VarnameBlueDrivemin!="")
			v_SetVariable(InstanceID,ThreadID,VarnameBlueDrivemin,result.Minimum)
		if (VarnameBlueDrivemax!="")
			v_SetVariable(InstanceID,ThreadID,VarnameBlueDrivemax,result.Maximum)
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
	
	;~ if (VarnameGamma!="")
	;~ {
		;~ result:=ActionsWithMonitorDisplay.GetDeviceGammaRamp()
		;~ if (substr(result,1,1)="*")
		;~ {
			;~ logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Couldn't get monitor gamma. Error code: " result)
			;~ MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Couldn't get monitor setting: %1%",lang("Gamma")) ". " lang("Error code: %1%",result))
			;~ return
		;~ }
		;~ v_SetVariable(InstanceID,ThreadID,VarnameGamma,result)
	;~ }
	
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
	
	;~ parametersToEdit.push({type: "Label", label:  lang("Gamma") " (" lang("Not monitor specific") ")" , size: "small"})
	;~ parametersToEdit.push({type: "Edit", id: "VarnameGamma", default: "Gamma", content: "VariableName"})
	
	parametersToEdit.push({type: "Label", label:  lang("Red gain") ": " lang("Current value") " - " lang("Minimum") " - " lang("Maximum") , size: "small" })
	parametersToEdit.push({type: "Edit", id: ["VarnameRedGain", "VarnameRedGainMin", "VarnameRedGainMax"], default: ["RedGain", "","" ], content: "VariableName"})
	parametersToEdit.push({type: "Label", label:  lang("Green gain") ": " lang("Current value") " - " lang("Minimum") " - " lang("Maximum") , size: "small" })
	parametersToEdit.push({type: "Edit", id: ["VarnameGreenGain", "VarnameGreenGainMin", "VarnameGreenGainMax"], default: ["GreenGain", "", ""], content: "VariableName"})
	parametersToEdit.push({type: "Label", label:  lang("Blue gain") ": " lang("Current value") " - " lang("Minimum") " - " lang("Maximum") , size: "small" })
	parametersToEdit.push({type: "Edit", id: ["VarnameBlueGain", "VarnameBlueGainMin", "VarnameBlueGainMax"], default: ["BlueGain","" , ""], content: "VariableName"})
	
	parametersToEdit.push({type: "Label", label:  lang("Red drive") ": " lang("Current value") " - " lang("Minimum") " - " lang("Maximum") , size: "small" })
	parametersToEdit.push({type: "Edit", id: ["VarnameReddrive", "VarnameReddriveMin", "VarnameReddriveMax"], default: ["RedDrive", "","" ], content: "VariableName"})
	parametersToEdit.push({type: "Label", label:  lang("Green drive") ": " lang("Current value") " - " lang("Minimum") " - " lang("Maximum") , size: "small" })
	parametersToEdit.push({type: "Edit", id: ["VarnameGreendrive", "VarnameGreendriveMin", "VarnameGreendriveMax"], default: ["GreenDrive", "", ""], content: "VariableName"})
	parametersToEdit.push({type: "Label", label:  lang("Blue drive") ": " lang("Current value") " - " lang("Minimum") " - " lang("Maximum") , size: "small" })
	parametersToEdit.push({type: "Edit", id: ["VarnameBluedrive", "VarnameBluedriveMin", "VarnameBluedriveMax"], default: ["BlueDrive","" , ""], content: "VariableName"})
	
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

	

	
	
}