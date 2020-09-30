global EnabledTriggerIDCounter:=0

enableFlow(p_FlowID)
{
	_EnterCriticalSection()

	enableTriggers(p_FlowID)
	SaveFlowMetaData(p_FlowID)

	_LeaveCriticalSection()
}
enableToggleFlow(p_FlowID)
{
	_EnterCriticalSection()
	
	if (_getFlowProperty(p_FlowID, "enabled") != true)
	{
		enableFlow(p_FlowID)
	}
	else
	{
		disableFlow(p_FlowID)
	}
	_LeaveCriticalSection()
}

disableFlow(p_FlowID)
{
	disableTriggers(p_FlowID)
	SaveFlowMetaData(p_FlowID)
}

enableTriggers(p_FlowID)
{
	_EnterCriticalSection()
	
	logger("a2", "Going to enable Flow " p_Flow.name)
	
	_setFlowProperty(p_FlowID, "enabled", "Enabling")
	allElements := _getAllElementIds(p_FlowID)
	for forElementIndex, forElementID in allElements
	{
		if (_getElementProperty(p_FlowID, forElementID, "type") = "trigger")
		{
			justEnableOneTrigger(p_FlowID, forElementID)
		}
	}
	_setFlowProperty(p_FlowID, "enabled", true)
	_LeaveCriticalSection()
	
	logger("a1", "Flow " _getFlowProperty(p_FlowID, "name") " enabled")
}

enableOneTrigger(p_FlowID, p_ElementID, p_save=true)
{
	_EnterCriticalSection()

	FlowName := _getFlowProperty(p_FlowID, "name")
	logger("a2", "Going to enable trigger " p_ElementID " in flow " FlowName)
	
	_setFlowProperty(p_FlowID, "enabled", "Enabling")
	
	justEnableOneTrigger(p_FlowID, p_ElementID)
	
	_setFlowProperty(p_FlowID, "enabled", true)
	if (p_save)
		SaveFlowMetaData(p_FlowID)
	
	logger("a1", "Trigger " p_ElementID " in flow " FlowName " enabled")
	
	_LeaveCriticalSection()
}

justEnableOneTrigger(p_FlowID, p_ElementID)
{
	_EnterCriticalSection()
	
	triggerEnvironment:=criticalObject()
	triggerEnvironment.id:= "enabledTrigger" ++EnabledTriggerIDCounter
	triggerEnvironment.flowID:=p_FlowID
	triggerEnvironment.ElementID:=p_ElementID
	triggerEnvironment.Pars := _getElementProperty(p_FlowID, p_ElementID, "Pars")
	
	_setTrigger(triggerEnvironment.id, triggerEnvironment)
	
	tempElementClass:=_getElementProperty(p_FlowID, p_ElementID, "class")
	if isfunc("Element_enable_" tempElementClass)
	{
		Element_enable_%tempElementClass%(triggerEnvironment, triggerEnvironment.Pars)
	}
	else
	{
		logger("a0", "Trigger " p_ElementID " cannot be enabled (missing implementation)")
	}

	_LeaveCriticalSection()
}

disableTriggers(p_FlowID)
{
	_EnterCriticalSection()

	FlowName := _getFlowProperty(p_FlowID, "name")
	logger("a2", "Going to disable Flow " FlowName)
	
	_setFlowProperty(p_FlowID, "enabled", "Disabling")
	tempToDisableTriggers:=Object()
	
	triggers := _getAllTriggerIds()
	for forEnabledTriggerIndex, forEnabledTriggerID in triggers
	{
		forFlowID:=_getTriggerProperty(forEnabledTriggerID, "flowID")
		if (forFlowID = p_FlowID)
		{
			forElementID:=_getTriggerProperty(forEnabledTriggerID, "flowID")
			justDisableOneTrigger(p_FlowID, forElementID, forEnabledTriggerID)
		}
	}

	logger("a1", "Flow " FlowName " disabled")
	_setFlowProperty(p_FlowID, "enabled", false)

	_LeaveCriticalSection()
}
disableOneTrigger(p_FlowID, p_ElementID, p_save = true)
{
	_EnterCriticalSection()
	FlowName := _getFlowProperty(p_FlowID, "name")

	logger("a2", "Going to disable trigger " p_ElementID " in Flow " FlowName)
	
	otherTriggersInThisFlowEnabled := False
	triggers := _getAllTriggerIds()
	for forEnabledTriggerIndex, forEnabledTriggerID in triggers
	{
		forFlowID:=_getTriggerProperty(forEnabledTriggerID, "flowID")
		if (forFlowID = p_FlowID)
		{
			forElementID:=_getTriggerProperty(forEnabledTriggerID, "flowID")
			if (forElementID = p_ElementID)
				justDisableOneTrigger(p_FlowID, p_ElementID, forEnabledTriggerID)
			else 
				otherTriggersInThisFlowEnabled:=true
		}
	}
	
	logger("a2", "Trigger " p_ElementID " in Flow " FlowName " disabled")
	if (otherTriggersInThisFlowEnabled = False)
	{
		_setFlowProperty(p_FlowID, "enabled", false)
	}
	if (p_save)
		SaveFlowMetaData(p_FlowID)
		
	_LeaveCriticalSection()
}

justDisableOneTrigger(p_Flow, p_ElementID, p_EnabledTriggerID)
{
	_EnterCriticalSection()

	tempElementClass := _getElementProperty(p_FlowID, p_ElementID, "class")
	triggerPars := _getTriggerProperty(TriggerID, "Pars")
	;~ d(forTrigger,"Element_disable_" tempElementClass)
	if isfunc("Element_disable_" tempElementClass)
	{
		Element_disable_%tempElementClass%(p_EnabledTriggerID, triggerPars)
		_setElementProperty(p_FlowID, p_ElementID, "enabled", false)
		_setFlowProperty(p_FlowID, "draw.mustdraw", false)
	}
	else
	{
		logger("a0", "Trigger " p_ElementID " cannot be disabled (missing implementation)")
	}
	_deleteTrigger(p_EnabledTriggerID)
	
	_LeaveCriticalSection()
}

saveResultOfTriggerEnabling(trigger, Result, Message)
{
	_EnterCriticalSection()

	trigger.result:=Result
	trigger.Message:=Message
	if (Result = "normal")
	{
		_setElementProperty(trigger.flowID, trigger.elementID, "enabled", True)
		if (Message = "")
			logger("a2", "Trigger " trigger.ElementID " enabled")
		else
			logger("a2", "Trigger " trigger.ElementID " enabled (" Message ")")
	}
	else if (result = "exception")
	{
		_setElementProperty(trigger.flowID, trigger.elementID, "enabled", False)
		ElementName := _getElementProperty(trigger.flowID, trigger.elementID, "name")
		if (Message = "")
		{
			logger("a0", "Trigger " trigger.ElementID " cannot be enabled")
			MsgBox, 16, % lang("Exception occured") , % lang("%1% '%2%' (ID '%3%') cannot be enabled due to an exception.", lang("Trigger"), ElementName, trigger.elementID)
		}
		else
		{
			logger("a0", "Trigger " trigger.ElementID " cannot be enabled (" Message ")")
			MsgBox, 16, % lang("Exception occured") , % lang("%1% '%2%' (ID '%3%') cannot be enabled due to an exception.", lang("Trigger"), ElementName, trigger.elementID) "`n`n" Message
		}
	}
	else
	{
		logger("a0", "Trigger " trigger.ElementID " cannot be enabled (unknown result: " Result ")")
		MsgBox, 16, % lang("Exception occured") , % lang("%1% '%2%' (ID '%3%') cannot be enabled." "`n" lang("Unknown result: %1%", Result), lang("Trigger"), ElementName, trigger.elementID) "`n`n" Message
	}
	_setFlowProperty(trigger.flowID, "draw.mustdraw", true)

	_LeaveCriticalSection()
}

saveResultOfTriggerDisabling(trigger, Result, Message)
{
	_EnterCriticalSection()

	trigger.result:=Result
	trigger.Message:=Message
	if (Result = "normal")
	{
		_setElementProperty(trigger.flowID, trigger.elementID, "enabled", False)
		if (Message = "")
			logger("a2", "Trigger " trigger.ElementID " disabled")
		else
			logger("a2", "Trigger " trigger.ElementID " disabled (" Message ")")
	}
	else if (result = "error")
	{
		ElementName := _getElementProperty(trigger.flowID, trigger.elementID, "name")
		if (Message = "")
		{
			logger("a0", "Trigger " trigger.ElementID " cannot be disabled")
			MsgBox, 16, % lang("Exception occured") , % lang("%1% '%2%' (ID '%3%') cannot be disabled due to an exception.", lang("Trigger"), ElementName, trigger.elementID)
		}
		else
			logger("a0", "Trigger " trigger.ElementID " cannot be disabled (" Message ")")
			MsgBox, 16, % lang("Exception occured") , % lang("%1% '%2%' (ID '%3%') cannot be disabled due to an exception.", lang("Trigger"), ElementName, trigger.elementID) "`n`n" Message
	}
	else
	{
		logger("a0", "Trigger " trigger.ElementID " cannot be disabled (unknown result: " Result ")")
	}
	_setFlowProperty(trigger.flowID, "draw.mustdraw", true)

	_LeaveCriticalSection()
}
