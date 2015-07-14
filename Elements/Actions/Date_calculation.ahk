iniAllActions.="Date_Calculation|" ;Add this action to list of all actions on initialisation

runActionDate_Calculation(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varname)
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Output variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Output variable name '%1%'",varname)) )
		return
	}
	
	local VarValue:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varvalue)
	
	;~ if (v_GetVariabletype(InstanceID,ThreadID,VarValue)!="date")
	;~ {
		
		;~ logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable " VarValue " is not date format.")
		;~ MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Variable '%1%' is not date format.",VarValue))
		;~ return
	;~ }
	
	local VarValue2
	
	local tempTime:=v_GetVariable(InstanceID,ThreadID,VarValue,"Date")
	local tempTime2
	local tempCount
	local tempOperation:=%ElementID%Operation
	
	local tempUnit
	if %ElementID%Unit=1 ;milliseconds
	{
		tempUnit=Seconds ;It will be calculated to seconds later
	}
	else if %ElementID%Unit=2
		tempUnit=Seconds
	else if %ElementID%Unit=3
		tempUnit=Minutes
	else if %ElementID%Unit=3
		tempUnit=Hours
	else if %ElementID%Unit=4
		tempUnit=Days
	
	if tempTime is time
	{
		if tempOperation=1 ;add a time period
		{
			tempCount:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%Units)
			if tempCount is not number
			{
				logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Unit count is not a number.")
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Unit count")))
				return
			}
			if %ElementID%Unit=1
			{
				tempCount:=round(tempCount/1000.0) ;Trim off milliseconds
			}
			envadd,tempTime,%tempCount%,%tempUnit%
		;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)
			
			v_SetVariable(InstanceID,ThreadID,varname,tempTime,"Date")
		}
		else ;Calculate time difference
		{
			VarValue2:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varvalue2)
			
			;~ if (v_GetVariabletype(InstanceID,ThreadID,VarValue2)!="date")
			;~ {
				;~ logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable " VarValue2 " is not date format.")
				;~ MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Variable '%1%' is not date format.",VarValue2))
				;~ return
			;~ }
			
			
			tempTime2:=v_GetVariable(InstanceID,ThreadID,VarValue2,"Date")
			if tempTime2 is time
			{
				;~ MsgBox %tempTime% - %tempTime2%
				envsub,tempTime2,%tempTime%,%tempUnit%
				;~ MsgBox %tempTime2%
			;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)
				
				if %ElementID%Unit=1
				{
					;~ MsgBox
					tempTime2:=tempTime2*1000 ;Calculate to milliseconds
				}
				
				v_SetVariable(InstanceID,ThreadID,varname,tempTime2)
			}
			else
			{
				logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable " VarValue2 " does not contain a date.")
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Variable '%1%' is does not contain a date.",VarValue2))
				return
			}
		}
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	}
	else
	{
		
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable " VarValue " does not contain a date.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Variable '%1%' is does not contain a date.",VarValue))
		return
	}
	

	
	return
}
getNameActionDate_Calculation()
{
	return lang("Date_Calculation")
}
getCategoryActionDate_Calculation()
{
	return lang("Variable")
}

getParametersActionDate_Calculation()
{
	global
	parametersToEdit:=["Label|" lang("Output variable name"),"VariableName|CalculatedTime|Varname","Label|" lang("Input variable name"),"VariableName|InputTime|VarValue","Label|" lang("Operation"),"Radio|1|Operation|" lang("Add a period") ";" lang("Calculate time difference") ,"Label| " lang("How many units to add"),"Text|10|Units","Label| " lang("Second input variable Name"),"Text|a_now|VarValue2","Label| " lang("Which unit"),"Radio|2|Unit|" lang("Milliseconds") ";" lang("Seconds") ";" lang("Minutes") ";" lang("Hours") ";" lang("Days")]
	
	return parametersToEdit
}

GenerateNameActionDate_Calculation(ID)
{
	global
	local tempstring
	local tempstringUnit
	local tempstring2
	local tempchar
	
	if GUISettingsOfElement%ID%Unit1=1
		tempstringUnit:= lang("Milliseconds")
	else if GUISettingsOfElement%ID%Unit2=1
		tempstringUnit:= lang("Seconds")
	else if GUISettingsOfElement%ID%Unit3=1
		tempstringUnit:= lang("Minutes")
	else if GUISettingsOfElement%ID%Unit4=1
		tempstringUnit:= lang("Hours")
	else if GUISettingsOfElement%ID%Unit5=1
		tempstringUnit:= lang("Days")
	
	if GUISettingsOfElement%ID%Operation1=1
	{
		StringLeft,tempchar,GUISettingsOfElement%ID%Units,1
		if tempchar=-
		{
			StringTrimLeft,tempstring2,GUISettingsOfElement%ID%Units ,1
			tempstring:= lang("Subtract %1% from %2%", tempstring2 " " tempstringUnit,GUISettingsOfElement%ID%varvalue )
		}
		else
			tempstring:= lang("Add %1% to %2%",GUISettingsOfElement%ID%Units " " tempstringUnit,GUISettingsOfElement%ID%varvalue )
	}
	else
	{
		tempstring:= lang("Calculate time difference between %1% and %2% in %3%",GUISettingsOfElement%ID%varvalue ,GUISettingsOfElement%ID%varvalue2 ,tempstringUnit)
		
	}
	return % lang("Date_Calculation") "`n" tempstring
	
}


CheckSettingsActionDate_Calculation(ID)
{
	
	;~ MsgBox % GUISettingsOfElement%ID%Operation1 "-" GUISettingsOfElement%ID%Operation
	if (GUISettingsOfElement%ID%Operation1 = 1)
	{
		GuiControl,Enable,GUISettingsOfElement%ID%Units
		GuiControl,Disable,GUISettingsOfElement%ID%VarValue2
	}
	else 
	{
		GuiControl,Disable,GUISettingsOfElement%ID%Units
		GuiControl,Enable,GUISettingsOfElement%ID%VarValue2
		
	}

	
}