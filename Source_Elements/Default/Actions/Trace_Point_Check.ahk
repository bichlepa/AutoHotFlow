;Always add this element class name to the global list
x_RegisterElementClass("Action_Trace_Point_Check")

;Element type of the element
Element_getElementType_Action_Trace_Point_Check()
{
	return "action"
}

;Name of the element
Element_getName_Action_Trace_Point_Check()
{
	return x_lang("Trace_Point_Check")
}

;Category of the element
Element_getCategory_Action_Trace_Point_Check()
{
	return x_lang("Debugging")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Trace_Point_Check()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Trace_Point_Check()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Programmer"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getIconPath_Action_Trace_Point_Check()
{
	return "Source_elements\default\icons\New variable.png"
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Trace_Point_Check()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Trace_Point_Check(Environment)
{
	; get all trace points of the flow
	FlowID := x_GetMyFlowID(Environment)
	allTracePointElementIDs := x_getAllElementIDsOfClass(FlowID, "Action_Trace_Point")
	allTracePointIDs := Object()
	for oneIndex, oneElementID in allTracePointElementIDs 
	{
		elementpars := x_getElementPars(FlowID, oneElementID)
		allTracePointIDs.push(elementpars.id " (" oneElementID ")")
	}
	
	parametersToEdit := Object()
	parametersToEdit.push({type: "Label", label: x_lang("Tracepoints which must be passed")})
	parametersToEdit.push({type: "Checkbox", id: "MustPassTracepointsAll", default: 0, label: x_lang("All tracepoints")})
	parametersToEdit.push({type: "ListBox", id: "MustPassTracepoints", result: "String", choices: allTracePointIDs, multi: True})
	parametersToEdit.push({type: "Label", label: x_lang("Tracepoints which must not be passed")})
	parametersToEdit.push({type: "Checkbox", id: "MustNotPassTracepointsAll", default: 0, label: x_lang("All tracepoints")})
	parametersToEdit.push({type: "ListBox", id: "MustNotPassTracepoints", result: "String", choices: allTracePointIDs, multi: True})
	
	; we want that this function is called every time when the element editor is opened
	parametersToEdit.updateOnEdit := true

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Trace_Point_Check(Environment, ElementParameters)
{
	global
	return % x_lang("Trace_Point_Check")
	
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Trace_Point_Check(Environment, ElementParameters, staticValues)
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

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Trace_Point_Check(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; get flow ID
	FlowID := x_GetMyFlowID(Environment)

	; get all tracepoints which must not have been passed
	if (ElementParameters.MustPassTracepointsAll)
	{
		; get all element IDs of tracepoint actions
		allTracePointElementIDs := x_getAllElementIDsOfClass(FlowID, "Action_Trace_Point")

		; write all tracepoints IDs with their element IDs to variable allTracePointMustPass
		allTracePointMustPass := Object()
		for oneIndex, oneElementID in allTracePointElementIDs 
		{
			elementpars := x_getElementPars(FlowID, oneElementID)
			allTracePointMustPass.push(elementpars.id " (" oneElementID ")")
		}
	}
	else
	{
		; get the list of all element which must pass
		allTracePointMustPass := ElementParameters.MustPassTracepoints
	}
	
	; get all tracepoints which must not have been passed
	if (ElementParameters.MustNotPassTracepointsAll)
	{
		; get all element IDs of tracepoint actions
		allTracePointElementIDs := x_getAllElementIDsOfClass(FlowID, "Action_Trace_Point")
		
		; write all tracepoints IDs with their element IDs to variable allTracePointMustNotPass
		allTracePointMustNotPass := Object()
		for oneIndex, oneElementID in allTracePointElementIDs 
		{
			elementpars := x_getElementPars(FlowID, oneElementID)
			allTracePointMustNotPass.push(elementpars.id " (" oneElementID ")")
		}
	}
	else
	{
		; get the list of all element which must not pass
		allTracePointMustNotPass := ElementParameters.MustNotPassTracepoints
	}
	
	; get the hidden variable passed_Tracepoints. It contains all passed tracepoints
	passed_Tracepoints := x_GetVariable(Environment, "passed_Tracepoints", true)
	
	; check, whether some tracepoins were not passed which must have been passed
	TracePointsMustPassedButNotPassed := Object()
	for oneMustPassIndex, oneMustPassTracePoint in allTracePointMustPass
	{
		found := False
		; Ignore Tracepoints which are selected as Must not be passed
		if (ElementParameters.MustPassTracepointsAll)
		{
			for oneMustNotPassIndex, oneMustNotPassTracePoint in allTracePointMustNotPass
			{
				if (oneMustNotPassTracePoint = oneMustPassTracePoint)
				{
					found := True
				}
			}
		}
		; check whether the tracepoint was passed
		for onePassedIndex, onePassedTracePoint in passed_Tracepoints
		{
			if (onePassedTracePoint = oneMustPassTracePoint)
			{
				found := True
			}
		}
		if (found = False)
		{
			; tracepoint was not passed. Add it to the list
			TracePointsMustPassedButNotPassed.push(oneMustPassTracePoint)
		}
	}
	
	; check, whether some tracepoins were passed which must not have been passed
	TracePointsMustNotPassedButPassed := Object()
	for oneMustNotPassIndex, oneMustNotPassTracePoint in allTracePointMustNotPass
	{
		found := False
		ignore := False
		if (ElementParameters.MustNotPassTracepointsAll)
		{
			;Ignore Tracepoints which are selected as Must be passed
			for oneMustPassIndex, oneMustPassTracePoint in allTracePointMustPass
			{
				if (oneMustNotPassTracePoint = oneMustPassTracePoint)
				{
					ignore := True
				}
			}
		}
		if (ignore = False)
		{
			; check whether the tracepoint was passed
			for onePassedIndex, onePassedTracePoint in passed_Tracepoints
			{
				if (onePassedTracePoint = oneMustNotPassTracePoint)
				{
					found := True
				}
			}
		}
		if (found = True)
		{
			; checkpoint was passed. Add it to the list
			TracePointsMustNotPassedButPassed.push(oneMustNotPassTracePoint)
		}
	}
	
	if (TracePointsMustPassedButNotPassed.maxindex() <1 and TracePointsMustNotPassedButPassed.maxindex() <1)
	{
		; there were no violations
		x_finish(Environment, "normal")
	}
	else
	{
		; there were violations. Generate error message and finish with exception.
		message := ""
		if (TracePointsMustPassedButNotPassed.maxindex() >= 1)
		{
			tempString := ""
			for oneIndex, oneTracePoint in TracePointsMustPassedButNotPassed
			{
				if (tempString != "")
					tempString .= ", "
				tempString .= oneTracePoint
			}
			message.= x_lang("%1% tracepoints were not passed which must have been passed: %2%.", TracePointsMustNotPassedButPassed.maxindex(), tempString) " "
		}
		if (TracePointsMustNotPassedButPassed.maxindex() >= 1)
		{
			tempString := ""
			for oneIndex, oneTracePoint in TracePointsMustNotPassedButPassed
			{
				if (tempString != "")
					tempString .= ", "
				tempString .= oneTracePoint
			}
			message.= x_lang("%1% tracepoints were passed which must not have been passed: %2%.", TracePointsMustNotPassedButPassed.maxindex(), tempString)
			
		}
		messate := trim(message)
		x_finish(Environment, "exception", message)
	}
	
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Trace_Point_Check(Environment, ElementParameters)
{
	; nothing to do
}

