Element_bufferedParametrationDetails:=Object()
Element_bufferedParameters:=Object()

Element_getParametrizationDetails(elementClass, Environment)
{
	global Element_bufferedParametrationDetails
	if not isobject(Element_bufferedParametrationDetails[elementClass])
	{
		Element_bufferedParametrationDetails[elementClass]:=Element_getParametrizationDetails_%elementClass%(Environment)
	}
	return Element_bufferedParametrationDetails[elementClass]
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
	return Element_bufferedParameters[elementClass]
}