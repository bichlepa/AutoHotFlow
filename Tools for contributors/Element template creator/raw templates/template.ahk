;Always add this element class name to the global list
AllElementClasses.push("&ElementType&_&Name&")

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
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_&ElementType&_&Name&()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_&ElementType&_&Name&()
{
#if icon
	return "Source_elements\default\icons\&icon&"
#endif
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_&ElementType&_&Name&()
{
	;"Stable" or "Experimental"
	return "&stability&"
}

;Returns a list of all parameters of the element.
;Only those parameters will be saved.
Element_getParameters_&ElementType&_&Name&()
{
	parametersToEdit:=Object()
	
#if par_radio
	parametersToEdit.push({id: "radio"})
#endif
#if par_radioEnum
	parametersToEdit.push({id: "radioEnum"})
#endif
#if par_checkbox 
	parametersToEdit.push({id: "checkbox"})
#endif
#if par_editstring 
	parametersToEdit.push({id: "editstring"})
#endif
#if par_editExpression 
	parametersToEdit.push({id: "editExpression"})
#endif
#if par_editStringOrExpression
	parametersToEdit.push({id: "editStringOrExpression"})
#endif
#if par_editVariableName
	parametersToEdit.push({id: "editVariableName"})
#endif
#if par_editMultiLine
	parametersToEdit.push({id: "editMultiLine"})
#endif
#if par_editTwoExpressions
	parametersToEdit.push({id: "editTwoExpressions1"})
	parametersToEdit.push({id: "editTwoExpressions2"})
#endif
#if par_DropDownString
	parametersToEdit.push({id: "DropDownString"})
#endif
#if par_ComboBoxString
	parametersToEdit.push({id: "ComboBoxString"})
#endif
#if par_ListBoxString
	parametersToEdit.push({id: "ListBoxString"})
#endif
#if par_file
	parametersToEdit.push({id: "file"})
#endif
#if par_folder
	parametersToEdit.push({id: "folder"})
#endif
#if addWindowSelector 
	parametersToEdit.push({id: "TitleMatchMode"})
	parametersToEdit.push({id: "Wintitle"})
	parametersToEdit.push({id: "excludeTitle"})
	parametersToEdit.push({id: "winText"})
	parametersToEdit.push({id: "FindHiddenText"})
	parametersToEdit.push({id: "ExcludeText"})
	parametersToEdit.push({id: "ahk_class"})
	parametersToEdit.push({id: "ahk_exe"})
	parametersToEdit.push({id: "ahk_id"})
	parametersToEdit.push({id: "ahk_pid"})
	parametersToEdit.push({id: "FindHiddenWindow"})
#endif
	
	return parametersToEdit
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_&ElementType&_&Name&(Environment)
{
	parametersToEdit:=Object()
	
#if par_label 
	parametersToEdit.push({type: "Label", label: lang("My label")})
#endif
#if par_radio 
	parametersToEdit.push({type: "Radio", id: "radio", result: "number", default: 1, choices: [lang("Choice %1%", 1), lang("Choice %1%", 2), lang("Choice %1%", 3)]})
#endif
#if par_radioEnum
	parametersToEdit.push({type: "Radio", id: "radioEnum", result: "enum", default: 1, choices: [lang("Cat"), lang("Dog"), lang("Bird")], enum: ["Cat", "Dog", "Bird"]})
#endif
#if par_checkbox 
	parametersToEdit.push({type: "Checkbox", id: "checkbox", default: 0, label: lang("Label")})
#endif
#if par_EditString 
	parametersToEdit.push({type: "Edit", id: "editString", content: "String"})
#endif
#if par_editExpression 
	parametersToEdit.push({type: "Edit", id: "editExpression", default: 123, content: "Expression", WarnIfEmpty: true})
#endif
#if par_editStringOrExpression 
	parametersToEdit.push({type: "Edit", id: "editStringOrExpression", default: "MyVar", content: ["String", "Expression"], contentID: "expression", contentDefault: "string", WarnIfEmpty: true})
#endif
#if par_editVariableName
	parametersToEdit.push({type: "Edit", id: "editVariableName", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
#endif
#if par_editMultiLine
	parametersToEdit.push({type: "multilineEdit", id: "editMultiLine", default: "", WarnIfEmpty: true})
#endif
#if par_editTwoExpressions
	parametersToEdit.push({type: "Edit", id: ["editTwoExpressions1", "editTwoExpressions2"], default: [10, 20], content: "Expression", WarnIfEmpty: true})
#endif
#if par_DropDownString
	parametersToEdit.push({type: "DropDown", id: "DropDownString", default: "jpg", choices: ["bmp", "jpg", "png"], result: "string"})
#endif
#if par_ComboBoxString
	parametersToEdit.push({type: "ComboBox", id: "ComboBoxString", content: "String", WarnIfEmpty: true, result: "string", choices: ["bmp", "jpg", "png"]})
#endif
#if par_ListBoxString
	parametersToEdit.push({type: "ListBox", id: "ListBoxString", result: "String", choices: ["bmp", "jpg", "png"], multi: True})
#endif
#if par_Slider
	parametersToEdit.push({type: "Slider", id: "Slider", default: 2, options: "Range0-100 tooltip"})
#endif
#if par_file 
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file")})
#endif
#if par_folder
	parametersToEdit.push({type: "Folder", id: "folder", label: lang("Select a folder")})
#endif
#if par_button
	parametersToEdit.push({type: "button", id: "button", goto: "&ElementType&_&Name&_ButtonClick", label: lang("Get coordinates")})
#endif
	
#if addWindowSelector
	
	parametersToEdit.push({type: "Label", label: lang("Window identification")})
	parametersToEdit.push({type: "Label", label: lang("Title_of_Window"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "TitleMatchMode", default: 1, choices: [lang("Start_with"), lang("Contain_anywhere"), lang("Exactly")]})
	parametersToEdit.push({type: "Edit", id: "Wintitle", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Exclude_title"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "excludeTitle", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Text_of_a_control_in_Window"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "winText", content: "String"})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenText", default: 0, label: lang("Detect hidden text")})
	parametersToEdit.push({type: "Label", label: lang("Exclude_text_of_a_control_in_window"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ExcludeText", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Window_Class"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ahk_class", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Process_Name"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ahk_exe", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Unique_window_ID"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ahk_id", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Unique_Process_ID"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ahk_pid", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Hidden window"), size: "small"})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenWindow", default: 0, label: lang("Detect hidden window")})
	parametersToEdit.push({type: "Label", label: lang("Import window identification"), size: "small"})
	parametersToEdit.push({type: "button", goto: "&ElementType&_&Name&_ButtonWindowAssistant", label: lang("Import window identification")})
#endif
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_&ElementType&_&Name&(Environment, ElementParameters)
{
#if addWindowSelector
	
	local tempNameString
	if (ElementParameters.Wintitle)
	{
		if (ElementParameters.TitleMatchMode=1)
			tempNameString:=tempNameString "`n" lang("Title begins with") ": " ElementParameters.Wintitle
		else if (ElementParameters.TitleMatchMode=2)
			tempNameString:=tempNameString "`n" lang("Title includes") ": " ElementParameters.Wintitle
		else if (ElementParameters.TitleMatchMode=3)
			tempNameString:=tempNameString "`n" lang("Title is exatly") ": " ElementParameters.Wintitle
	}
	if (ElementParameters.excludeTitle)
		tempNameString:=tempNameString "`n" lang("Exclude_title") ": " ElementParameters.excludeTitle
	if (ElementParameters.winText)
		tempNameString:=tempNameString "`n" lang("Control_text") ": " ElementParameters.winText
	if (ElementParameters.ExcludeText)
		tempNameString:=tempNameString "`n" lang("Exclude_control_text") ": " ElementParameters.ExcludeText
	if (ElementParameters.ahk_class)
		tempNameString:=tempNameString "`n" lang("Window_Class") ": " ElementParameters.ahk_class
	if (ElementParameters.ahk_exe)
		tempNameString:=tempNameString "`n" lang("Process") ": " ElementParameters.ahk_exe
	if (ElementParameters.ahk_id)
		tempNameString:=tempNameString "`n" lang("Window_ID") ": " ElementParameters.ahk_id
	if (ElementParameters.ahk_pid)
		tempNameString:=tempNameString "`n" lang("Process_ID") ": " ElementParameters.ahk_pid
	
	return lang("&Name&") ": " tempNameString
#else
	return lang("&Name&") 
#endif
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_&ElementType&_&Name&(Environment, ElementParameters)
{	
	
}


#if ElementType = action | condition | loop
;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_&ElementType&_&Name&(Environment, ElementParameters)
{
#if par_checkbox 

	checkboxValue := ElementParameters.checkbox
#endif
#if par_radio 

	radioValue := ElementParameters.radio
#endif
#if par_radioEnum

	radioEnumValue := ElementParameters.radioEnum
#endif
#if par_editstring 

	editstringValue := x_replaceVariables(Environment,ElementParameters.editstring)
#endif
#if par_editExpression 

	evRes := x_evaluateExpression(Environment,ElementParameters.editExpression)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.editExpression) "`n`n" evRes.error) 
		return
	}
	editExpressionValue:=evRes.result
#endif
#if par_editStringOrExpression 

	if (ElementParameters.Expression = 2)
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
			editStringOrExpressionValue:=evRes.result
		}
	}
	else
		editStringOrExpressionValue := x_replaceVariables(Environment, ElementParameters.editStringOrExpression)
#endif
#if par_editVariableName

	editVariableNameValue := x_replaceVariables(Environment, ElementParameters.editVariableName)
	if not x_CheckVariableName(editVariableNameValue)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("%1% is not valid", lang("Ouput variable name '%1%'", par_editVariableName)))
		return
	}
#endif
#if par_editMultiLine

	editMultiLineValue := x_replaceVariables(Environment, ElementParameters.editMultiLine)
#endif
#if par_editTwoExpressions

	evRes := x_evaluateExpression(Environment,ElementParameters.editTwoExpressions1)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.editTwoExpressions1) "`n`n" evRes.error) 
		return
	}
	editTwoExpressions1Value:=evRes.result
	evRes := x_evaluateExpression(Environment,ElementParameters.editTwoExpressions2)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.editTwoExpressions2) "`n`n" evRes.error) 
		return
	}
	editTwoExpressions2Value:=evRes.result
#endif
#if par_DropDownString 

	DropDownStringValue := ElementParameters.DropDownString
#endif
#if par_ComboBoxString

	ComboBoxStringValue := x_replaceVariables(Environment, ElementParameters.ComboBoxString) 
#endif
#if par_ListBoxString 

	ListBoxStringValue:=ElementParameters.ListBoxString
	for oneListBoxStringIndex, oneListBoxString in ListBoxStringValue
	{
		;Do anything with oneListBoxString
	}
#endif
#if par_Slider

	evRes := x_evaluateExpression(Environment,ElementParameters.Slider)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.Slider) "`n`n" evRes.error) 
		return
	}
	SliderValue:=evRes.result

#endif
#if par_file 

	fileValue := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.file))
#endif
#if par_folder

	folderValue := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.folder))
#endif

#if addWindowSelector

	tempWinTitle:=x_replaceVariables(Environment, ElementParameters.Wintitle) 
	tempWinText:=x_replaceVariables(Environment, ElementParameters.winText)
	tempTitleMatchMode :=ElementParameters.TitleMatchMode
	tempahk_class:=x_replaceVariables(Environment, ElementParameters.ahk_class)
	tempahk_exe:=x_replaceVariables(Environment, ElementParameters.ahk_exe)
	tempahk_id:=x_replaceVariables(Environment, ElementParameters.ahk_id)
	tempahk_pid:=x_replaceVariables(Environment, ElementParameters.ahk_pid)
	
	tempwinstring:=tempWinTitle
	if tempahk_class
		tempwinstring:=tempwinstring " ahk_class " tempahk_class
	if tempahk_id
		tempwinstring:=tempwinstring " ahk_id " tempahk_id
	if tempahk_pid
		tempwinstring:=tempwinstring " ahk_pid " tempahk_pid
	if tempahk_exe
		tempwinstring:=tempwinstring " ahk_exe " tempahk_exe
	
	;If no window specified, error
	if (tempwinstring="" and tempWinText="")
	{
		x_enabled(Environment, "exception", lang("No window specified"))
		return
	}
	
	if ElementParameters.findhiddenwindow=0
		tempFindHiddenWindows = off
	else
		tempFindHiddenWindows = on
	if ElementParameters.findhiddentext=0
		tempfindhiddentext = off
	else
		tempfindhiddentext = on

#if !ElementType = Loop
	tempWinid:=winexist(tempwinstring,tempWinText,tempExcludeTitle,tempExcludeText) ;Example code. Remove it
	if tempWinid
	{
		x_SetVariable(Environment,"A_WindowID",tempWinid,"Thread") ;Example code. Remove it
		;Do some actions here
#if ElementType = action
		x_finish(Environment, "normal")
#endif
#if ElementType = condition
		x_finish(Environment, "yes")
#endif
		return
	}
	else
	{
#if ElementType = action
		x_finish(Environment, "exception", lang("Error! Seeked window does not exist")) 
#endif
#if ElementType = condition
		x_finish(Environment, "no")
#endif
		return
	}
#endif
#endif

	x_SetVariable(Environment,Varname,VarValue) ;Example
#if ElementType = action
#if !addWindowSelector
#if !addSeparateAhkThread
	MsgBox Hello World
	x_finish(Environment,"normal")
	return
#endif
#endif
#endif
	
#if ElementType = condition
#if !addWindowSelector
#if !addSeparateAhkThread
	MsgBox, 4, Choose, Yes or no
	IfMsgBox yes
		x_finish(Environment,"yes")
	else
		x_finish(Environment,"no")
		
	return
	
#endif
#endif
#endif

#if addSeparateAhkThread
	;Unfortunately we can't use the function lang() inside the exported code. But we can export them inside variables befor use.
	inputVars:={header: lang("Hello"), message: lang("Input some text")}
	outputVars:=["enteredText"]
	outputVars.push("resultmessage","result") ;We use those variables to find out whether an error was found during execution 
	code =
	( ` , LTrim %
		InputBox,enteredText, %header%, %message%
		if errorlevel
		{
			result := "exception"
			resultmessage := "User dismissed the dialog."
		}
		else
		{
			result := "normal"
		}
	)
	;We want later to translate the text inside message. Add the text here inside comments, so the translation tool can find it.
	;Translations: lang("User dismissed the dialog.")
	 
	functionObject := x_NewExecutionFunctionObject(Environment, "&ElementType&_&Name&_FinishExecution", ElementParameters)
	x_SetExecutionValue(Environment, "functionObject", functionObject)
	x_SetExecutionValue(Environment, "Varname", Varname)
	x_ExecuteInNewAHKThread(Environment, functionObject, code, inputVars, outputVars)
#endif
	
#if ElementType = Loop
	entryPoint := x_getEntryPoint(environment)
	
	if (entryPoint = "Head") ;Initialize loop
	{
		x_SetVariable(Environment, "A_Index", 1, "loop")
		x_finish(Environment, "head")
	}
	else if (entryPoint = "Tail") ;Continue loop
	{
		index := x_GetVariable(Environment, "A_Index")
		index++
		
		x_SetVariable(Environment, "A_Index", index, "loop")
		if (true) ;add here a decision
		{
			x_finish(Environment, "head") ;Continue with next iteration
		}
		else
		{
			x_finish(Environment, "tail") ;Leave the loop
		}
		
	}
	else if (entryPoint = "Break") ;Break loop
	{
		x_finish(Environment, "tail") ;Leave the loop
		
	}
	else
	{
		;This should never happen, but I suggest to keep this code for catching bugs in AHF.
		x_finish(Environment, "exception", lang("No information whether the connection leads into head or tail"))
	}
	
#endif
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_&ElementType&_&Name&(Environment, ElementParameters)
{
	
}
#endif


#if addSeparateAhkThread
&ElementType&_&Name&_FinishExecution(Environment, values, ElementParameters)
{
	if (values.result="normal")
	{
		varname := x_GetExecutionValue(Environment, "Varname")
		selectedFile:=values.selectedFile ;Do something with the result
		x_finish(Environment,values.result, values.message)
	}
	else
	{
		if (values.resultmessage)
		{
			x_finish(Environment,"exception", lang(values.resultmessage))
		}
		else
		{
			x_finish(Environment,"exception", lang("Unknown error"))
		}
	}
	
}
#endif


#if ElementType = trigger
;Called when the trigger is activated
Element_enable_&ElementType&_&Name&(Environment, ElementParameters)
{
	
#if par_checkbox 

	checkboxValue := ElementParameters.checkbox
#endif
#if par_radio 

	radioValue := ElementParameters.radio
#endif
#if par_radioEnum

	radioEnumValue := ElementParameters.radioEnum
#endif
#if par_editstring 

	editstringValue := x_replaceVariables(Environment,ElementParameters.editstring)
#endif
#if par_editExpression 

	evRes := x_evaluateExpression(Environment,ElementParameters.editExpression)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.editExpression) "`n`n" evRes.error) 
		return
	}
	editExpressionValue:=evRes.result
#endif
#if par_editStringOrExpression 

	editStringOrExpressionValueRaw := x_evaluateExpression(Environment,ElementParameters.editStringOrExpression)
	if (ElementParameters.Expression = 2)
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
			editStringOrExpressionValue:=evRes.result
		}
	}
	else
		editStringOrExpressionValue := x_replaceVariables(Environment, ElementParameters.editStringOrExpression)
#endif
#if par_editVariableName
	editVariableNameValue := x_replaceVariables(Environment, ElementParameters.editVariableName)
	
	if not x_CheckVariableName(editVariableNameValue)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("%1% is not valid", lang("Ouput variable name '%1%'", varname)))
		return
	}
#endif
#if par_editMultiLine
	editMultiLineValue := x_replaceVariables(Environment, ElementParameters.editMultiLine)
#endif
#if par_editTwoExpressions

	evRes := x_evaluateExpression(Environment,ElementParameters.editTwoExpressions1)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.editTwoExpressions1) "`n`n" evRes.error) 
		return
	}
	editTwoExpressions1Value:=evRes.result
	evRes := x_evaluateExpression(Environment,ElementParameters.editTwoExpressions2)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.editTwoExpressions2) "`n`n" evRes.error) 
		return
	}
	editTwoExpressions2Value:=evRes.result
#endif
#if par_DropDownString 
	DropDownStringValue := ElementParameters.DropDownString
#endif
#if par_ComboBoxString
	ComboBoxStringValue := x_replaceVariables(Environment, ElementParameters.ComboBoxString) 
#endif
#if par_ListBoxString 
	ListBoxStringValue:=ElementParameters.ListBoxString
	for oneListBoxStringIndex, oneListBoxString in ListBoxStringValue
	{
		;Do anything with oneListBoxString
	}
#endif
#if par_file 
	fileValue := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.file))
#endif
#if par_folder
	folderValue := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.folder))
#endif

#if addWindowSelector
	tempWinTitle:=x_replaceVariables(Environment, ElementParameters.Wintitle) 
	tempWinText:=x_replaceVariables(Environment, ElementParameters.winText)
	tempTitleMatchMode :=ElementParameters.TitleMatchMode
	tempahk_class:=x_replaceVariables(Environment, ElementParameters.ahk_class)
	tempahk_exe:=x_replaceVariables(Environment, ElementParameters.ahk_exe)
	tempahk_id:=x_replaceVariables(Environment, ElementParameters.ahk_id)
	tempahk_pid:=x_replaceVariables(Environment, ElementParameters.ahk_pid)
	
	tempwinstring:=tempWinTitle
	if tempahk_class
		tempwinstring:=tempwinstring " ahk_class " tempahk_class
	if tempahk_id
		tempwinstring:=tempwinstring " ahk_id " tempahk_id
	if tempahk_pid
		tempwinstring:=tempwinstring " ahk_pid " tempahk_pid
	if tempahk_exe
		tempwinstring:=tempwinstring " ahk_exe " tempahk_exe
	
	;If no window specified, error
	if (tempwinstring="" and tempWinText="")
	{
		x_enabled(Environment, "exception", lang("No window specified"))
		return
	}
	
	if ElementParameters.findhiddenwindow=0
		tempFindHiddenWindows = off
	else
		tempFindHiddenWindows = on
	if ElementParameters.findhiddentext=0
		tempfindhiddentext = off
	else
		tempfindhiddentext = on
	
	tempWinid:=winexist(tempwinstring,tempWinText,tempExcludeTitle,tempExcludeText)
	if not tempWinid
	{
		x_enabled(Environment, "exception", lang("Error! Seeked window does not exist")) 
		return
	}

	x_SetExecutionValue(Environment, "windowID", tempWinid)
#endif
	
	x_enabled(Environment, "normal", lang("I'm ready.",temphotkey))

}

;Called after the trigger has triggered.
;Here you can for example define the variables which are provided by the triggers.
Element_postTrigger_&ElementType&_&Name&(Environment, ElementParameters)
{
#if addWindowSelector
	tempWinid:=x_getExecutionValue(Environment, "windowID")
	x_SetVariable(Environment,"A_WindowID",tempWinid,"Thread")
#endif
}

;Called when the trigger should be disabled.
Element_disable_&ElementType&_&Name&(Environment, ElementParameters)
{
	x_disabled(Environment, "normal", lang("I'm stopped."))
}

#endif

#if par_button
&ElementType&_&Name&_ButtonClick()
{
	MsgBox user clicked me
}
#endif

#if addWindowSelector
&ElementType&_&Name&_ButtonWindowAssistant()
{
	x_assistant_windowParameter({wintitle: "Wintitle", excludeTitle: "excludeTitle", winText: "winText", FindHiddenText: "FindHiddenText", ExcludeText: "ExcludeText", ahk_class: "ahk_class", ahk_exe: "ahk_exe", ahk_id: "ahk_id", ahk_pid: "ahk_pid", FindHiddenWindow: "FindHiddenWindow"})
}
#endif