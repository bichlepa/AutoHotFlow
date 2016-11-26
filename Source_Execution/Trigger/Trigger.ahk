EnabledTriggerIDCounter:=0


enableTriggers(p_Flow)
{
	global _execution, EnabledTriggerIDCounter
	
	logger("a2", "Going to enable Flow " p_Flow.name)
	
	p_Flow.enabled:="Enabling"
	for forElementID, forElement in p_Flow.allElements
	{
		if (forElement.type = "trigger")
		{
			triggerEnvironment:=Object()
			triggerEnvironment.id:= "enabledTrigger" ++EnabledTriggerIDCounter
			triggerEnvironment.flowID:=p_Flow.ID
			triggerEnvironment.ElementID:=forElementID
			triggerEnvironment.ElementClass:=forElement.class
			triggerEnvironment.Pars:=ObjFullyClone(forElement.pars)
			
			_execution.triggers[triggerEnvironment.id]:=triggerEnvironment
			
			tempElementClass:=forElement.class
			;~ d(forElement,Element_enable_%tempElementClass%)
			if isfunc("Element_enable_" tempElementClass)
			{
				Element_enable_%tempElementClass%(triggerEnvironment, triggerEnvironment.Pars)
			}
			else
			{
				logger("a0", "Trigger " triggerEnvironment.ElementID " cannot be enabled (missing implementation)")
			}
		}
		
	}
	p_Flow.enabled:=true
	
	logger("a1", "Flow " p_Flow.name " enabled")
	;~ d(p_flow)
}
disableTriggers(p_Flow)
{
	global _execution, EnabledTriggerIDCounter
	
	p_Flow.enabled:="Disabling"
	logger("a2", "Going to disable Flow " p_Flow.name)
	
			;~ d(_execution.triggers,p_Flow.id)
	for forTriggerID, forTrigger in _execution.triggers
	{
		if (forTrigger.flowID = p_Flow.id)
		{
			
			
			triggerEnvironment:=forTrigger
			tempElementClass:=triggerEnvironment.ElementClass
			;~ d(forTrigger,"Element_disable_" tempElementClass)
			if isfunc("Element_disable_" tempElementClass)
			{
				Element_disable_%tempElementClass%(triggerEnvironment, triggerEnvironment.Pars)
			}
			else
			{
				logger("a0", "Trigger " triggerEnvironment.ElementID " cannot be disabled (missing implementation)")
			}
			_execution.triggers.delete(forTriggerID)
		}
		
	}
	
	
	logger("a1", "Flow " p_Flow.name " disabled")
	p_Flow.enabled:=false
	;~ d(p_flow)
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
