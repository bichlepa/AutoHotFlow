;Always add this element class name to the global list
x_RegisterElementClass("Action_Execute_Flow")

;Element type of the element
Element_getElementType_Action_Execute_Flow()
{
	return "action"
}

;Name of the element
Element_getName_Action_Execute_Flow()
{
	return x_lang("Execute_Flow")
}

;Category of the element
Element_getCategory_Action_Execute_Flow()
{
	return x_lang("Flow_control")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Execute_Flow()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Execute_Flow()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Execute_Flow()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Execute_Flow()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Execute_Flow(Environment)
{
	parametersToEdit := Object()
	parametersToEdit.push({type: "Label", label: x_lang("Which flow")})
	parametersToEdit.push({type: "Checkbox", id: "ThisFlow", default: 1, label: x_lang("This flow (%1%)", x_GetMyFlowID(Environment))})
	parametersToEdit.push({type: "DropDown", id: "flowID", result: "enum", choices: [], enum: []})

	parametersToEdit.push({type: "Label", label: x_lang("Which trigger")})
	parametersToEdit.push({type: "Radio", id: "WhichTrigger", default: 1, result: "enum", choices: [x_lang("Default trigger"), x_lang("Specified trigger")], enum: ["Default", "specified"]})
	parametersToEdit.push({type: "DropDown", id: "triggerID", result: "enum", choices: [], enum: []})

	parametersToEdit.push({type: "Label", label:  x_lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "SendLocalVars", default: 1, label: x_lang("Send local variables")})
	parametersToEdit.push({type: "Checkbox", id: "SkipDisabled", default: 0, label: x_lang("Skip disabled flows without error")})
	parametersToEdit.push({type: "Checkbox", id: "WaitToFinish", default: 0, label: x_lang("Wait for called flow to finish")})
	parametersToEdit.push({type: "Checkbox", id: "ReturnVariables", default: 0, label: x_lang("Return local variables to the calling flow")})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Execute_Flow(Environment, ElementParameters)
{
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
	
	if (ElementParameters.WhichTrigger = "Default")
		TriggerName := x_lang("Default trigger")
	else
		TriggerName := x_getElementName(FlowID, ElementParameters.TriggerID) 

	return % x_lang("Execute_Flow") ": " FlowName " - " TriggerName
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Execute_Flow(Environment, ElementParameters, staticValues)
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
			choicesTriggerIDs := x_getAllElementIDsOfClass(FlowID, "trigger_manual")
			
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
	
	if (ElementParameters.WaitToFinish = False)
	{
		x_Par_Disable("ReturnVariables")
		x_Par_SetValue("ReturnVariables", False)
	}
	else
	{
		x_Par_Enable("ReturnVariables")
	}	
	
	if (ElementParameters.defaultTrigger = True)
	{
		x_Par_Disable("triggerName")
		x_Par_SetValue("triggerName", "")
	}
	else
	{
		x_Par_Enable("triggerName")
	}	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Execute_Flow(Environment, ElementParameters)
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
	
	if (ElementParameters.WhichTrigger = "Default")
	{
		; default trigger is selected. We have to find the ID of the default trigger
		
		; we can call this function. If we keep the name empty, it will seek for the default trigger
		TriggerID := x_getDefaultManualTriggerID(FlowID)
		if (TriggerID)
		{
			; there is a manual trigger. We can continue
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
			; specified trigger exists. We cann continue
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
	
	; check whether trigger is enabled
	if not x_isTriggerEnabled(FlowID, TriggerID)
	{
		; trigger is disabled. Finish.
		if (ElementParameters.SkipDisabled)
		{
			; do not raise exception since the configuration sais so.
			return x_finish(Environment, "normal", x_lang("Trigger '%1%' in '%2%' is disabled", TriggerNameText, FlowNameText))
		}
		else
		{
			return x_finish(Environment, "exception", x_lang("Trigger '%1%' in '%2%' is disabled", TriggerNameText, FlowNameText))
		}
	}
	
	if (ElementParameters.SendLocalVars = True)
	{
		; local variables schould be sent to the other flow. Get all local variables.
		Variables := x_ExportAllInstanceVars(Environment)
	}
	if (ElementParameters.WaitToFinish)
	{
		; we want to wait until the execution finishes.

		; prepare a funciton object. It will be the called as soon as the other flow finishes
		functionObject := x_NewFunctionObject(environment, "Action_Execute_Flow_FunctionExecutionFinished", ElementParameters)

		; trigger the other flow and pass the function object as callback
		x_ManualTriggerExecute(FlowID, TriggerID, Variables, functionObject)

		; do not call x_finish(). It will be called when the functionObject is called.
		return
	}
	else
	{
		; we don't want to wait until the execution finishes

		; trigger the other flow and finish
		x_ManualTriggerExecute(FlowID, TriggerID, Variables)
		return x_finish(Environment, "normal")
	}
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Execute_Flow(Environment, ElementParameters)
{
	; nothing to do.
	; if WaitToFinish is set, the funciton Action_Execute_Flow_FunctionExecutionFinished() will be called when the remot flow finishes.
	; it's not a problem, if x_finish() will be called.
}

; if parameter WaitToFinish is set, this funciton will be called when the remote flow finishes
Action_Execute_Flow_FunctionExecutionFinished(Environment, ElementParameters, p_result, p_variables)
{
	if (ElementParameters.ReturnVariables)
	{
		; we want to import the instance variables from the other flow.
		x_ImportInstanceVars(Environment, p_variables)
	}
	; call x_finish()
	return x_finish(Environment, "normal")
}