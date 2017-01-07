/* Prototypes
Element_New(p_type,p_elementID)
Element_SetType(p_elementID,p_elementType)
Element_setParameterDefaults(p_elementID)
Element_Remove(p_elementID)
MarkOne(p_ID,false)
UnmarkEverything()
MarkEverything()
Connection_New(p_elementID)
Connection_Remove(p_elementID)
GetListContainingElement(p_ElementID)
*/

;Creates a new element and puts it in the array "allelements"
Element_New(p_FlowID, p_type="",p_elementID="")
{
	global _flows
	global GridX, Gridy
	
	;~ allElements:=_flows[p_FlowID].allElements
	
	tempElement:=CriticalObject()
	;~ tempElement:=[]
	
	if (p_elementID="")
		tempElement.ID:="element" . format("{1:010u}",++_flows[p_FlowID].ElementIDCounter) 
	else
		tempElement.ID:=p_elementID
	
	;~ d(p_elementID "--" tempElement.ID)
	
	tempElement.ClickPriority:=500
	;~ d(p_elementID "--" tempElement.ID "--" tempElement.ClickPriority)
	tempElement.pars:=[]
	
	tempElement.StandardName:=True
	tempElement.lastrun:=0
	tempElement.marked:=false
	tempElement.state:="idle"
	tempElement.countRuns:=0
	tempElement.enabled:=False
	
	;Assign default position, although it is commonly not needed
	tempElement.x:=0
	tempElement.y:=0
	
	 
	_flows[p_FlowID].allElements[tempElement.id]:=tempElement
	
	Element_SetType(p_FlowID, tempElement.ID,p_type)
	
	return tempElement.ID
}

;Sets the element type. It could later be possible to change the element type (e.g. change from type "action" to type "condition")
Element_SetType(p_FlowID, p_elementID,p_elementType)
{
	global _flows
	
	allElements:=_flows[p_FlowID].allElements
	
	allElements[p_elementID].type:=p_elementType 
	allElements[p_elementID].class:="" ;After changing the element type only, the class is unset 
	
	
	allElements[p_elementID].name:="Νew Соntainȩr"
	
	if (p_elementType="Loop")
	{
		allElements[p_elementID].heightOfVerticalBar:=150
	}
}

;Sets the element class. This means it is possible to change the element type and subtype
Element_SetClass(p_FlowID, p_elementID, p_elementClass)
{
	global _flows
	
	allElements:=_flows[p_FlowID].allElements
	
	;First set type
	if not isfunc("Element_getElementType_" p_elementClass)
	{
		MsgBox internal error! Function Element_getElementType_%p_elementClass% missing.
	}
	if (allElements[p_elementID].type!=Element_getElementType_%p_elementClass%())
	{
		Element_SetType(p_FlowID, p_elementID,Element_getElementType_%p_elementClass%())
	}
	
	;Then set class
	allElements[p_elementID].class:=p_elementClass 
	allElements[p_elementID].icon:=Element_getIconPath_%p_elementClass%()
	
	;If element is trigger_manual: Set the trigger as default if no other is already default
	if (p_elementClass = "trigger_manual" and Element_findDefaultTrigger(p_FlowID)="")
	{
		Element_setDefaultTrigger(p_FlowID, p_elementID)
	}
	
	
	Element_setParameterDefaults(p_FlowID, p_elementID)
	
	
	allElements[p_elementID].name:=Element_GenerateName_%p_elementClass%(allElements[p_elementID], allElements[p_elementID].pars)
	

}

;Is called when the element subtype is set. All parameters that are not set yet are set to the default parameters
Element_setParameterDefaults(p_FlowID, p_elementID)
{
	global _flows
	
	allElements:=_flows[p_FlowID].allElements
	
	elementClass:=allElements[p_elementID].class
	
	parameters:=Element_getParametrizationDetails_%elementClass%({flowID: p_FlowID, elementID: p_elementID})
	;~ MsgBox % strobj(parameters) "`n" elementType "`n" elementSubType
	for index, parameter in parameters
	{
		
		if not IsObject(parameter.id)
			parameterID:=[parameter.id]
		else
			parameterID:=parameter.id
		if not IsObject(parameter.default)
			parameterdefault:=[parameter.default]
		else
			parameterdefault:=parameter.default
	
		if (parameterID[1]="" or parameter.type="label" or parameter.type="SmallLabel") ;If this is only a label for the edit fielt etc. Do nothing
			continue
		
		;~ MsgBox % strobj(parameter)
		;Certain types of control consist of multiple controls and thus contain multiple parameters.
		for index2, oneID in parameterID
		{
			;~ MsgBox % oneID "  -  " index2 " - " parameterdefault[index2]
			if (allElements[p_elementID].pars[oneID]="")
			{
				tempContent:=parameterdefault[index2]
				
				StringReplace, tempContent, tempContent, |¶,`n, All
				allElements[p_elementID].pars[oneID]:=tempContent
			}
			
		}
		
	
	}
	
	
}

Element_findDefaultTrigger(p_FlowID)
{
	global _flows
	for oneID, oneElement in _flows[p_FlowID].allElements
	{
		if (oneElement.class = "trigger_manual")
		{
			if (oneElement.defaultTrigger)
				return oneID
		}
	}
}

Element_setDefaultTrigger(p_FlowID, p_elementID)
{
	global _flows
	for oneID, oneElement in _flows[p_FlowID].allElements
	{
		if (oneElement.class = "trigger_manual")
		{
	;~ MsgBox %p_FlowID% %p_elementID%
			if (oneID = p_elementID )
			{
				oneElement.defaultTrigger:=True
			}
			else
			{
				oneElement.defaultTrigger:=False
			}
		}
	}
}


;Removes the element. It will be deleted from list of all elements and all connections which start or ends there will be deleted, too
Element_Remove(p_FlowID, p_elementID)
{
	global _flows
	
	allElements:=_flows[p_FlowID].allElements
	allConnections:=_flows[p_FlowID].allConnections
	markedElements:=_flows[p_FlowID].markedElements
	
	;If the element is a connection, call function to delete connection
	IfInString,p_elementID,connection
	{
		Connection_Remove(p_FlowID, p_elementID)
		return
	}
	
	
	
	;remove the element from list of all elements
	for forID, forElement in allElements
	{
		if (forID=p_elementID)
		{
			allElements.delete(forID)
			break
		}
	}
	
	;~ ;If the element is marked, unmark it
	;~ for forID, forElement in markedElements
	;~ {
		;~ if (forID=p_elementID)
		;~ {
			;~ UnmarkEverything(p_FlowID) ;Unmark all elements
			;~ break
		;~ }
	;~ }
	
	;remove the connections which end or start at the element ;TODO: if removing an element with only one connection from and one connection to the element, keep one connection
	copyAllConnections:=allConnections.clone()
	for forID, forElement in copyAllConnections
	{
		if ((forElement.from=p_elementID) or (forElement.to=p_elementID))
		{
			Connection_Remove(p_FlowID, forID)
		}
	}
	
}




Connection_New(p_FlowID, p_elementID="")
{
	global _flows
	
	allConnections:=_flows[p_FlowID].allConnections
	
	tempElement:=CriticalObject()
	if (p_elementID="")
		tempElement.ID:="Connection" . format("{1:010u}",++_flows[p_FlowID].ElementIDCounter) 
	else
		tempElement.ID:=p_elementID
	
	tempElement.ConnectionType:="normal"
	tempElement.ClickPriority:=200
	
	tempElement.marked:=false
	tempElement.state:="idle"
	tempElement.type:="Connection"
	tempElement.frompart:=""
	tempElement.topart:=""
	
	allConnections[tempElement.id]:=tempElement
	
	return tempElement.ID
}


;Removes the connection. It will be deleted from list of all elements and all connections which start or ends there will be deleted, too
Connection_Remove(p_FlowID, p_elementID)
{
	global _flows
	
	allConnections:=_flows[p_FlowID].allConnections
	markedElements:=_flows[p_FlowID].markedElements
	
	;remove the element from list of all connections
	for forID, forElement in allConnections
	{
		if (forID=p_elementID)
		{
			allConnections.delete(forID)
			break
		}
	}
	
	;~ _flows[p_FlowID].allConnections[forID].marked:=false
	
	;If the element is marked, unmark it
	;~ for forID, forElement in markedElements
	;~ {
		;~ if (forID=p_elementID)
		;~ {
			;~ UnmarkEverything(p_FlowID) ;Unmark all elements
			;~ break
		;~ }
	;~ }
	
	;~ API_editor_CreateMarkedList(p_FlowID)
}


;~ ;
GetListContainingElement(p_FlowID, p_ElementID, p_returnPointer = false)
{
	global _flows
	
	if _flows[p_FlowID].allElements.HasKey(p_ElementID)
		templist := _flows[p_FlowID].allElements
	else if _flows[p_FlowID].allConnections.HasKey(p_ElementID)
		templist := _flows[p_FlowID].allConnections
	if (p_returnPointer)
		return &templist
	else
		return templist
}

UpdateConnectionLists(p_FlowID)
{
	global _flows
	for oneElementID, oneElement in _flows[p_FlowID].allElements
	{
		oneElement.fromConnections:=Object()
		oneElement.toConnections:=Object()
	}
	for oneConnectionID, oneConnection in _flows[p_FlowID].allConnections
	{
		_flows[p_FlowID].allElements[oneConnection.from].fromConnections.push(oneConnectionID)
		_flows[p_FlowID].allElements[oneConnection.to].toConnections.push(oneConnectionID)
	}
}