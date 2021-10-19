;Always add this element class name to the global list
x_RegisterElementClass("Action_Set_element_parameter")

;Element type of the element
Element_getElementType_Action_Set_element_parameter()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Set_element_parameter()
{
	return lang("Set element parameter")
}

;Category of the element
Element_getCategory_Action_Set_element_parameter()
{
	return lang("Flow_control")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Set_element_parameter()
{
	return "Default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Set_element_parameter()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Advanced"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Set_element_parameter()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Set_element_parameter()
{
	;"Stable" or "Experimental"
	return "Experimental"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Set_element_parameter(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Which flow")})
	parametersToEdit.push({type: "Checkbox", id: "ThisFlow", default: 1, label: x_lang("This flow (%1%)", x_GetMyFlowID(Environment))})
	parametersToEdit.push({type: "DropDown", id: "flowID", result: "enum", choices: [], enum: []})

	parametersToEdit.push({type: "Label", label: x_lang("Which element")})
	parametersToEdit.push({type: "DropDown", id: "elementID", result: "enum", choices: [], enum: []})

	parametersToEdit.push({type: "Label", label: x_lang("Which parameter")})
	parametersToEdit.push({type: "DropDown", id: "parameterID", result: "enum", choices: [], enum: []})

	parametersToEdit.push({type: "Label", label: lang("New value")})
	parametersToEdit.push({type: "Edit", id: "newParameterValueEdit", default: "", content: ["rawString", "string"], contentID: "newParameterValueEditContent", contentDefault: "rawString"})
	parametersToEdit.push({type: "Checkbox", id: "newParameterValueCheckbox", default: 0, label: lang("Label")})
	parametersToEdit.push({type: "Checkbox", id: "newParameterValueCheckboxGray", default: 0, gray: true, label: lang("Label")})
	parametersToEdit.push({type: "DropDown", id: "newParameterValueDropDown", default: "", choices: [""], result: "enum", enum: [""]})
	parametersToEdit.push({type: "DropDown", id: "newParameterValueComboBox", default: "", choices: [""], result: "enum", enum: [""]})
	parametersToEdit.push({type: "multilineEdit", id: "newParameterValueMultilineEdit", default: "",  content: ["rawString", "string"], contentID: "newParameterValueMultilineEditContent", contentDefault: "rawString"})
	parametersToEdit.push({type: "DropDown", id: "newParameterValueListBox", default: "", choices: [""], result: "enum", enum: [""]})
	parametersToEdit.push({type: "File", id: "newParameterValueFile", label: lang("Select a file")})
	parametersToEdit.push({type: "Folder", id: "newParameterValueFolder", label: lang("Select a folder")})
	parametersToEdit.push({type: "Weekdays", id: "newParameterValueWeekdays"})
	parametersToEdit.push({type: "dateAndTime", id: "newParameterValueDateAndTime", format: "datetime"})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Set_element_parameter(Environment, ElementParameters)
{
	if (ElementParameters.ThisFlow)
	{
		flowText := x_lang("This flow")
	}
	Else
	{
		flowText :=  x_lang("Flow '%1%'", ElementParameters.flowID)
	}
	elementText := x_lang("Element '%1%'", ElementParameters.elementID)
	
	parameterIDSplit := StrSplit(ElementParameters.ParameterID, "/", , 2)
	controlID := parameterIDSplit[1]
	parameterIDonly := parameterIDSplit[2]
	parameterText := x_lang("'%1%'", parameterIDonly)
	valueText := x_lang("'%1%'", ElementParameters[controlID])

	return lang("Set element parameter") " - " parameterText " = " valueText " - " elementText " - " flowText
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Set_element_parameter(Environment, ElementParameters, staticValues)
{	
	thisFlow := ElementParameters.ThisFlow
	flowID := ElementParameters.flowID
	elementID := ElementParameters.elementID
	ParameterID := ElementParameters.ParameterID
	allPars := staticValues.allPars

	if (ThisFlow)
	{
		flowID :=  x_GetMyFlowID(Environment)
	}

	; if flow is changed, we need to update the list of available elements
	if (ThisFlow != staticValues.oldParThisFlow)
	{
		if (ThisFlow)
		{
			x_Par_Disable("flowID")
			x_Par_SetValue("flowID", "")
		}
		else
		{
			x_Par_Enable("flowID")

			; get list of flows
			choicesFlowIDs := x_GetListOfFlowIDs()
			choicesFlowNames := []
			for oneFlowIndex, oneFlowID in choicesFlowIDs
			{
				choicesFlowNames.push(oneFlowID ": " x_getFlowName(oneFlowID))
			}
			
			; set choices
			x_Par_SetChoices("flowID", choicesFlowNames, choicesFlowIDs)

			; select flow
			if (not flowID or not x_FirstCallOfCheckSettings(Environment))
			{
				; there is no flow ID specified or user swichted option "ThisFlow" off.
				; Set current flow ID
				flowID := x_GetMyFlowID(Environment)
			}
			x_Par_SetValue("flowID", flowID)
		}
	}

	; if flow or element was changed, we need to update the available parameters
	if (staticValues.oldParFlowID != flowID or staticValues.oldParThisFlow != ThisFlow or elementID != staticValues.oldParelementID)
	{
		; get all Elements
		choicesElementIDs := x_getAllElementIDs(FlowID)
		
		; generate a list with all Elements
		choicesElementNames := []
		for oneIDIndex, oneElementID in choicesElementIDs
		{
			elementName := x_getElementName(FlowID, oneElementID)
			choicesElementNames.push(oneElementID ": " elementName)

			; we choose either the first Element or if the list contains the parametrized Element ID, we will select it.
			; this is also importand on first call of this function
			if (elementID = oneElementID or not toChooseElementID)
			{
				toChooseElementID := oneElementID
			}
		}
		elementID := toChooseElementID

		; show the Element list
		x_Par_SetChoices("ElementID", choicesElementNames, choicesElementIDs)

		; check the Element
		x_Par_SetValue("ElementID", elementID)


		; get list of all element parameters and add them to the dropdown
		ParsDetails := x_getElementParsDetails(FlowID, elementID)

		; find the parameter ID and the parameter type
		allPars := []
		for oneParameterDefinitionIndex, oneParameterDefinition in ParsDetails
		{
			if (oneParameterDefinition.type = "label")
			{
				lastLabel := oneParameterDefinition.label
			}
			ids := oneParameterDefinition.id
			if (ids and not IsObject(ids))
			{
				ids := [ids]
			}
			oneAllIdsString := ""
			for oneIDIndex, oneID in ids
			{
				switch (oneParameterDefinition.type)
				{
					case "edit":
					allPars.push({id: oneID, control: "newParameterValueEdit", name: lastLabel})

					case "multilineEdit":
					allPars.push({id: oneID, control: "newParameterValuemultilineEdit", name: lastLabel})

					case "Checkbox":
					if (oneParameterDefinition.gray)
					{
						allPars.push({id: oneID, control: "newParameterValueCheckboxGray", name: oneParameterDefinition.label})
					}
					Else
					{
						allPars.push({id: oneID, control: "newParameterValueCheckbox", name: oneParameterDefinition.label})
					}

					case "radio", "dropdown":
					switch (oneParameterDefinition.result)
					{
						case "enum":
						allPars.push({id: oneID, control: "newParameterValueDropDown", name: lastLabel, choices: oneParameterDefinition.choices, enum: oneParameterDefinition.enum})

						case "string":
						enumValues := []
						for oneIndex, oneChoice in oneParameterDefinition.choices
						{
							enumValues.push(oneChoice)
						}
						allPars.push({id: oneID, control: "newParameterValueDropDown", name: lastLabel, choices: oneParameterDefinition.choices, enum: oneParameterDefinition.enum})

						case "number", "":
						enumValues := []
						for oneIndex, oneChoice in oneParameterDefinition.choices
						{
							enumValues.push(oneIndex)
						}
						allPars.push({id: oneID, control: "newParameterValueDropDown", name: lastLabel, choices: oneParameterDefinition.choices, enum: enumValues})

						default:
						MsgBox, result type is supported
					}

					case "slider":
					allPars.push({id: oneID, control: "newParameterValueEdit", name: lastLabel})
					
					case "listbox":
					switch (oneParameterDefinition.result)
					{
						case "string":
						enumValues := []
						for oneIndex, oneChoice in oneParameterDefinition.choices
						{
							enumValues.push(oneChoice)
						}
						allPars.push({id: oneID, control: "newParameterValueListBox", name: lastLabel, choices: oneParameterDefinition.choices, result: "string"})

						case "number", "":
						enumValues := []
						for oneIndex, oneChoice in oneParameterDefinition.choices
						{
							enumValues.push(oneIndex)
						}
						allPars.push({id: oneID, control: "newParameterValueListBox", name: lastLabel, choices: oneParameterDefinition.choices, result: "number"})

						default:
						MsgBox, result type is supported
					}

					case "combobox":
					switch (oneParameterDefinition.result)
					{
						case "string", "":
						enumValues := []
						for oneIndex, oneChoice in oneParameterDefinition.choices
						{
							enumValues.push(oneChoice)
						}
						allPars.push({id: oneID, control: "newParameterValueComboBox", name: lastLabel, choices: oneParameterDefinition.choices, result: "string"})

						case "number":
						enumValues := []
						for oneIndex, oneChoice in oneParameterDefinition.choices
						{
							enumValues.push(oneIndex)
						}
						allPars.push({id: oneID, control: "newParameterValueComboBox", name: lastLabel, choices: oneParameterDefinition.choices, result: "number"})

						case default:
						x_log(Environment, x_lang("Result type '%1%' is not supported", oneParameterDefinition.result), 0)
					}
					
					case "hotkey":
					allPars.push({id: oneID, control: "newParameterValueFile", name: lastLabel})
					
					case "file":
					allPars.push({id: oneID, control: "newParameterValueFile", name: lastLabel})

					case "folder":
					allPars.push({id: oneID, control: "newParameterValueFolder", name: lastLabel})
					
					case "dateAndTime":
					allPars.push({id: oneID, control: "newParameterValuedateAndTime", name: lastLabel})

					case "weekdays":
					allPars.push({id: oneID, control: "newParameterValueweekdays", name: lastLabel})
					
					case default:
					x_log(Environment, x_lang("Parameter type '%1%' is not supported", oneParameterDefinition.type), 0)
				}

				if (oneAllIdsString != "")
					oneAllIdsString .= ", "
				oneAllIdsString .= oneID
			}
			
			ids := oneParameterDefinition.contentId
			if (ids and not IsObject(ids))
			{
				ids := [ids]
			}
			for oneIDIndex, oneID in ids
			{
				allPars.push({id: oneID, control: "DropDown", name: x_lang("Type of parameter '%1%'", oneAllIdsString)})
			}
		}

		; set choices for parameter ID
		choices := []
		enums := []
		for oneParIndex, onePar in allPars
		{
			choices.push(onePar.id " - " onePar.name)
			oneEnum := onePar.control "/" onePar.id
			enums.push(oneEnum)
			
			; we choose either the first Element or if the list contains the parametrized Element ID, we will select it.
			; this is also importand on first call of this function
			if (ElementParameters.parameterID = oneEnum or not toChooseParameterID)
			{
				toChooseParameterID := oneEnum
			}
		}
		x_Par_SetChoices("parameterID", choices, enums)

		; select the parameterID
		x_Par_SetValue("parameterID", toChooseParameterID)
		ParameterID := toChooseParameterID
	}

	; if flow or element or parameter was changed, we need to find out which control has tu be activated and (if applicable) update the choices
	if (staticValues.oldParFlowID != flowID or staticValues.oldParThisFlow != ThisFlow or elementID != staticValues.oldParelementID or ParameterID != staticValues.oldParParameterID)
	{
		; enable the required control
		{
			; the value EvaluatedParameters.parameterID contains the control which contains the new value and the ID of the parameter in the target element
			parameterIDSplit := StrSplit(ParameterID, "/", , 2)
			controlID := parameterIDSplit[1]
			parameterIDonly := parameterIDSplit[2]

			allControls := []
			allControls.push("newParameterValueEdit")
			allControls.push("newParameterValueCheckbox")
			allControls.push("newParameterValueCheckboxGray")
			allControls.push("newParameterValueDropDown")
			allControls.push("newParameterValueComboBox")
			allControls.push("newParameterValueMultilineEdit")
			allControls.push("newParameterValueListBox")
			allControls.push("newParameterValueFile")
			allControls.push("newParameterValueFolder")
			allControls.push("newParameterValueWeekdays")
			allControls.push("newParameterValueDateAndTime")

			for oneIndex, oneControl in allControls
			{
				x_Par_Enable(oneControl, oneControl = controlID)
			}

			; find the entry in allPars
			for oneIndex, onePars in allPars
			{
				if (onePars.id = parameterIDonly)
				{
					if (onePars.choices)
					{
						x_Par_SetChoices(controlID, onePars.choices, onePars.enum)
					}
				}
			}
			x_Par_SetValue(controlID, ElementParameters[controlID])
		}
	}
	staticValues.oldParThisFlow := ThisFlow
	staticValues.oldParFlowID := flowID
	staticValues.oldParelementID := elementID
	staticValues.oldParParameterID := ParameterID
	staticValues.allPars := allPars
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Set_element_parameter(Environment, ElementParameters)
{
	x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["ThisFlow", "FlowID", "ElementID", "ParameterID"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	if (EvaluatedParameters.ThisFlow)
	{
		; we take the ID of the current flow
		FlowID := x_GetMyFlowID(Environment)
	}
	else
	{
		; we take the specified flow ID and check whether it exists
		FlowID := EvaluatedParameters.flowID
		
		if not x_FlowExists(FlowID)
		{
			return x_finish(Environment, "exception", x_lang("Flow '%1%' does not exist", FlowID))
		}
	}

	ElementID := EvaluatedParameters.ElementID
	; check whether element ID is set
	if (ElementID = "")
	{
		return x_finish(Environment, "exception", x_lang("Element ID is empty"))
	}
	
	; check whether specified Element exists
	if not (x_elementExists(FlowID, ElementID))
	{
		; specified Element does not exist. finish with error.
		return x_finish(Environment, "exception", x_lang("Flow '%1%' does not have the element with ID '%2%'.", FlowID, ElementID))
	}

	; the value EvaluatedParameters.parameterID contains the control which contains the new value and the ID of the parameter in the target element
	parameterIDSplit := StrSplit(EvaluatedParameters.parameterID, "/", , 2)
	controlID := parameterIDSplit[1]
	parameterID := parameterIDSplit[2]


	x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, [controlID])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage)
		return
	}
	x_setElementPar(FlowID, ElementID, parameterID, EvaluatedParameters[controlID])

	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Set_element_parameter(Environment, ElementParameters)
{
}



