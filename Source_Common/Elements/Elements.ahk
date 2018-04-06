Element_bufferedParametrationDetails:=Object()
Element_bufferedParameters:=Object()

Element_Register_Element_Class(p_class)
{
	_share.AllElementClasses.push(p_class)
}

Element_getParametrizationDetails(elementClass, Environment)
{
	global Element_bufferedParametrationDetails
	if (not isobject(Element_bufferedParametrationDetails[elementClass]) 
		or (Element_bufferedParametrationDetails[elementClass].updateOnEdit and Environment.updateOnEdit )) ;If the edit field is opened and the parameters must be reloaded
	{
		if not IsFunc("Element_getParametrizationDetails_" elementClass)
			MsgBox unexpected error function Element_getParametrizationDetails_%elementClass% does not exist
		Element_bufferedParametrationDetails[elementClass]:=Element_getParametrizationDetails_%elementClass%(Environment)
	}
	return ObjFullyClone(Element_bufferedParametrationDetails[elementClass])
}

Element_getParameters(elementClass, Environment)
{
	global Element_bufferedParameters
	if not isobject(Element_bufferedParameters[elementClass])
	{
		tempObject:=Object()
		ParametrizationDetails:=Element_getParametrizationDetails(elementClass, Environment)
		for index, oneParameterDetail in ParametrizationDetails
		{
			if (oneParameterDetail.ID)
			{
				if not isobject(oneParameterDetail.ID)
				{
					tempObject.push(oneParameterDetail.ID)
				}
				else
				{
					for index3, OneID in oneParameterDetail.ID
					{
						tempObject.push(OneID)
					}
				}
			}
			if (oneParameterDetail.ContentID)
			{
				if not isobject(oneParameterDetail.ContentID)
				{
					tempObject.push(oneParameterDetail.ContentID)
				}
				else
				{
					for index3, OneID in oneParameterDetail.ContentID
					{
						tempObject.push(OneID)
					}
				}
			}
		}
		
		Element_bufferedParameters[elementClass]:=tempObject
	}
	return ObjFullyClone(Element_bufferedParameters[elementClass])
}