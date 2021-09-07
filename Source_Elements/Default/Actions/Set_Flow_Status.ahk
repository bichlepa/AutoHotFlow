;Always add this element class name to the global list
x_RegisterElementClass("Action_Set_Flow_Status")

;Element type of the element
Element_getElementType_Action_Set_Flow_Status()
{
	return "action"
}

;Name of the element
Element_getName_Action_Set_Flow_Status()
{
	return x_lang("Set_Flow_Status")
}

;Category of the element
Element_getCategory_Action_Set_Flow_Status()
{
	return x_lang("Flow_control")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Set_Flow_Status()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Set_Flow_Status()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Set_Flow_Status()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Set_Flow_Status()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Set_Flow_Status(Environment)
{
	parametersToEdit := Object()
	parametersToEdit.push({type: "Label", label: x_lang("New state")})
	parametersToEdit.push({type: "Radio", id: "Enable", default: 1, result: "enum", choices: [x_lang("Enable"), x_lang("Disable")], enum: ["Enable", "Disable"]})

	parametersToEdit.push({type: "Label", label: x_lang("Which flow")})
	parametersToEdit.push({type: "Checkbox", id: "ThisFlow", default: 1, label: x_lang("This flow (%1%)", x_GetMyFlowID(Environment))})
	parametersToEdit.push({type: "DropDown", id: "flowID", result: "enum", choices: [], enum: []})

	parametersToEdit.push({type: "Label", label: x_lang("Which trigger")})
	parametersToEdit.push({type: "Radio", id: "WhichTrigger", default: 1, result: "enum", choices: [x_lang("All triggers"), x_lang("Default trigger"), x_lang("Specified trigger")], enum: ["Any", "Default", "Specified"]})
	parametersToEdit.push({type: "DropDown", id: "triggerID", result: "enum", choices: [], enum: []})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Set_Flow_Status(Environment, ElementParameters)
{
	if (ElementParameters.Enable = "Enable")
		enableString := x_lang("Enable")
	else
		enableString := x_lang("Disable")

	if (ElementParameters.ThisFlow = True)
	{
		FlowName := x_lang("This flow")
		FlowID := x_GetMyFlowID(Environment)
	}
	else
	{
		FlowName := x_getFlowName(ElementParameters.flowID)
		FlowID := ElementParameters.flowID
	}
	
	if (ElementParameters.WhichTrigger = "Any")
		TriggerName := x_lang("All triggers")
	else if (ElementParameters.WhichTrigger = "Default")
		TriggerName := x_lang("Default trigger")
	else
		TriggerName := x_getElementName(FlowID, ElementParameters.TriggerID) 

	
	return % x_lang("Set_Flow_Status") " - " enableString ": " FlowName " - " TriggerName
	
	
}


;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Set_Flow_Status(Environment, ElementParameters, staticValues)
{
	thisFlow := ElementParameters.ThisFlow
	flowID := ElementParameters.flowID
	WhichTrigger := ElementParameters.WhichTrigger

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

	if (WhichTrigger != staticValues.oldParWhichTrigger)
	{
		if (WhichTrigger != "Specified")
		{
			x_Par_Disable("triggerID")
			x_Par_SetValue("triggerID", "")
		}
		Else
		{
			x_Par_Enable("triggerID")
		}
	}

	if (WhichTrigger = "Specified")
	{
		if (staticValues.oldParFlowID != flowID or staticValues.oldParThisFlow != ThisFlow or WhichTrigger != staticValues.oldParWhichTrigger)
		{
			; user changed flow name or checkbox "thisFlow" and "Specified" trigger is chosen. We need to update the trigger list.
			if (x_Par_GetValue("ThisFlow"))
			{
				; ThisFlow is checked. get own flow ID
				FlowID := x_getMyFlowID(Environment)
			}
			else
			{
				; ThisFlow is not checked. flowID does not need to be changed
			}

			; get all triggers
			choicesTriggerIDs := x_getAllElementIDsOfType(FlowID, "trigger")
			
			; generate a list with all triggers
			choicesTriggerNames := []
			for oneIDIndex, oneTriggerID in choicesTriggerIDs
			{
				elementName := x_getElementName(FlowID, oneTriggerID)
				choicesTriggerNames.push(oneTriggerID ": " elementName)

				; we chosse either the first trigger or if the list contains the parametrized trigger ID, we will select it.
				; this is also importand on first call of this function
				if (ElementParameters.triggerID = oneTriggerID or not toChooseTriggerID)
				{
					toChooseTriggerID := oneTriggerID
				}
			}

			; show the trigger list
			x_Par_SetChoices("triggerID", choicesTriggerNames, choicesTriggerIDs)

			; check the trigger
			x_Par_SetValue("triggerID", toChooseTriggerID)
		}
	}

	staticValues.oldParThisFlow := ThisFlow
	staticValues.oldParFlowID := flowID
	staticValues.oldParWhichTrigger := WhichTrigger
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Set_Flow_Status(Environment, ElementParameters)
{
	; get flow ID
	if (ElementParameters.ThisFlow)
	{
		; we take the ID of the current flow
		FlowID := x_GetMyFlowID(Environment)
	}
	else
	{
		; we take the specified flow ID and check whether it exists
		FlowID := ElementParameters.flowID
		
		if not x_FlowExists(FlowID)
		{
			return x_finish(Environment, "exception", x_lang("Flow '%1%' does not exist", FlowID))
		}
	}
	
	if (ElementParameters.WhichTrigger = "Any")
	{
		; any trigger is selected. We can enable the flow
		if (ElementParameters.Enable = "Enable")
			x_flowEnable(FlowID)
		Else
			x_flowDisable(FlowID)
		
		return x_finish(Environment, "normal")
	}
	else if (ElementParameters.WhichTrigger = "Default")
	{
		; default trigger is selected. We have to find the ID of the default trigger
		
		; we can call this function. If we keep the name empty, it will seek for the default trigger
		TriggerID := x_getDefaultManualTriggerID(FlowID)
		if (TriggerID)
		{
			; there is a manual trigger. We can enable it
			if (ElementParameters.Enable = "Enable")
				x_triggerEnable(FlowID, TriggerID)
			Else
				x_triggerDisable(FlowID, TriggerID)

			return x_finish(Environment, "normal")
		}
		Else
		{
			; there is no manual trigger. finish with error.
			return x_finish(Environment, "exception", x_lang("Flow '%1%' does not have any manual trigger.", FlowID))
		}
	}
	else if (ElementParameters.WhichTrigger = "Specified")
	{
		; a Specified trigger is selected
		TriggerID := ElementParameters.TriggerID

		; check whether trigger ID is set
		if (TriggerID = "")
		{
			return x_finish(Environment, "exception", x_lang("Trigger ID is empty"))
		}
		
		; check whether specified trigger exists
		if (x_elementExists(FlowID, TriggerID))
		{
			; specified trigger exists. Enable it
			if (ElementParameters.Enable = "Enable")
				x_triggerEnable(FlowID, TriggerID)
			Else
				x_triggerDisable(FlowID, TriggerID)
			
			return x_finish(Environment, "normal")
		}
		else
		{
			; specified trigger does not exist. finish with error.
			return x_finish(Environment, "exception", x_lang("Flow '%1%' does not have the trigger with ID '%2%'.", FlowID, TriggerID))
		}
	}
	Else
	{
		return x_finish(Environment, "exception", x_lang("Unexpected Error!") " " x_lang("Parameter '%1%' is invalid.", "WhichTrigger"))
	}
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Set_Flow_Status(Environment, ElementParameters)
{
	
}
