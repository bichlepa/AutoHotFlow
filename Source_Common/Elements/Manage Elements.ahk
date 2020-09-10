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
	global GridX, Gridy
	
	if not p_FlowID
	{
		MsgBox internal error! A new element should be created but FlowID is empty!
		return
	}

	EnterCriticalSection(_cs_shared) ; We get, change and store a flow in this function. keep this critical section to ensure data integrity

	tempElement:=Object()
	;~ tempElement:=[]
	
	if (p_elementID="")
		tempElement.ID:="element" . format("{1:010u}",_getAndIncrementFlowProperty(p_FlowID,"ElementIDCounter")) 
	else
		tempElement.ID:=p_elementID
	tempElement.ElementID:=tempElement.ID
	tempElement.FlowID:=p_FlowID
	
	;~ d(p_elementID "--" tempElement.ID)
	
	tempElement.UniqueID:=p_FlowID "_" tempElement.ID
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
	
	_setElement(p_FlowID, tempElement.ID, tempElement)

	Element_SetType(p_FlowID, tempElement.ID, p_type)
	
	LeaveCriticalSection(_cs_shared)
	return tempElement.ID
}

;Sets the element type. It could later be possible to change the element type (e.g. change from type "action" to type "condition")
Element_SetType(p_flowID, p_ElementID, p_elementType)
{
	if not p_ElementID
	{
		MsgBox internal error! A new element type should be set but ElementID is empty!
		return
	}

	EnterCriticalSection(_cs_shared) ; We get, change and store an element in this function. keep this critical section to ensure data integrity

	_setElementProperty(p_FlowID, p_elementID, "type", p_elementType)
	_setElementProperty(p_FlowID, p_elementID, "class", "")  ;After changing the element type only, the class is unset 
	
	_setElementProperty(p_FlowID, p_elementID, "name", "Νew Соntainȩr") 
	if (p_elementType="Loop")
	{
		_setElementProperty(p_FlowID, p_elementID, "heightOfVerticalBar", 150) 
	}
	
	LeaveCriticalSection(_cs_shared)
}

;Sets the element class. This means it is possible to change the element type and subtype
Element_SetClass(p_FlowID, p_ElementID, p_elementClass)
{
	if not p_ElementID
	{
		MsgBox internal error! A new element class should be set but ElementID is empty!
		return
	}

	EnterCriticalSection(_cs_shared) ; We get, change and store an element in this function. keep this critical section to ensure data integrity
	
	;First set type
	if not isfunc("Element_getElementType_" p_elementClass)
	{
		MsgBox internal error! Function Element_getElementType_%p_elementClass% missing.
	}
	if (_getElementProperty(p_FlowID, p_elementID, "type") !=Element_getElementType_%p_elementClass%())
	{
		Element_SetType(p_FlowID, p_elementID, Element_getElementType_%p_elementClass%())
	}
	
	;Then set class
	_setElementProperty(p_FlowID, p_elementID, "class", p_elementClass)
	_setElementProperty(p_FlowID, p_elementID, "icon", Element_getIconPath_%p_elementClass%())
	
	;Set new parameter Defaults
	Element_setParameterDefaults(p_FlowID, p_elementID)
	
	; Set the element name (which depends on the element parameters)
	newName:=Element_GenerateName_%p_elementClass%(allElements[p_elementID], allElements[p_elementID].pars)
	_setElementProperty(p_FlowID, p_elementID, "name", newName)
	
	
	;If element is trigger_manual: Set the trigger as default if no other is already default
	if (p_elementClass = "trigger_manual" and Element_findDefaultTrigger(p_FlowID)="")
	{
		Element_setDefaultTrigger(p_FlowID, p_elementID)
	}
	LeaveCriticalSection(_cs_shared)
}

;Is called when the element subtype is set. All parameters that are not set yet are set to the default parameters
Element_setParameterDefaults(p_FlowID, p_elementID)
{
	if not p_ElementID
	{
		MsgBox internal error! A element parameter defaults should be set but ElementID is empty!
		return
	}

	EnterCriticalSection(_cs_shared)  ; We get, change and store an element in this function. keep this critical section to ensure data integrity

	elementClass:=_getElementProperty(p_FlowID, p_elementID, "class")
	parameters:=Element_getParametrizationDetails(elementClass, {flowID: p_FlowID, elementID: p_elementID})
	;~ MsgBox % strobj(parameters) "`n" elementType "`n" elementSubType
	ElementParsObject:=_getElementProperty(p_FlowID, p_elementID, "pars")
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
			if (ElementParsObject[oneID]="")
			{
				tempContent:=parameterdefault[index2]
				
				StringReplace, tempContent, tempContent, |¶,`n, All
				ElementParsObject[oneID]:=tempContent
			}
			
		}
		
	
	}
	_setElementProperty(p_FlowID, p_elementID, "pars", ElementParsObject)
	
	LeaveCriticalSection(_cs_shared)
}

Element_findDefaultTrigger(p_FlowID)
{
	if not p_FlowID
	{
		MsgBox internal error! A new element should be created but FlowID is empty!
		return
	}
	
	allElements := _getFlowProperty(p_FlowID, "allElements")

	for oneID, oneElement in allElements
	{
		if (oneElement.class = "trigger_manual")
		{
			if (oneElement.defaultTrigger)
			{
				retval:= oneID
				break
			}
		}
	}
	
	return retval
}

Element_setDefaultTrigger(p_FlowID, p_elementID)
{
	if not p_FlowID
	{
		MsgBox internal error! A new element should be created but FlowID is empty!
		return
	}

	EnterCriticalSection(_cs_shared) ; We get, change and store a flow in this function. keep this critical section to ensure data integrity

	allElements := _getFlowProperty(p_FlowID, "allElements")
	for oneID, oneElement in allElements
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
	_setFlowProperty(p_FlowID, "allElements", allElements)

	LeaveCriticalSection(_cs_shared)
}


;Removes the element. It will be deleted from list of all elements and all connections which start or ends there will be deleted, too
Element_Remove(p_FlowID, p_elementID)
{
	if not p_FlowID
	{
		MsgBox internal error! A new element should be created but FlowID is empty!
		return
	}

	EnterCriticalSection(_cs_shared) ; We get, change and store a flow in this function. keep this critical section to ensure data integrity

	; allElements:=_getFlowProperty(p_FlowID, "allElements")
	; markedElements:=_getFlowProperty(p_FlowID, "markedElements")
	
	;If the element is a connection, call function to delete connection
	IfInString,p_elementID,connection
	{
		Connection_Remove(p_FlowID, p_elementID)
	}
	else
	{
		;remove the element from list of all elements
		_deleteElement(p_FlowID, forID)
		
		;~ ;If the element is marked, unmark it TODO
		;~ for forID, forElement in markedElements
		;~ {
			;~ if (forID=p_elementID)
			;~ {
				;~ UnmarkEverything(p_FlowID) ;Unmark all elements
				;~ break
			;~ }
		;~ }
		
		;remove the connections which end or start at the element ;TODO: if removing an element with only one connection from and one connection to the element, keep one connection
		allConnections:=_getFlowProperty(p_FlowID, "allConnections")
		for forElementID, forElement in allConnections
		{
			if ((forElement.from=p_elementID) or (forElement.to=p_elementID))
			{
				Connection_Remove(p_FlowID, forElementID)
			}
		}
	}
	
	LeaveCriticalSection(_cs_shared)
}




Connection_New(p_FlowID, p_elementID="")
{
	if not p_FlowID
	{
		MsgBox internal error! A new element should be created but FlowID is empty!
		return
	}

	EnterCriticalSection(_cs_shared) ; We get, change and store a flow in this function. keep this critical section to ensure data integrity
	
	tempElement:=Object()
	if (p_elementID="")
		tempElement.ID:="Connection" . format("{1:010u}",_getAndIncrementFlowProperty(p_FlowID,"ElementIDCounter")) 
	else
		tempElement.ID:=p_elementID
	
	tempElement.UniqueID:=p_FlowID "_" tempElement.ID
	
	tempElement.ConnectionType:="normal"
	tempElement.ClickPriority:=200
	
	tempElement.marked:=false
	tempElement.state:="idle"
	tempElement.type:="Connection"
	tempElement.frompart:=""
	tempElement.topart:=""
	
	_setConnection(p_FlowID, tempElement.ID, tempElement)
	
	LeaveCriticalSection(_cs_shared)
	return tempElement.ID
}


;Removes the connection. It will be deleted from list of all elements and all connections which start or ends there will be deleted, too
Connection_Remove(p_FlowID, p_elementID)
{
	if not p_FlowID
	{
		MsgBox internal error! A new element should be created but FlowID is empty!
		return
	}

	EnterCriticalSection(_cs_shared) ; We get, change and store a flow in this function. keep this critical section to ensure data integrity

	;remove the element from list of all connections
	_deleteConnection(p_FlowID, forID)
	
	;If the element is marked, unmark it TODO
	;~ for forID, forElement in markedElements
	;~ {
		;~ if (forID=p_elementID)
		;~ {
			;~ UnmarkEverything(p_FlowID) ;Unmark all elements
			;~ break
		;~ }
	;~ }
	
	;~ API_editor_CreateMarkedList(p_FlowID)
	LeaveCriticalSection(_cs_shared)
}


UpdateConnectionLists(p_FlowID)
{
	if not p_FlowID
	{
		MsgBox internal error! A new element should be created but FlowID is empty!
		return
	}

	EnterCriticalSection(_cs_shared) ; We get, change and store a flow in this function. keep this critical section to ensure data integrity
	
	allElements := _getFlowProperty(p_FlowID, "allElements")
	allConnections := _getFlowProperty(p_FlowID, "allConnections")
	for oneElementID, oneElement in allElements
	{
		oneElement.fromConnections := Object()
		oneElement.toConnections := Object()
	}
	for oneConnectionID, oneConnection in allConnections
	{
		allElements[oneConnection.from].fromConnections.push(oneConnectionID)
		allElements[oneConnection.to].toConnections.push(oneConnectionID)
	}

	_setFlowProperty(p_FlowID, "allElements", allElements)

	LeaveCriticalSection(_cs_shared)
}