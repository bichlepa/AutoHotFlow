;Always add this element class name to the global list
x_RegisterElementClass("&ElementType&_&Name&")

;Element type of the element
Element_getElementType_&ElementType&_&Name&()
{
	return "&ElementType&"
}

;Name of the element
Element_getName_&ElementType&_&Name&()
{
	return lang("&Name&")
}

;Category of the element
Element_getCategory_&ElementType&_&Name&()
{
	return lang("&Category&")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_&ElementType&_&Name&()
{
	return "&package&"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_&ElementType&_&Name&()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "&Level&"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_&ElementType&_&Name&()
{
#if icon
	return "&icon&"
#endif ;icon
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_&ElementType&_&Name&()
{
	;"Stable" or "Experimental"
	return "&stability&"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_&ElementType&_&Name&(Environment)
{
	parametersToEdit:=Object()
	
#if par_label 
	parametersToEdit.push({type: "Label", label: lang("My label")})
#endif ;par_label
#if par_radio 
	parametersToEdit.push({type: "Radio", id: "radio", result: "number", default: 1, choices: [lang("Choice %1%", 1), lang("Choice %1%", 2), lang("Choice %1%", 3)]})
#endif ;par_radio
#if par_radioEnum
	parametersToEdit.push({type: "Radio", id: "radioEnum", result: "enum", default: 1, choices: [lang("Cat"), lang("Dog"), lang("Bird")], enum: ["Cat", "Dog", "Bird"]})
#endif ;par_radioEnum
#if par_checkbox 
	parametersToEdit.push({type: "Checkbox", id: "checkbox", default: 0, label: lang("Label")})
#endif ;par_checkbox
#if par_EditString 
	parametersToEdit.push({type: "Edit", id: "editString", content: "String"})
#endif ;par_EditString
#if par_editExpression 
	parametersToEdit.push({type: "Edit", id: "editExpression", default: 123, content: "Expression", WarnIfEmpty: true})
#endif ;par_editExpression
#if par_editStringOrExpression 
	parametersToEdit.push({type: "Edit", id: "editStringOrExpression", default: "MyVar", content: ["String", "Expression"], contentID: "expression", contentDefault: "string", WarnIfEmpty: true})
#endif
#if par_editVariableName
	parametersToEdit.push({type: "Edit", id: "editVariableName", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
#endif ;par_editVariableName
#if par_editMultiLine
	parametersToEdit.push({type: "multilineEdit", id: "editMultiLine", default: "", WarnIfEmpty: true})
#endif ;par_editMultiLine
#if par_editTwoExpressions
	parametersToEdit.push({type: "Edit", id: ["editTwoExpressions1", "editTwoExpressions2"], default: [10, 20], content: "Expression", WarnIfEmpty: true})
#endif
#if par_DropDownString
	parametersToEdit.push({type: "DropDown", id: "DropDownString", default: "jpg", choices: ["bmp", "jpg", "png"], result: "string"})
#endif ;par_DropDownString
#if par_ComboBoxString
	parametersToEdit.push({type: "ComboBox", id: "ComboBoxString", content: "String", WarnIfEmpty: true, result: "string", choices: ["bmp", "jpg", "png"]})
#endif ;par_ComboBoxString
#if par_ListBoxString
	parametersToEdit.push({type: "ListBox", id: "ListBoxString", result: "String", choices: ["bmp", "jpg", "png"], multi: True})
#endif ;par_ListBoxString
#if par_Slider
	parametersToEdit.push({type: "Slider", id: "Slider", default: 2, options: "Range0-100 tooltip"})
#endif ;par_Slider
#if par_file 
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file")})
#endif ;par_file
#if par_folder
	parametersToEdit.push({type: "Folder", id: "folder", label: lang("Select a folder")})
#endif ;par_folder
#if par_button
	parametersToEdit.push({type: "button", id: "button", goto: "&ElementType&_&Name&_ButtonClick", label: lang("Click me")})
#endif ;par_button
	
#if addWindowSelector
	
	; call function which adds all the required fields for window identification
	windowFunctions_addWindowIdentificationParametrization(parametersToEdit)
#endif ;addWindowSelector
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_&ElementType&_&Name&(Environment, ElementParameters)
{
#if addWindowSelector
	
	; generate window identification name
	nameString := windowFunctions_generateWindowIdentificationName(ElementParameters)
	
	return lang("&Name&") ": " nameString
#else ;addWindowSelector
	return lang("&Name&") 
#endif ;addWindowSelector
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_&ElementType&_&Name&(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_&ElementType&_&Name&(Environment, ElementParameters)
{
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
#if customParameterEvaluation
#if par_checkbox 

	checkboxValue := ElementParameters.checkbox
#endif ;par_checkbox
#if par_radio 

	radioValue := ElementParameters.radio
#endif ;par_radio
#if par_radioEnum

	radioEnumValue := ElementParameters.radioEnum
#endif ;par_radioEnum
#if par_editstring 

	editstringValue := x_replaceVariables(Environment, ElementParameters.editstring)
#endif ;par_editstring
#if par_editExpression 

	evRes := x_evaluateExpression(Environment, ElementParameters.editExpression)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.editExpression) "`n`n" evRes.error) 
		return
	}
	editExpressionValue := evRes.result
	if editExpressionValue is not number
	{
		x_finish(Environment, "exception", lang("%1% is not a number: %2%",lang("Expression value"), editExpressionValue))
		return
	}
#endif ;par_editExpression
#if par_editStringOrExpression 

	if (ElementParameters.Expression = "expression")
	{
		evRes := x_EvaluateExpression(Environment, ElementParameters.editStringOrExpression)
		if (evRes.error)
		{
			;On error, finish with exception and return
			x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.editStringOrExpression) "`n`n" evRes.error) 
			return
		}
		else
		{
			editStringOrExpressionValue := evRes.result
		}
	}
	else
		editStringOrExpressionValue := x_replaceVariables(Environment, ElementParameters.editStringOrExpression)
#endif ;par_editStringOrExpression
#if par_editVariableName

	editVariableNameValue := x_replaceVariables(Environment, ElementParameters.editVariableName)
	if not x_CheckVariableName(editVariableNameValue)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("%1% is not valid", lang("Ouput variable name '%1%'", editVariableName)))
		return
	}
#endif ;par_editVariableName
#if par_editMultiLine

	editMultiLineValue := x_replaceVariables(Environment, ElementParameters.editMultiLine)
#endif ;par_editMultiLine
#if par_editTwoExpressions

	evRes := x_evaluateExpression(Environment,ElementParameters.editTwoExpressions1)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.editTwoExpressions1) "`n`n" evRes.error) 
		return
	}
	editTwoExpressions1Value := evRes.result
	evRes := x_evaluateExpression(Environment,ElementParameters.editTwoExpressions2)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.editTwoExpressions2) "`n`n" evRes.error) 
		return
	}
	editTwoExpressions2Value := evRes.result
#endif ;par_editTwoExpressions
#if par_DropDownString 

	DropDownStringValue := ElementParameters.DropDownString
#endif ;par_DropDownString
#if par_ComboBoxString

	ComboBoxStringValue := x_replaceVariables(Environment, ElementParameters.ComboBoxString) 
#endif ;par_ComboBoxString
#if par_ListBoxString 

	ListBoxStringValue := ElementParameters.ListBoxString
	for oneListBoxStringIndex, oneListBoxString in ListBoxStringValue
	{
		;Do anything with oneListBoxString
	}
#endif ;par_ListBoxString
#if par_Slider

	evRes := x_evaluateExpression(Environment, ElementParameters.Slider)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.Slider) "`n`n" evRes.error) 
		return
	}
	SliderValue:=evRes.result

#endif ;par_Slider
#if par_file 

	fileValue := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.file))
	if not FileExist(fileValue)
	{
		x_finish(Environment, "exception", lang("%1% '%2%' does not exist.",lang("File"), fileValue)) 
		return
	}
#endif ;par_file
#if par_folder

	folderValue := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.folder))
#endif ;par_folder
#endif ;customParameterEvaluation

#if addWindowSelector

	; evaluate window parameters
	EvaluatedWindowParameters := windowFunctions_evaluateWindowParameters(EvaluatedParameters)
	if (EvaluatedWindowParameters.exception)
	{
		x_finish(Environment, "exception", EvaluatedWindowParameters.exception)
		return
	}

	; get window ID
	windowID := windowFunctions_getWindowID(EvaluatedWindowParameters)
	if (windowID.exception)
	{
		x_finish(Environment, "exception", windowID.exception)
		return
	}
	
	if not windowID
	{
		x_finish(Environment, "no")
		return
	}
	
	; write found window ID as thread variable
	x_SetVariable(Environment, "A_WindowID", windowID, "Thread") ;Example code. Remove it
	;Do some actions here
	x_finish(Environment, "yes")
	
#endif ;addWindowSelector

	x_SetVariable(Environment, Varname, VarValue) ;Example
	
#if addNothing
	MsgBox, 4, Choose, Yes or no
	IfMsgBox yes
		x_finish(Environment, "yes")
	else
		x_finish(Environment, "no")
		
	return
	
#endif ;addNothing

#if addCustomGUI
	guiID := x_GetMyUniqueExecutionID(Environment)
	gui, %guiID%: +label&ElementType&_&Name&_On
	
	gui, %guiID%: add, button, g&ElementType&_&Name&_ChangeButtonText, Change button text

	gui, %guiID%: add, button, g&ElementType&_&Name&_OnCloseYes, Yes
	gui, %guiID%: add, button, g&ElementType&_&Name&_OnCloseNo, No
	
	gui, %guiID%: show
#endif ;addCustomGUI

#if addSeparateAhkThread
	;Unfortunately we can't use the function lang() inside the exported code. But we can export them inside variables befor use.
	inputVars := {header: lang("Hello"), message: lang("Input some text")}
	outputVars := ["enteredText"]
	outputVars.push("resultmessage", "result") ;We use those variables to find out whether an error was found during execution 
	code =
	( ` , LTrim %
		InputBox, enteredText, %header%, %message%
		if errorlevel
		{
			result := "no"
			resultmessage := "User dismissed the dialog."
		}
		else
		{
			result := "yes"
		}
	)
	;We want later to translate the text inside message. Add the text here inside comments, so the translation tool can find it.
	;Translations: lang("User dismissed the dialog.")

	;create a function object as callback for the other AHK thread
	functionObject := x_NewFunctionObject(Environment, "&ElementType&_&Name&_FinishExecution", ElementParameters)
	x_SetExecutionValue(Environment, "functionObject", functionObject)
	x_SetExecutionValue(Environment, "Varname", Varname)
	;Start new AHK thread
	x_ExecuteInNewAHKThread(Environment, functionObject, code, inputVars, outputVars)
#endif ;addSeparateAhkThread

}

#if addCustomGUI
;Handle user input

&ElementType&_&Name&_OnCloseYes()
{
	Environment := x_GetMyEnvironmentFromExecutionID(A_Gui)
	gui, destroy
	x_finish(Environment, "yes")
}
&ElementType&_&Name&_OnCloseNo()
{
	Environment := x_GetMyEnvironmentFromExecutionID(A_Gui)
	gui, destroy
	x_finish(Environment, "no")
}

&ElementType&_&Name&_ChangeButtonText()
{
	guicontrol,, %A_GuiControl%, Button text changed
}

#endif ;addCustomGUI

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_&ElementType&_&Name&(Environment, ElementParameters)
{
#if addCustomGUI
	;Close window if currently opened
	guiID := x_GetMyUniqueExecutionID(Environment)
	gui, %guiID%: destroy
#endif ;addCustomGUI
#if addSeparateAhkThread
	;Stop AHK thread
	x_ExecuteInNewAHKThread_Stop(Environment)
#endif ;addSeparateAhkThread
}


#if addSeparateAhkThread
&ElementType&_&Name&_FinishExecution(Environment, ElementParameters, values)
{
	if (values.result = "yes")
	{
		x_SetVariable(Environment, "A_text", values.enteredText, "thread")
	}
	x_finish(Environment, values.result, values.message)
}
#endif ;addSeparateAhkThread

#if par_button
&ElementType&_&Name&_ButtonClick()
{
	MsgBox user clicked me
}
#endif ;par_button
