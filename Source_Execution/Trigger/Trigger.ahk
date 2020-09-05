EnabledTriggerIDCounter:=0

enableFlow(par_FlowID)
{
	global
	EnterCriticalSection(_cs_flows)
	EnterCriticalSection(_cs_execution)

	local oneTriggerID, oneTrigger
	if (_flows[par_FlowID].loaded != true)
	{
		LoadFlow(par_FlowID)
	}
	enableTriggers(par_FlowID)
	SaveFlowMetaData(par_FlowID)

	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_flows)
}
enableToggleFlow(par_FlowID)
{
	global
	EnterCriticalSection(_cs_flows)
	EnterCriticalSection(_cs_execution)
	
	if (_flows[par_FlowID].enabled != true)
	{
		enableFlow(par_FlowID)
	}
	else
	{
		disableFlow(par_FlowID)
	}
	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_flows)
}

disableFlow(par_FlowID)
{
	disableTriggers(par_FlowID)
	SaveFlowMetaData(par_FlowID)
}

enableTriggers(p_Flow)
{
	global EnabledTriggerIDCounter
	EnterCriticalSection(_cs_flows)
	EnterCriticalSection(_cs_execution)
	
	logger("a2", "Going to enable Flow " p_Flow.name)
	
	p_Flow.enabled:="Enabling"
	for forElementID, forElement in p_Flow.allElements
	{
		if (forElement.type = "trigger")
		{
			justEnableOneTrigger(p_Flow, forElement)
		}
		
	}
	p_Flow.enabled:=true
	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_flows)
	
	logger("a1", "Flow " p_Flow.name " enabled")
}

enableOneTrigger(p_Flow, p_Trigger, p_save=true)
{
	EnterCriticalSection(_cs_flows)
	EnterCriticalSection(_cs_execution)

	logger("a2", "Going to enable trigger " p_Trigger.ID " in flow " p_Flow.name)
	
	p_Flow.enabled:="Enabling"
	
	justEnableOneTrigger(p_Flow, p_Trigger)
	
	p_Flow.enabled:=true
	if (p_save)
		SaveFlowMetaData(p_Flow.id)
	
	logger("a1", "Trigger " p_Trigger.ID " in flow " p_Flow.name " enabled")
	
	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_flows)
}

justEnableOneTrigger(p_Flow, p_Trigger)
{
	global EnabledTriggerIDCounter
	EnterCriticalSection(_cs_flows)
	EnterCriticalSection(_cs_execution)
	
	triggerEnvironment:=criticalObject()
	triggerEnvironment.id:= "enabledTrigger" ++EnabledTriggerIDCounter
	triggerEnvironment.flowID:=p_Flow.ID
	triggerEnvironment.EnvironmentType:="trigger"
	triggerEnvironment.vars:=Object()
	triggerEnvironment.ElementID:=p_Trigger.id
	triggerEnvironment.UniqueID:=p_Trigger.UniqueID
	triggerEnvironment.ElementClass:=p_Trigger.class
	triggerEnvironment.Pars:=ObjFullyClone(p_Trigger.pars)
	
	_execution.triggers[triggerEnvironment.id]:=triggerEnvironment
	
	tempElementClass:=p_Trigger.class
	if isfunc("Element_enable_" tempElementClass)
	{
		Element_enable_%tempElementClass%(triggerEnvironment, triggerEnvironment.Pars)
	}
	else
	{
		logger("a0", "Trigger " triggerEnvironment.ElementID " cannot be enabled (missing implementation)")
	}

	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_flows)
}

disableTriggers(p_Flow)
{
	global EnabledTriggerIDCounter
	EnterCriticalSection(_cs_flows)
	EnterCriticalSection(_cs_execution)
	
	p_Flow.enabled:="Disabling"
	logger("a2", "Going to disable Flow " p_Flow.name)
	tempToDisableTriggers:=Object()
	
			;~ d(_execution.triggers,p_Flow.id)
	for forEnabledTriggerID, forEnabledTrigger in _execution.triggers
	{
		if (forEnabledTrigger.flowID = p_Flow.id)
		{
			tempToDisableTriggers.push({flow: p_Flow, element: p_Flow.allelements[forEnabledTrigger.elementid], enabledTrigger: forEnabledTrigger})
		}
		
	}
	
	for index, todisabletrigger in tempToDisableTriggers
	{
		justDisableOneTrigger(todisabletrigger.flow, todisabletrigger.element, todisabletrigger.enabledTrigger)
	}

	logger("a1", "Flow " p_Flow.name " disabled")
	p_Flow.enabled:=false

	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_flows)
}
disableOneTrigger(p_Flow, p_Trigger, p_save=true)
{
	EnterCriticalSection(_cs_flows)
	EnterCriticalSection(_cs_execution)

	p_Flow.enabled:="Disabling"
	logger("a2", "Going to disable trigger " p_Trigger.ID " in Flow " p_Flow.name)
	
	otherTriggersInThisFlowEnabled:=False
	for forEnabledTriggerID, forEnabledTrigger in _execution.triggers
	{
		if (forEnabledTrigger.flowID = p_Flow.id )
		{
			if ( forEnabledTrigger.elementID = p_Trigger.ID)
				justDisableOneTrigger(p_Flow, p_Trigger, forEnabledTrigger)
			else 
				otherTriggersInThisFlowEnabled:=true
		}
	}
	
	
	logger("a2", "Trigger " p_Trigger.ID " in Flow " p_Flow.name " disabled")
	if (otherTriggersInThisFlowEnabled = False)
	{
		p_Flow.enabled:=false
	}
	if (p_save)
		SaveFlowMetaData(p_Flow.id)
		
	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_flows)
}

justDisableOneTrigger(p_Flow, p_Trigger, p_EnabledTrigger)
{
	EnterCriticalSection(_cs_flows)
	EnterCriticalSection(_cs_execution)

	tempElementClass:=p_Trigger.Class
	;~ d(forTrigger,"Element_disable_" tempElementClass)
	if isfunc("Element_disable_" tempElementClass)
	{
		Element_disable_%tempElementClass%(p_EnabledTrigger, p_EnabledTrigger.Pars)
		p_Flow.allelements[p_Trigger.ID].enabled := false
		p_Flow.draw.mustdraw := true
	}
	else
	{
		logger("a0", "Trigger " p_Trigger.ID " cannot be disabled (missing implementation)")
	}
	;~ d(_execution)
	_execution.triggers.delete(p_EnabledTrigger.id)
	;~ d(_execution)
	
	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_flows)
}

saveResultOfTriggerEnabling(Environment, Result, Message)
{
	Environment.result:=Result
	Environment.Message:=Message
	if (Result = "normal")
	{
		_flows[Environment.flowID].allElements[Environment.elementID].enabled:=True
		if (Message = "")
			logger("a2", "Trigger " triggerEnvironment.ElementID " enabled")
		else
			logger("a2", "Trigger " triggerEnvironment.ElementID " enabled (" Message ")")
	}
	else if (result = "exception")
	{
		_flows[Environment.flowID].allElements[Environment.elementID].enabled:=False
		if (Message = "")
		{
			logger("a0", "Trigger " triggerEnvironment.ElementID " cannot be enabled")
			MsgBox, 16, % lang("Exception occured") , % lang("%1% '%2%' (ID '%3%') cannot be enabled due to an exception.", lang(_flows[Environment.flowID].allElements[Environment.elementID].type), _flows[Environment.flowID].allElements[Environment.elementID].name, Environment.elementID)
		}
		else
		{
			logger("a0", "Trigger " triggerEnvironment.ElementID " cannot be enabled (" Message ")")
			MsgBox, 16, % lang("Exception occured") , % lang("%1% '%2%' (ID '%3%') cannot be enabled due to an exception.", lang(_flows[Environment.flowID].allElements[Environment.elementID].type), _flows[Environment.flowID].allElements[Environment.elementID].name, Environment.elementID) "`n`n" Message
		}
	}
	else
	{
		logger("a0", "Trigger " triggerEnvironment.ElementID " cannot be enabled (unknown result: " Result ")")
		MsgBox, 16, % lang("Exception occured") , % lang("%1% '%2%' (ID '%3%') cannot be enabled." "`n" lang("Unknown result: %1%", Result), lang(_flows[Environment.flowID].allElements[Environment.elementID].type), _flows[Environment.flowID].allElements[Environment.elementID].name, Environment.elementID) "`n`n" Message
	}
	_flows[Environment.flowID].draw.mustdraw := true
}

saveResultOfTriggerDisabling(Environment, Result, Message)
{
	Environment.result:=Result
	Environment.Message:=Message
	if (Result = "normal")
	{
		_flows[Environment.flowID].allElements[Environment.elementID].enabled:=False
		if (Message = "")
			logger("a2", "Trigger " triggerEnvironment.ElementID " disabled")
		else
			logger("a2", "Trigger " triggerEnvironment.ElementID " disabled (" Message ")")
	}
	else if (result = "error")
	{
		;~ Environment.enabled:=True
		if (Message = "")
		{
			logger("a0", "Trigger " triggerEnvironment.ElementID " cannot be disabled")
			MsgBox, 16, % lang("Exception occured") , % lang("%1% '%2%' (ID '%3%') cannot be disabled due to an exception.", lang(_flows[Environment.flowID].allElements[Environment.elementID].type), _flows[Environment.flowID].allElements[Environment.elementID].name, Environment.elementID)
		}
		else
			logger("a0", "Trigger " triggerEnvironment.ElementID " cannot be disabled (" Message ")")
			MsgBox, 16, % lang("Exception occured") , % lang("%1% '%2%' (ID '%3%') cannot be disabled due to an exception.", lang(_flows[Environment.flowID].allElements[Environment.elementID].type), _flows[Environment.flowID].allElements[Environment.elementID].name, Environment.elementID) "`n`n" Message
	}
	else
	{
		logger("a0", "Trigger " triggerEnvironment.ElementID " cannot be disabled (unknown result: " Result ")")
	}
	_flows[Environment.flowID].draw.mustdraw := true
}
