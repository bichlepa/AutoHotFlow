;Always add this element class name to the global list
x_RegisterElementClass("Action_Trace_Point_Check")

Element_getPackage_Action_Trace_Point_Check()
{
	return "default"
}

Element_getElementType_Action_Trace_Point_Check()
{
	return "action"
}

Element_getElementLevel_Action_Trace_Point_Check()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Programmer"
}

Element_getName_Action_Trace_Point_Check()
{
	return lang("Trace_Point_Check")
}

Element_getIconPath_Action_Trace_Point_Check()
{
	return "Source_elements\default\icons\New variable.png"
}

Element_getCategory_Action_Trace_Point_Check()
{
	return lang("Debugging")
}

Element_getParameters_Action_Trace_Point_Check()
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({id: "MustPassTracepointsAll"})
	parametersToEdit.push({id: "MustPassTracepoints"})
	parametersToEdit.push({id: "MustNotPassTracepointsAll"})
	parametersToEdit.push({id: "MustNotPassTracepoints"})
	parametersToEdit.push({id: "Wait"})
	
	return parametersToEdit
}

Element_getParametrizationDetails_Action_Trace_Point_Check(Environment)
{
	
	FlowID:=x_GetMyFlowID(Environment)
	
	allTracePointElementIDs := x_getAllElementIDsOfClass(FlowID, "Action_Trace_Point")
	;~ d(allTracePointElements)
	allTracePointIDs:=Object()
	for oneIndex, oneElementID in allTracePointElementIDs 
	{
		elementpars:=x_getElementPars(FlowID, oneElementID)
		;~ d(elementpars)
		allTracePointIDs.push(elementpars.id " (" oneElementID ")")
	}
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Tracepoints which must be passed")})
	parametersToEdit.push({type: "Checkbox", id: "MustPassTracepointsAll", default: 0, label: lang("All tracepoints")})
	parametersToEdit.push({type: "ListBox", id: "MustPassTracepoints", result: "String", choices: allTracePointIDs, multi: True})
	parametersToEdit.push({type: "Label", label: lang("Tracepoints which must not be passed")})
	parametersToEdit.push({type: "Checkbox", id: "MustNotPassTracepointsAll", default: 0, label: lang("All tracepoints")})
	parametersToEdit.push({type: "ListBox", id: "MustNotPassTracepoints", result: "String", choices: allTracePointIDs, multi: True})
	;~ parametersToEdit.push({type: "Label", label: lang("Options")}) ;TODO
	;~ parametersToEdit.push({type: "Checkbox", id: "Wait", default: 0, label: lang("Wait until all other threads have finished")})
	

	return parametersToEdit
}

Element_GenerateName_Action_Trace_Point_Check(Environment, ElementParameters)
{
	global
	return % lang("Trace_Point_Check")
	
}

Element_CheckSettings_Action_Trace_Point_Check(Environment, ElementParameters)
{
	if (ElementParameters.MustPassTracepointsAll = True)
	{
		x_Par_Disable("MustPassTracepoints")
		x_Par_Disable("MustNotPassTracepointsAll")
		x_Par_SetValue("MustNotPassTracepointsAll", False)
	}
	else
	{
		x_Par_Enable("MustPassTracepoints")
		x_Par_Enable("MustNotPassTracepointsAll")
	}
	
	if (ElementParameters.MustNotPassTracepointsAll = True)
	{
		x_Par_Disable("MustNotPassTracepoints")
		x_Par_Disable("MustPassTracepointsAll")
		x_Par_SetValue("MustPassTracepointsAll", False)
	}
	else
	{
		x_Par_Enable("MustNotPassTracepoints")
		x_Par_Enable("MustPassTracepointsAll")
	}
	
	
}

Element_run_Action_Trace_Point_Check(Environment, ElementParameters)
{
	;~ d(ElementParameters, "element parameters")
	FlowID:=x_GetMyFlowID(Environment)
	if (ElementParameters.MustPassTracepointsAll or ElementParameters.MustNotPassTracepointsAll)
	{
		allTracePointElementIDs := x_getAllElementIDsOfClass(FlowID, "Action_Trace_Point")
	}
	if (ElementParameters.MustPassTracepointsAll)
	{
		allTracePointMustPass:=Object()
		for oneIndex, oneElementID in allTracePointElementIDs 
		{
			elementpars:=x_getElementPars(FlowID, oneElementID)
			allTracePointMustPass.push(elementpars.id " (" oneElementID ")")
		}
	}
	else
	{
		allTracePointMustPass := ElementParameters.MustPassTracepoints
	}
	if (ElementParameters.MustNotPassTracepointsAll)
	{
		allTracePointMustNotPass:=Object()
		for oneIndex, oneElementID in allTracePointElementIDs 
		{
			elementpars:=x_getElementPars(FlowID, oneElementID)
			allTracePointMustNotPass.push(elementpars.id " (" oneElementID ")")
		}
	}
	else
	{
		allTracePointMustNotPass := ElementParameters.MustNotPassTracepoints
	}
	
	;~ if (ElementParameters.wait)
	;~ {
		;~ threadCount:=x_GetThreadCountInCurrentInstance(Environment)
		;~ if threadCount > 1
		;~ {
			;~ ;Wait until all other threads finish
			
			;~ return
		;~ }
	;~ }
	
	;Either not needed to wait or only one thread remained
	
	passed_Tracepoints := x_GetVariable(Environment, "passed_Tracepoints", "hidden")
	;~ d(passed_Tracepoints)
	TracePointsMustPassedButNotPassed:=Object()
	for oneMustPassIndex, oneMustPassTracePoint in allTracePointMustPass
	{
		found:=False
		;Ignore Tracepoints which are selected as Must not be passed
		if (ElementParameters.MustPassTracepointsAll)
		{
			for oneMustNotPassIndex, oneMustNotPassTracePoint in allTracePointMustNotPass
			{
				if (oneMustNotPassTracePoint = oneMustPassTracePoint)
				{
					found:=True
				}
			}
		}
		for onePassedIndex, onePassedTracePoint in passed_Tracepoints
		{
			if (onePassedTracePoint = oneMustPassTracePoint)
			{
				found:=True
			}
		}
		if (found = False)
		{
			TracePointsMustPassedButNotPassed.push(oneMustPassTracePoint)
		}
	}
	
	TracePointsMustNotPassedButPassed:=Object()
	for oneMustNotPassIndex, oneMustNotPassTracePoint in allTracePointMustNotPass
	{
		found:=False
		ignore:=False
		if (ElementParameters.MustNotPassTracepointsAll)
		{
			;Ignore Tracepoints which are selected as Must be passed
			for oneMustPassIndex, oneMustPassTracePoint in allTracePointMustPass
			{
				if (oneMustNotPassTracePoint = oneMustPassTracePoint)
				{
					ignore:=True
				}
			}
		}
		if (ignore = False)
		{
			for onePassedIndex, onePassedTracePoint in passed_Tracepoints
			{
				if (onePassedTracePoint = oneMustNotPassTracePoint)
				{
					found:=True
				}
			}
		}
		if (found = True)
		{
			TracePointsMustNotPassedButPassed.push(oneMustNotPassTracePoint)
		}
	}
	
	if (TracePointsMustPassedButNotPassed.maxindex() <1 and TracePointsMustNotPassedButPassed.maxindex() <1)
	{
		x_finish(Environment, "normal")
	}
	else
	{
		message:=""
		if (TracePointsMustPassedButNotPassed.maxindex() >=1)
		{
			tempString:=""
			for oneIndex, oneTracePoint in TracePointsMustPassedButNotPassed
			{
				if (tempString!="")
					tempString.=", "
				tempString.=oneTracePoint
			}
			message.= lang("%1% tracepoints were not passed which must have been passed: %2%.", TracePointsMustNotPassedButPassed.maxindex(), tempString) " "
		}
		if (TracePointsMustNotPassedButPassed.maxindex() >=1)
		{
			tempString:=""
			for oneIndex, oneTracePoint in TracePointsMustNotPassedButPassed
			{
				if (tempString!="")
					tempString.=", "
				tempString.=oneTracePoint
			}
			message.= lang("%1% tracepoints were passed which must not have been passed: %2%.", TracePointsMustNotPassedButPassed.maxindex(), tempString)
			
		}
		messate:=trim(message)
		x_finish(Environment, "exception", message)
	}
	
	
	;Always call v_finish() before return
	return
}