EnabledTriggerIDCounter:=0


enableTriggers(p_Flow)
{
	global EnabledTriggerIDCounter
	
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
	
	logger("a1", "Flow " p_Flow.name " enabled")
	;~ d(p_flow)
}

enableOneTrigger(p_Flow, p_Trigger)
{
	logger("a2", "Going to enable trigger " p_Trigger.ID " in flow " p_Flow.name)
	
	p_Flow.enabled:="Enabling"
	
	justEnableOneTrigger(p_Flow, p_Trigger)
	
	p_Flow.enabled:=true
	logger("a1", "Trigger " p_Trigger.ID " in flow " p_Flow.name " enabled")
}

justEnableOneTrigger(p_Flow, p_Trigger)
{
	global EnabledTriggerIDCounter
	
	triggerEnvironment:=criticalObject()
	triggerEnvironment.id:= "enabledTrigger" ++EnabledTriggerIDCounter
	triggerEnvironment.flowID:=p_Flow.ID
	triggerEnvironment.EnvironmentType:="trigger"
	triggerEnvironment.vars:=Object()
	triggerEnvironment.ElementID:=p_Trigger.id
	triggerEnvironment.ElementClass:=p_Trigger.class
	triggerEnvironment.Pars:=ObjFullyClone(p_Trigger.pars)
	
	_execution.triggers[triggerEnvironment.id]:=triggerEnvironment
	
	tempElementClass:=p_Trigger.class
	;~ d(forElement,Element_enable_%tempElementClass%)
	if isfunc("Element_enable_" tempElementClass)
	{
		Element_enable_%tempElementClass%(triggerEnvironment, triggerEnvironment.Pars)
		p_Flow.allelements[p_Trigger.ID].enabled := true
		p_Flow.draw.mustdraw := true
	}
	else
	{
		logger("a0", "Trigger " triggerEnvironment.ElementID " cannot be enabled (missing implementation)")
	}
	p_Flow.enabled:=true
}

disableTriggers(p_Flow)
{
	global EnabledTriggerIDCounter
	
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
	;~ d(p_flow)
}
disableOneTrigger(p_Flow, p_Trigger)
{
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
		p_Flow.enabled:=false
}

justDisableOneTrigger(p_Flow, p_Trigger, p_EnabledTrigger)
{
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
}

saveResultOfTriggerEnabling(Environment, Result, Message)
{
	Environment.result:=Result
	Environment.Message:=Message
	if (Result = "normal")
	{
		Environment.enabled:=True
		if (Message = "")
			logger("a2", "Trigger " triggerEnvironment.ElementID " enabled")
		else
			logger("a2", "Trigger " triggerEnvironment.ElementID " enabled (" Message ")")
	}
	else if (result = "error")
	{
		Environment.enabled:=False
		if (Message = "")
			logger("a0", "Trigger " triggerEnvironment.ElementID " cannot be enabled")
		else
			logger("a0", "Trigger " triggerEnvironment.ElementID " cannot be enabled (" Message ")")
	}
	else
	{
		logger("a0", "Trigger " triggerEnvironment.ElementID " cannot be enabled (unknown result: " Result ")")
	}
}

saveResultOfTriggerDisabling(Environment, Result, Message)
{
	Environment.result:=Result
	Environment.Message:=Message
	if (Result = "normal")
	{
		Environment.enabled:=False
		if (Message = "")
			logger("a2", "Trigger " triggerEnvironment.ElementID " disabled")
		else
			logger("a2", "Trigger " triggerEnvironment.ElementID " disabled (" Message ")")
	}
	else if (result = "error")
	{
		;~ Environment.enabled:=True
		if (Message = "")
			logger("a0", "Trigger " triggerEnvironment.ElementID " cannot be disabled")
		else
			logger("a0", "Trigger " triggerEnvironment.ElementID " cannot be disabled (" Message ")")
	}
	else
	{
		logger("a0", "Trigger " triggerEnvironment.ElementID " cannot be disabled (unknown result: " Result ")")
	}
}
