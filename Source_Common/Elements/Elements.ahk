;Only called from main thread. Fills a list of all available element classes
Element_Register_Element_Class(p_class)
{
	AllElementClasses := _getSharedProperty("AllElementClasses")

	if (not isFunc("Element_getElementType_" p_class))
	{
		logger("A0", "Element class " p_class " is not fully implemented. Missing function: Element_getParametrizationDetails_" p_class "()", ,true)
		return
	}
	elementType := Element_getElementType_%p_class%()
	requiredFunctions := []
	requiredFunctions.push("Element_getElementType_")
	requiredFunctions.push("Element_getName_")
	requiredFunctions.push("Element_getCategory_")
	requiredFunctions.push("Element_getPackage_")
	requiredFunctions.push("Element_getElementLevel_")
	requiredFunctions.push("Element_getIconPath_")
	requiredFunctions.push("Element_getStabilityLevel_")
	requiredFunctions.push("Element_getParametrizationDetails_")
	requiredFunctions.push("Element_GenerateName_")
	requiredFunctions.push("Element_CheckSettings_")

	if (elementType = "action" or elementType = "condition" or elementType = "loop")
	{
		requiredFunctions.push("Element_run_")
		requiredFunctions.push("Element_stop_")
	}
	else if (elementType = "trigger")
	{
		requiredFunctions.push("Element_enable_")
		requiredFunctions.push("Element_postTrigger_")
		requiredFunctions.push("Element_disable_")
	}
	Else
	{
		logger("A0", "Element class " p_class " is of not supported type: " elementType, ,true)
		return
	}

	for oneindex, oneRequiredFunction in requiredFunctions
	{
		if (not isFunc(oneRequiredFunction p_class))
		{
			logger("A0", "Element class " p_class " is not fully implemented. Missing function: " oneRequiredFunction p_class "()", ,true)
			return
		}
	}


	AllElementClasses.push(p_class)
	_setSharedProperty("AllElementClasses", AllElementClasses)
}

; Returns parametration details of an element class.
; the result of the actual call of the element function is buffered to save execution time
Element_getParametrizationDetails(elementClass, Environment)
{
	; we will use this static variable to buffer the results of the call, since they never change.
	static Element_bufferedParametrationDetails
	if (not isobject(Element_bufferedParametrationDetails))
		Element_bufferedParametrationDetails := Object()

	; check whether the result of the call is already buffered
	if (not isobject(Element_bufferedParametrationDetails[elementClass])
		or (Element_bufferedParametrationDetails[elementClass].updateOnEdit and Environment.updateOnEdit )) ;If the edit field is opened and the parameters must be reloaded
	{
		; it is not buffered. Call the element function
		if not IsFunc("Element_getParametrizationDetails_" elementClass)
		{
			; if this happens, the element is not properly implemented
			logger("a0", "unexpected error! function Element_getParametrizationDetails_" elementClass " does not exist")
			throw exception("unexpected error! function Element_getParametrizationDetails_" elementClass " does not exist", -1)
			return
		}

		; call the element funciton and buffer the result
		Element_bufferedParametrationDetails[elementClass] := Element_getParametrizationDetails_%elementClass%(Environment)
	}
	; return the buffered result
	return ObjFullyClone(Element_bufferedParametrationDetails[elementClass])
}

; Returns a list of all parameter IDs.
; the result of the actual call of the element function is buffered to save execution time
Element_getParameters(elementClass, Environment)
{
	; we will use this static variable to buffer the results of the call, since they never change.
	static Element_bufferedParameters
	if (not isobject(Element_bufferedParameters))
		Element_bufferedParameters := Object()
	
	; check whether the result of the call is already buffered
	if (not isobject(Element_bufferedParameters[elementClass]))
	{
		; it is not buffered. Create list of all parameter IDs.
		tempObject := Object()

		; get parametration details.
		ParametrizationDetails := Element_getParametrizationDetails(elementClass, Environment)

		; find all parameter IDs in the paraemetration details
		for index, oneParameterDetail in ParametrizationDetails
		{
			; the value in key "ID" can contain parameter IDs
			if (oneParameterDetail.ID)
			{
				if not isobject(oneParameterDetail.ID)
				{
					; the value contains a single parameter ID. Add it.
					tempObject.push(oneParameterDetail.ID)
				}
				else
				{
					; The value contains a list of parameter IDs. Add them all.
					for index3, OneID in oneParameterDetail.ID
					{
						tempObject.push(OneID)
					}
				}
			}
			; the value in key "ContentID" can contain parameter IDs
			if (oneParameterDetail.ContentID)
			{
				if not isobject(oneParameterDetail.ContentID)
				{
					; the value contains a single parameter ID. Add it.
					tempObject.push(oneParameterDetail.ContentID)
				}
				else
				{
					; The value contains a list of parameter IDs. Add them all.
					for index3, OneID in oneParameterDetail.ContentID
					{
						tempObject.push(OneID)
					}
				}
			}
		}

		; buffer the result
		Element_bufferedParameters[elementClass]:=tempObject
	}

	; return the buffered result
	return ObjFullyClone(Element_bufferedParameters[elementClass])
}
