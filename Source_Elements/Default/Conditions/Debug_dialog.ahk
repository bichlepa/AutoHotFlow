;Always add this element class name to the global list
x_RegisterElementClass("Condition_Debug_Dialog")

;Element type of the element
Element_getElementType_Condition_Debug_Dialog()
{
	return "condition"
}

;Name of the element
Element_getName_Condition_Debug_Dialog()
{
	return x_lang("Debug_Dialog")
}

;Category of the element
Element_getCategory_Condition_Debug_Dialog()
{
	return x_lang("Debugging")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Condition_Debug_Dialog()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Condition_Debug_Dialog()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Condition_Debug_Dialog()
{
	return "bug.png"
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Condition_Debug_Dialog()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Condition_Debug_Dialog(Environment)
{
	parametersToEdit := Object()
	; we have no parameters here
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Condition_Debug_Dialog(Environment, ElementParameters)
{
	return % x_lang("Debug_dialog")
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Condition_Debug_Dialog(Environment, ElementParameters, staticValues)
{	
	; Noting to check
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Condition_Debug_Dialog(Environment, ElementParameters)
{
	;Start building GUI
	guiID := x_GetMyUniqueExecutionID(Environment)
	gui, %guiID%: +LabelCondition_Debug_Dialog_On ;This label leads to a jump label beneath. It's needed if user closes the window

	; add variable list header with update button
	gui, %guiID%:add, text, xm ym w90, % x_lang("Variable list")
	gui, %guiID%:add, button, xm Y+10 w80 h20 gCondition_Debug_DialogButtonUpdateVariableList, % x_lang("Update")

	; add variable value header with type selector and unicode checkbox
	gui, %guiID%:add, text, xm+210 ym w90, % x_lang("Type and value")
	gui, %guiID%:add, DropDownList, X+10 w130 gCondition_Debug_DialogValueEditField hwndHWNDVarTypeDropDown disabled, % x_lang("Normal") "|" x_lang("Object")
	x_SetExecutionValue(Environment, "HWNDVarTypeDropDown", HWNDVarTypeDropDown)
	gui, %guiID%:add, checkbox, xp-100 Y+10 w200 gCondition_Debug_DialogVarList hwndHWNDUnicodeCheckbox, % x_lang("Convert special characters")
	x_SetExecutionValue(Environment, "HWNDUnicodeCheckbox", HWNDUnicodeCheckbox)

	; add list box with variable names
	gui, %guiID%:add, listbox, xm Y+10 w200 h200 hwndHWNDVarList gCondition_Debug_DialogVarList
	x_SetExecutionValue(Environment, "HWNDVarList", HWNDVarList)
	
	; add edit field where user can see and change the variable value
	gui, %guiID%:add, edit, X+10 w260 yp h200 hwndHWNDValueEditField gCondition_Debug_DialogValueEditField
	x_SetExecutionValue(Environment, "HWNDValueEditField", HWNDValueEditField)

	; add row of buttons where user can do something with the varibles
	gui, %guiID%:add, button, xm w200 h30 gCondition_Debug_DialogButtonDeleteVariable hwndHWNDDeleteVariableButton Disabled, % x_lang("Delete variable")
	x_SetExecutionValue(Environment, "HWNDDeleteVariableButton", HWNDDeleteVariableButton)
	gui, %guiID%:add, button, X+10 w260 h30 gCondition_Debug_DialogButtonChangeValue hwndHWNDChangeValueButton Disabled, % x_lang("Change value")
	x_SetExecutionValue(Environment, "HWNDChangeValueButton", HWNDChangeValueButton)

	; add row of buttons where user can select the desired result of the dialog element
	gui, %guiID%:add, text, xm Y+20 w90, % x_lang("Result")
	gui, %guiID%:add, button, Y+10 xm w100 h30 gCondition_Debug_DialogButtonYes, % x_lang("Yes")
	gui, %guiID%:add, button, X+10 yp w100 h30 gCondition_Debug_DialogButtonNo, % x_lang("No")

	; update the list of variables
	Condition_Debug_Dialog_UpdateVariableList(guiID)

	; show gui
	gui, %guiID%:show, , % tempTitle
}

; update the variable list in gui
Condition_Debug_Dialog_UpdateVariableList(guiID)
{
	; get environment and required control HWNDs
	environment := x_GetMyEnvironmentFromExecutionID(guiID)
	HWNDChangeValueButton := x_GetExecutionValue(Environment, "HWNDChangeValueButton")
	HWNDDeleteVariableButton := x_GetExecutionValue(Environment, "HWNDDeleteVariableButton")
	HWNDVarList := x_GetExecutionValue(Environment, "HWNDVarList")
	HWNDValueEditField := x_GetExecutionValue(Environment, "HWNDValueEditField")
	HWNDVarTypeDropDown := x_GetExecutionValue(Environment, "HWNDVarTypeDropDown")

	; start with an empty list
	variableNameList := "|"
	
	; search for loop variables
	for tempIndex, tempVarName in x_GetListOfLoopVars(environment)
	{
		if (a_index = 1)
			variableNameList .= "--- " x_lang("Loop variables") " ---|"
		variableNameList .= tempVarName "|"
	}
	
	; search for thread variables
	for tempIndex, tempVarName in x_GetListOfThreadVars(environment)
	{
		if (a_index = 1)
			variableNameList.= "--- " x_lang("Thread variables") " ---|"
		variableNameList .= tempVarName "|"
	}
	
	; search for instance variables
	for tempIndex, tempVarName in x_GetListOfInstanceVars(environment)
	{
		if (a_index = 1)
			variableNameList.= "--- " x_lang("Instance variables") " ---|"
		variableNameList .= tempVarName "|"
	}
	
	; search for static variables
	for tempIndex, tempVarName in x_GetListOfStaticVars(environment)
	{
		if (a_index = 1)
			variableNameList .= "--- " x_lang("Static variables") " ---|"
		variableNameList .= tempVarName "|"
	}

	; search for global variables
	for tempIndex, tempVarName in x_GetListOfGlobalVars(environment)
	{
		if (a_index = 1)
			variableNameList .= "--- " x_lang("Global variables") " ---|"
		variableNameList .= tempVarName "|"
	}
	
	; save the variable list as execution value for later use
	x_SetExecutionValue(environment, "VariableNames", variableNameList)

	; show the variable list in the gui
	guicontrol, %guiID%:, % HWNDVarList, %variableNameList%
	
	; clear and disable the value edit field and disable some buttons
	guicontrol, %guiID%:, % HWNDValueEditField
	GuiControl, %guiID%:disable, % HWNDValueEditField
	GuiControl, %guiID%:Disable, % HWNDDeleteVariableButton
	GuiControl, %guiID%:Disable, % HWNDChangeValueButton

	; disable variable type dropdown and checkbox and hide dropdown value
	GuiControl, %guiID%:Disable, % HWNDVarTypeDropDown
	GuiControl, %guiID%:choose, % HWNDVarTypeDropDown, 0
}

; function is called when user clicks on the button to update the variable lists
Condition_Debug_DialogButtonUpdateVariableList()
{
	; call the function which upates the variable list
	Condition_Debug_Dialog_UpdateVariableList(a_gui)
}

; function is calles when user changes the value of the variable in the GUI
Condition_Debug_DialogValueEditField()
{
	; get environment and required control HWNDs
	guiID := a_gui
	environment := x_GetMyEnvironmentFromExecutionID(guiID)
	HWNDChangeValueButton := x_GetExecutionValue(Environment, "HWNDChangeValueButton")

	; enable the button "change value" and highlight it
	GuiControl, %guiID%:enable, % HWNDChangeValueButton
	GuiControl, %guiID%:+default, % HWNDChangeValueButton
}

; funciton is called when user selects a variable from the variable list
Condition_Debug_DialogVarList()
{
	; get environment and required control HWNDs
	guiID := a_gui
	environment := x_GetMyEnvironmentFromExecutionID(guiID)
	HWNDChangeValueButton := x_GetExecutionValue(Environment, "HWNDChangeValueButton")
	HWNDDeleteVariableButton := x_GetExecutionValue(Environment, "HWNDDeleteVariableButton")
	HWNDVarList := x_GetExecutionValue(Environment, "HWNDVarList")
	HWNDValueEditField := x_GetExecutionValue(Environment, "HWNDValueEditField")
	HWNDVarTypeDropDown := x_GetExecutionValue(Environment, "HWNDVarTypeDropDown")
	HWNDUnicodeCheckbox := x_GetExecutionValue(Environment, "HWNDUnicodeCheckbox")

	; get the selected variable name
	guicontrolget, selectedVarName,, % HWNDVarList
	If (substr(selectedVarName, 1, 3) = "---" or not selectedVarName)
	{
		; user has selected the entry which is a separator between different types of variables, or nothing is selected
		
		; disable variable type dropdown and hide value
		GuiControl, %guiID%:Disable, % HWNDVarTypeDropDown
		GuiControl, %guiID%:choose, % HWNDVarTypeDropDown, 0

		; disable the buttons "delete variable" and clear and disable the value edit field
		GuiControl ,%guiID%:Disable, % HWNDDeleteVariableButton
		GuiControl, %guiID%:, % HWNDValueEditField, %A_Space%
		GuiControl, %guiID%:disable, % HWNDValueEditField

		; clear the (probably) saved variable name and type 
		x_SetExecutionValue(environment, "SelectedVarName", "")
		x_SetExecutionValue(environment, "SelectedVarType", "")
	}
	Else
	{
		; user selected a variable name

		; get the variable content and type
		variableContent := x_GetVariable(environment, selectedVarName)
		variableType := x_getVariableType(environment, selectedVarName)

		if (variableType = "object")
		{
			; the variable contains an object. We habe to convert it to readable format
			guicontrolget, convertUnicode,, % HWNDUnicodeCheckbox
			variableContent := x_ConvertObjToString(variableContent, convertUnicode)
		}

		; show the variable content in the edit field
		guicontrol, %guiID%:, % HWNDValueEditField, %variableContent%

		; enable variable type dropdown and set correct value
		GuiControl, %guiID%:Enable, % HWNDVarTypeDropDown
		GuiControl, %guiID%:chooseString, % HWNDVarTypeDropDown, % variableType

		; enable the button "delete variable" and the value edit field
		GuiControl, %guiID%:Enable, % HWNDValueEditField
		GuiControl, %guiID%:Enable, % HWNDDeleteVariableButton
		
		; save the variable name and type for later use 
		x_SetExecutionValue(environment, "SelectedVarName", selectedVarName)
		x_SetExecutionValue(environment, "SelectedVarType", variableType)
	}

	; we also need to disable the button "change value", since there is nothing to change
	GuiControl, %guiID%:Disable, % HWNDChangeValueButton
}

; function is triggered when  user clicks on the button "change value"
Condition_Debug_DialogButtonChangeValue()
{
	; get environment and required control HWNDs
	guiID := a_gui
	environment := x_GetMyEnvironmentFromExecutionID(guiID)
	HWNDChangeValueButton := x_GetExecutionValue(Environment, "HWNDChangeValueButton")
	HWNDVarList := x_GetExecutionValue(Environment, "HWNDVarList")
	HWNDValueEditField := x_GetExecutionValue(Environment, "HWNDValueEditField")
	HWNDVarTypeDropDown := x_GetExecutionValue(Environment, "HWNDVarTypeDropDown")

	; disable the button "change value"
	GuiControl, %guiID%:Disable, % HWNDChangeValueButton

	; get the selected variable name and type
	SelectedVarName := x_GetExecutionValue(Environment, "SelectedVarName")

	; this can't happen but we will still check it
	if not SelectedVarName
	{
		x_log(environment, "unexpected error: user clicked on button 'change value' but no variable is selected", 0)
		return
	}
	
	; get variable location
	variableLocation := x_GetVariableLocation(environment, SelectedVarName)
	
	; get new variable content and type
	guicontrolget, newVariableContent,, % HWNDValueEditField
	guicontrolget, newVariableType,, % HWNDVarTypeDropDown
	
	if (newVariableType = "object")
	{
		; the variable type is object. We have to convert the string to object
		try 
		{
			; convert
			newVariableContent := x_ConvertStringToObj(newVariableContent)
		}
		Catch
		{
			; an error occured. This is very likely since the string can be changed freely by the user
			ToolTip, "Error! The string cannot be converted to object!`nPlease correct syntax errors and try again.",,, 19
			settimer, Condition_Debug_DialogButtonDisableTooltip, 3000
			
			; reenable the button "change value", since the change was not applied
			GuiControl, %guiID%:Enable, % HWNDChangeValueButton
		}
	}

	; set the new variable value
	x_SetVariable(Environment, SelectedVarName, newVariableContent, variableLocation)
	return
}

; disables tooltip
Condition_Debug_DialogButtonDisableTooltip()
{
	ToolTip, ,,, 19
}

; function is triggered when user clicks on the button "delete value"
Condition_Debug_DialogButtonDeleteVariable()
{
	; get environment and required control HWNDs
	guiID := a_gui
	environment := x_GetMyEnvironmentFromExecutionID(guiID)
	HWNDChangeValueButton := x_GetExecutionValue(Environment, "HWNDChangeValueButton")
	HWNDDeleteVariableButton := x_GetExecutionValue(Environment, "HWNDDeleteVariableButton")
	HWNDVarList := x_GetExecutionValue(Environment, "HWNDVarList")
	HWNDValueEditField := x_GetExecutionValue(Environment, "HWNDValueEditField")

	; get the selected variable name and type
	SelectedVarName := x_GetExecutionValue(Environment, "SelectedVarName")
	SelectedVarType := x_GetExecutionValue(environment, "SelectedVarType")
	
	; also get the variable list
	variableNameList := x_GetExecutionValue(environment, "VariableNames") 
	
	; delete the variable
	x_DeleteVariable(environment, SelectedVarName)
	
	; update the variable list
	Condition_Debug_Dialog_UpdateVariableList(guiID)
	return
}

; function is triggered when user clicks on the button "yes"
Condition_Debug_DialogButtonYes()
{
	Condition_Debug_Dialog_SetResult("yes")
}
; function is triggered when user clicks on the button "no"
Condition_Debug_DialogButtonNo()
{
	Condition_Debug_Dialog_SetResult("no")
}
Condition_Debug_Dialog_SetResult(result)
{
	; destroy the gui
	gui, %a_gui%:destroy
	
	; get environment
	environment := x_GetMyEnvironmentFromExecutionID(a_gui)
	
	; finish with the requested result
	if (result = "exception")
	{
		x_finish(Environment, result, "User dismissed the dialog")
	}
	Else
	{
		x_finish(Environment, result)
	}
	return
}

; function is triggered when user closes the GUI
Condition_Debug_Dialog_OnClose()
{
	; we will make "exception" as result. There is no need for an error message, since this is expected that user can close the window.
	Condition_Debug_Dialog_SetResult("exception")
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Condition_Debug_Dialog(Environment, ElementParameters)
{
	; destroy the gui
	guiID := x_GetMyUniqueExecutionID(Environment)
	gui, %guiID%:destroy
}
