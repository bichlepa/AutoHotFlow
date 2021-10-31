;This function used to fill a list of all available element classes. It is not required anymore
Element_Register_Element_Class(p_class)
{
	; nothing to do
}

; Returns parametration details of an element class.
; the result of the actual call of the element function is buffered to save execution time
Element_getParametrizationDetails(elementClass, Environment, updateIfRequired = false)
{
	; we will use this static variable to buffer the results of the call, since they never change.
	static Element_bufferedParametrationDetails
	if (not isobject(Element_bufferedParametrationDetails))
		Element_bufferedParametrationDetails := Object()

	; check whether the result of the call is already buffered
	if (not isobject(Element_bufferedParametrationDetails[elementClass])
		or (Element_bufferedParametrationDetails[elementClass].updateOnEdit and updateIfRequired )) ;If the edit field is opened and the parameters must be reloaded
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

; Returns a list of all parameter IDs and their default value.
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
			if (oneParameterDetail.type = "label")
			{
				; a label may have an ID (if it needs to be changed while user edits the parameters), but it has not value
				continue
			}

			; the value in key "ID" can contain parameter IDs
			if (oneParameterDetail.ID)
			{
				if not isobject(oneParameterDetail.ID)
				{
					; the value contains a single parameter ID. Add it.
					tempObject.push({ID: oneParameterDetail.ID, default: oneParameterDetail.default})
				}
				else
				{
					; The value contains a list of parameter IDs. Add them all.
					for index3, OneID in oneParameterDetail.ID
					{
						tempObject.push({ID: oneParameterDetail.OneID, default: oneParameterDetail.default[index3]})
					}
				}
			}
			; the value in key "ContentID" can contain parameter IDs
			if (oneParameterDetail.ContentID)
			{
				if not isobject(oneParameterDetail.ContentID)
				{
					; the value contains a single parameter ID. Add it.
					tempObject.push({ID: oneParameterDetail.ContentID, default: oneParameterDetail.ContentDefault})
				}
				else
				{
					; The value contains a list of parameter IDs. Add them all.
					for index3, OneID in oneParameterDetail.ContentID
					{
						tempObject.push({ID: oneParameterDetail.OneID, default: oneParameterDetail.ContentDefault[index3]})
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
