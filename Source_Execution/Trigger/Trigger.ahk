global EnabledTriggerIDCounter := 0

; enable a flow and thus enable all triggers
enableFlow(p_FlowID)
{
	; enable all triggers
	enableTriggers(p_FlowID)
}

; toggle the enable state of the flow
; enable if flow is disabled. Disable flow if flow is enabled.
enableToggleFlow(p_FlowID)
{
	if (_getFlowProperty(p_FlowID, "enabled") != true)
	{
		; flow is disabled. Enable it
		enableFlow(p_FlowID)
	}
	else
	{
		; flow is enabled. Disable it
		disableFlow(p_FlowID)
	}
}

; disable a flow
disableFlow(p_FlowID)
{
	; disable all triggers
	disableTriggers(p_FlowID)
}

; enable all triggers of a flow
enableTriggers(p_FlowID)
{
	_EnterCriticalSection()
	
	FlowName := _getFlowProperty(p_FlowID, "name")
	logger("a2", "Going to enable Flow " FlowName)
	
	; loop through all triggers
	allElements := _getAllElementIds(p_FlowID)
	_LeaveCriticalSection()
	for forElementIndex, forElementID in allElements
	{
		if (_getElementProperty(p_FlowID, forElementID, "type") = "trigger")
		{
			; enable the trigger
			justEnableOneTrigger(p_FlowID, forElementID)
		}
	}

	; save changed enabling state
	SaveFlowMetaData(p_FlowID)

	; set the flow property "enabled" to "true"
	_setFlowProperty(p_FlowID, "enabled", true)

	logger("a1", "Flow " FlowName " enabled")
}

; enable a single trigger
enableOneTrigger(p_FlowID, p_ElementID, p_save = true)
{
	FlowName := _getFlowProperty(p_FlowID, "name")
	logger("a2", "Going to enable trigger " p_ElementID " in flow " FlowName)
	
	; enable the trigger
	justEnableOneTrigger(p_FlowID, p_ElementID)
	
	; set the flow property "enabled" to "true"
	_setFlowProperty(p_FlowID, "enabled", true)
	
	; save changed enabling state if requested
	if (p_save)
		SaveFlowMetaData(p_FlowID)
	
	logger("a1", "Trigger " p_ElementID " in flow " FlowName " enabled")
}

; enable a single trigger (reusable code)
justEnableOneTrigger(p_FlowID, p_ElementID)
{
	_EnterCriticalSection()
	
	; add the current trigger to the list of all enabled triggers

	; create a trigger object with some informations
	newEnabledTrigger := criticalObject()
	newEnabledTrigger.id := "enabledTrigger" ++EnabledTriggerIDCounter
	newEnabledTrigger.flowID := p_FlowID
	newEnabledTrigger.ElementID := p_ElementID
	newEnabledTrigger.Pars := _getElementProperty(p_FlowID, p_ElementID, "Pars")
	newEnabledTrigger.variables := []
	newEnabledTrigger.triggerValues := []
	
	_setTrigger(newEnabledTrigger.id, newEnabledTrigger)
	
	; call the element function to enable the trigger
	tempElementClass := _getElementProperty(p_FlowID, p_ElementID, "class")
	environment := {flowID: newEnabledTrigger.FlowID, elementID: newEnabledTrigger.elementID, triggerID: newEnabledTrigger.id}
	
	_LeaveCriticalSection()
	result := Element_enable_%tempElementClass%(environment, newEnabledTrigger.Pars)

	if (not result)
	{
		; if the function did not return true, delete the trigger. We won't need to disable it.
		_deleteTrigger(newEnabledTrigger.id)
	}

}

; disable all triggers of a flow
disableTriggers(p_FlowID)
{
	FlowName := _getFlowProperty(p_FlowID, "name")
	logger("a2", "Going to disable Flow " FlowName)
	
	; loop through all active triggers
	triggers := _getAllTriggerIds()
	for forEnabledTriggerIndex, forEnabledTriggerID in triggers
	{
		; check whether the enabled trigger belongs to the current flow
		forFlowID := _getTriggerProperty(forEnabledTriggerID, "flowID")
		if (forFlowID = p_FlowID)
		{
			; disable the trigger
			forElementID := _getTriggerProperty(forEnabledTriggerID, "elementID")
			justDisableOneTrigger(p_FlowID, forElementID, forEnabledTriggerID)
		}
	}

	; save changed enabling state
	SaveFlowMetaData(p_FlowID)

	; set the flow property "enabled" to "false"
	; we set it to false after we saved the flow. When a flow is deleted, it checks the "enabled" flag. If we set it to false and save afterwards, the flow file will be recreated.
	_setFlowProperty(p_FlowID, "enabled", false)

	logger("a1", "Flow " FlowName " disabled")
}

; disable a single trigger
disableOneTrigger(p_FlowID, p_ElementID, p_save = true)
{
	FlowName := _getFlowProperty(p_FlowID, "name")
	logger("a2", "Going to disable trigger " p_ElementID " in Flow " FlowName)
	
	otherTriggersInThisFlowEnabled := False

	; loop through all active triggers
	triggers := _getAllTriggerIds()
	for forEnabledTriggerIndex, forEnabledTriggerID in triggers
	{
		; check whether the enabled trigger belongs to the current flow
		forFlowID := _getTriggerProperty(forEnabledTriggerID, "flowID")
		if (forFlowID = p_FlowID)
		{
			; check whether the enabled trigger belongs to the current element
			forElementID := _getTriggerProperty(forEnabledTriggerID, "elementID")
			if (forElementID = p_ElementID)
			{
				; disable the trigger
				justDisableOneTrigger(p_FlowID, p_ElementID, forEnabledTriggerID)
			}
			else
			{
				; track whether there is an other enabled trigger in this flow
				otherTriggersInThisFlowEnabled := true
			}
		}
	}
	
	logger("a2", "Trigger " p_ElementID " in Flow " FlowName " disabled")

	if (otherTriggersInThisFlowEnabled = False)
	{
		; if there is no other enabled trigger in this flow, set the flow property "enabled" to "false"
		_setFlowProperty(p_FlowID, "enabled", false)
	}
	
	; save changed enabling state if requested
	if (p_save)
		SaveFlowMetaData(p_FlowID)
}

; disable a single trigger (reusable code)
justDisableOneTrigger(p_FlowID, p_ElementID, p_EnabledTriggerID)
{
	_EnterCriticalSection()

	; get some informations
	tempElementClass := _getElementProperty(p_FlowID, p_ElementID, "class")
	triggerPars := _getTriggerProperty(p_EnabledTriggerID, "pars")

	; call the element function to disable the trigger
	environment := {flowID: p_FlowID, elementID: p_ElementID, triggerID: p_EnabledTriggerID}

	_LeaveCriticalSection()
	Element_disable_%tempElementClass%(environment, triggerPars)

	; update visual data
	_setElementInfo(p_FlowID, p_ElementID, "enabled", false)
	_setFlowProperty(p_FlowID, "draw.mustdraw", true)

	; delete the enabled trigger
	_deleteTrigger(p_EnabledTriggerID)
	
}

; update the enabling state of the trigger after the trigger was enabled
; it is called by the element api
saveResultOfTriggerEnabling(environment, Result, Message)
{
	_EnterCriticalSection()
	
	FlowName := _getFlowProperty(environment.FlowID, "name")

	; check the result
	if (Result = "normal")
	{
		; set the enabling sate of the element
		_setElementInfo(environment.flowID, environment.elementID, "enabled", True)
		
		; log the event
		if (Message = "")
			logger("a2", "Trigger " environment.ElementID " enabled", FlowName)
		else
			logger("a2", "Trigger " environment.ElementID " enabled (" Message ")", FlowName)
	}
	else if (result = "exception")
	{
		; set the enabling sate of the element
		_setElementInfo(environment.flowID, environment.elementID, "enabled", False)

		; log the event and show a message
		ElementName := _getElementProperty(environment.flowID, environment.elementID, "name")
		if (Message = "")
		{
			loggerMessage := lang("%1% '%2%' (ID '%3%') cannot be enabled due to an exception.", lang("Trigger"), ElementName, environment.elementID)
			logger("a0", loggerMessage, FlowName, true)
		}
		else
		{
			loggerMessage := lang("%1% '%2%' (ID '%3%') cannot be enabled due to an exception.", lang("Trigger"), ElementName, environment.elementID) " - " Message
			logger("a0", loggerMessage, FlowName, true)
		}
	}
	else
	{
		; log the event and show a message
		loggerMessage := lang("%1% '%2%' (ID '%3%') cannot be enabled." "`n" lang("Unknown result: %1%", Result), lang("Trigger"), ElementName, environment.elementID) "`n`n" Message
		logger("a0", loggerMessage, flowName, true)
	}

	; redraw flow
	_setFlowProperty(environment.flowID, "draw.mustdraw", true)

	_LeaveCriticalSection()
}

; update the enabling state of the trigger after a trigger was disabled
; it is called by the element api
saveResultOfTriggerDisabling(trigger, Result, Message)
{
	_EnterCriticalSection()

	FlowName := _getFlowProperty(environment.FlowID, "name")

	; check the result
	if (Result = "normal")
	{
		; set the enabling sate of the element
		_setElementInfo(environment.flowID, environment.elementID, "enabled", False)

		; log the event
		if (Message = "")
			logger("a2", "Trigger " environment.ElementID " disabled", FlowName)
		else
			logger("a2", "Trigger " environment.ElementID " disabled (" Message ")", FlowName)
	}
	else if (result = "exception")
	{
		; log the event and show a message
		ElementName := _getElementProperty(environment.flowID, environment.elementID, "name")
		if (Message = "")
		{
			loggerMessage := lang("%1% '%2%' (ID '%3%') cannot be disabled due to an exception.", lang("Trigger"), ElementName, environment.elementID)
			logger("a0", loggerMessage, FlowName, true)
		}
		else
		{
			loggerMessage := lang("%1% '%2%' (ID '%3%') cannot be disabled due to an exception.", lang("Trigger"), ElementName, environment.elementID) " - " Message
			logger("a0", loggerMessage, FlowName, true)
		}
	}
	else
	{
		; log the event and show a message
		loggerMessage := lang("%1% '%2%' (ID '%3%') cannot be disabled." "`n" lang("Unknown result: %1%", Result), lang("Trigger"), ElementName, environment.elementID) "`n`n" Message
		logger("a0", loggerMessage, flowName, true)
	}
	
	; redraw flow
	_setFlowProperty(environment.flowID, "draw.mustdraw", true)

	_LeaveCriticalSection()
}
