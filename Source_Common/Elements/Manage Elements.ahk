
;Creates a new element and puts it in the array "allelements"
Element_New(p_FlowID, p_type="", p_elementID="")
{
	if not p_FlowID
	{
		; todo: make all such unexpected errors throw an exception.
		throw exception("internal error! A new element should be created but FlowID is empty", -1)
		return
	}

	_EnterCriticalSection() ; enter this critical section to ensure data integrity

	; create an empty element object
	newElement := Object()

	if (not p_elementID)
	{
		; element ID is empty, so we generate a new unique one
		newElement.ID := "element" . format("{1:010u}", _getAndIncrementFlowProperty(p_FlowID,"ElementIDCounter")) 
	}
	else
	{
		; element ID is set, we use it
		newElement.ID := p_elementID
	}

	; this ID is unique for all flows
	newElement.UniqueID := p_FlowID "_" newElement.ID

	; create empty object for parameters
	newElement.pars:=[]

	; set some default properties
	newElement.StandardName := True

	; set som initial info (which are not changed on undo/redo actions)
	newElement.info := Element_generateDefaultInfoObject()
	
	;Assign default position
	newElement.x := 0
	newElement.y := 0
	
	; write element object
	_setElement(p_FlowID, newElement.ID, newElement)

	; set element type, is parameter is passed
	if (p_type)
		Element_SetType(p_FlowID, newElement.ID, p_type)
	
	_LeaveCriticalSection()

	return newElement.ID
}

; Sets the element type.
; It might later be possible to change the element type (e.g. change from type "action" to type "condition")
Element_SetType(p_flowID, p_ElementID, p_elementType)
{
	if not p_ElementID
	{
		MsgBox internal error! A new element type should be set but ElementID is empty!
		return
	}

	_EnterCriticalSection() ; enter this critical section to ensure data integrity

	; set the element type
	_setElementProperty(p_FlowID, p_elementID, "type", p_elementType)
	;After changing the element type only, the class is unset 
	_setElementProperty(p_FlowID, p_elementID, "class", "")
	; since the class is not set, the name is unset too
	_setElementProperty(p_FlowID, p_elementID, "name", "") 

	; define default propoerties depending on the element type
	if (p_elementType = "Loop")
	{
		_setElementProperty(p_FlowID, p_elementID, "heightOfVerticalBar", 150) 
	}
	
	_LeaveCriticalSection()
}

;Sets the element class. With this it is possible to change the type and subtype in one step.
Element_SetClass(p_FlowID, p_ElementID, p_elementClass)
{
	if not p_ElementID
	{
		MsgBox internal error! A new element class should be set but ElementID is empty!
		return
	}

	if not isfunc("Element_getElementType_" p_elementClass)
	{
		MsgBox internal error! Function Element_getElementType_%p_elementClass% missing.
		return
	}

	_EnterCriticalSection() ; enter this critical section to ensure data integrity
	
	;Set element type if it has changed
	if (_getElementProperty(p_FlowID, p_elementID, "type") != Element_getElementType_%p_elementClass%())
	{
		Element_SetType(p_FlowID, p_elementID, Element_getElementType_%p_elementClass%())
	}
	
	;Set element class
	_setElementProperty(p_FlowID, p_elementID, "class", p_elementClass)
	_setElementProperty(p_FlowID, p_elementID, "icon", Element_getIconPath_%p_elementClass%())
	
	;Set new parameter Defaults
	Element_setParameterDefaults(p_FlowID, p_elementID)
	
	; update the name
	Element_updateName(p_FlowID, p_ElementID)
	
	;If element is of class trigger_manual: Set the trigger as default if no other is already default
	if (p_elementClass = "trigger_manual" and Element_findDefaultTrigger(p_FlowID) = "")
	{
		Element_setDefaultTrigger(p_FlowID, p_elementID)
	}

	_LeaveCriticalSection()
}

; update the name of an element
Element_updateName(p_FlowID, p_ElementID)
{
	_EnterCriticalSection() ; enter this critical section to ensure data integrity
	elementClass := _getElementProperty(p_FlowID, p_elementID, "class")

	; Set the default element name (if default name is enabled)
	if (_getElementProperty(p_FlowID, p_elementID, "StandardName"))
	{
		newName := Element_GenerateName_%elementClass%({flowID: p_FlowID, elementID: p_ElementID}, _getElementProperty(p_FlowID, p_ElementID, "pars"))
		_setElementProperty(p_FlowID, p_elementID, "name", newName)
	}
	_LeaveCriticalSection()
}

; Is called when the element class is set. All parameters that are not yet set will be set to the default values.
; We only write the unset parameters.
; After a change of element class, the unused parameters of the class will stay in the object, but they won't appear in the savefile and will get lost after a restart of AHF.
; This is a feature for following usecases:
; - User changes element class and both elements have similar parameters. Then the element parameters will be transferred to the new class.
;   For example: user wants two elements: "show window" and "hide window" and they should operate on same window.
;   So he configures the element "show window". Then he makes a copy of it and then changes class to "hide window".
;   Since the parameters are equal, he does not need to re-enter the parameters in the settings window.
; - User changes by mistake the element class which has different parameters.
;   He may now undo last change but he also may change the element class back and the old parameters will appear again.
Element_setParameterDefaults(p_FlowID, p_elementID)
{
	if not p_ElementID
	{
		MsgBox internal error! A element parameter defaults should be set but ElementID is empty!
		return
	}

	_EnterCriticalSection() ; enter this critical section to ensure data integrity

	; get parametration details
	elementClass := _getElementProperty(p_FlowID, p_elementID, "class")
	ParametrizationDetails := Element_getParametrizationDetails(elementClass, {flowID: p_FlowID, elementID: p_elementID}, true)
	
	; get alredy configured parameters (if available)
	ElementParsObject := _getElementProperty(p_FlowID, p_elementID, "pars")

	; loop through all parametration details and create a list of all parameters and their defauls
	parameters := []
	for index, oneParameter in ParametrizationDetails
	{
		; the value in key "ID" can either contain a single ID or an array of IDs. Convert single ID into an array for easy user later
		if (oneParameter.id)
		{
			if (not IsObject(oneParameter.id))
			{
				parameters.push({ID: oneParameter.id, Default: oneParameter.default, result: oneParameter.result, enum: oneParameter.enum, WarnIfEmpty: oneParameter.WarnIfEmpty})
			}
			else
			{
				for index, oneID in oneParameter.id
				{
					parameters.push({ID: oneID, Default: oneParameter.default[index], result: oneParameter.result, enum: oneParameter.enum, WarnIfEmpty: oneParameter.WarnIfEmpty})
				}
			}
		}

		; the value in key "ContentID" can only contain a single ID
		if (oneParameter.ContentID)
		{
			if (not IsObject(oneParameter.id))
			{
				parameters.push({ID: oneParameter.ContentID, Default: oneParameter.ContentDefault, result: "enum", enum: oneParameter.content, WarnIfEmpty: true})
			}
		}
	}
	
	; loop through all parameters
	for index, oneParameter in parameters
	{
		; write default parameter if it either doen't exist yet or if it is empty but must have a value.
		if ((not ElementParsObject.hasKey(oneParameter.ID)) or (oneParameter.WarnIfEmpty and ElementParsObject[oneParameter.ID] = ""))
		{
			ElementParsObject[oneParameter.ID] := oneParameter.Default
		}

		; check value of parameter which have an enum
		if (oneParameter.result = "enum")
		{
			if (not ObjHasValue(oneParameter.enum, ElementParsObject[oneParameter.ID]))
			{
				ElementParsObject[oneParameter.ID] := oneParameter.Default
			}
		}
	}

	; write parameter object
	_setElementProperty(p_FlowID, p_elementID, "pars", ElementParsObject)
	
	_LeaveCriticalSection()
}

; find the default manual trigger
Element_findDefaultTrigger(p_FlowID)
{
	if not p_FlowID
	{
		throw exception("internal error! Should find default trigger, but FlowID is empty", -1)
		return
	}
	
	; loop through all elements
	allElementsIDs := _getAllElementIds(p_FlowID)
	for oneID, oneElementID in allElementsIDs
	{
		; we only need manual trigger
		if (_getElementProperty(p_FlowID, oneElementID, "class") = "trigger_manual")
		{
			; is this the default trigger?
			if (_getElementProperty(p_FlowID, oneElementID, "defaultTrigger"))
			{
				; yes, return the ID
				return oneElementID
			}
		}
	}
	
	; we did not find a default manual trigger
	return 
}

; set default trigger
Element_setDefaultTrigger(p_FlowID, p_elementID)
{
	if not p_FlowID
	{
		throw exception("internal error! Should set default trigger, but FlowID is empty", -1)
		return
	}

	_EnterCriticalSection() ; enter this critical section to ensure data integrity

	; loop through all elements
	allElementsIDs := _getAllElementIds(p_FlowID)
	for oneID, oneElementID in allElementsIDs
	{
		; we only need manual trigger
		if (_getElementProperty(p_FlowID, oneElementID, "class") = "trigger_manual")
		{
			if (oneElementID = p_elementID )
			{
				; enable set the propert "defaultTrigger" for the defined trigger
				_setElementProperty(p_FlowID, oneElementID, "defaultTrigger", True)
			}
			else
			{
				; disable set the propert "defaultTrigger" for all other manual triggers
				_setElementProperty(p_FlowID, oneElementID, "defaultTrigger", false)
			}
		}
	}

	_LeaveCriticalSection()
}

; checks whether we have one or multiple manual triggers and a single manual trigger. If not, fix it.
Element_checkAndFixDefaultTrigger(p_FlowID)
{
	_EnterCriticalSection() ; enter this critical section to ensure data integrity

	defaultTrigger := ""
	anyManualTrigger := ""
	needToCallElement_setDefaultTrigger := ""

	; loop through all elements
	allElementsIDs := _getAllElementIds(p_FlowID)
	for oneID, oneElementID in allElementsIDs
	{
		; we only need manual trigger
		if (_getElementProperty(p_FlowID, oneElementID, "class") = "trigger_manual")
		{
			if (not anyManualTrigger)
			{
				; we found a manual trigger. Remember its ID
				anyManualTrigger := oneElementID
			}
			
			if (_getElementProperty(p_FlowID, oneElementID, "defaultTrigger"))
			{
				; we found a default trigger
				if (defaultTrigger)
				{
					; we found a second default trigger. We will call Element_setDefaultTrigger() and set the first found trigger as default
					needToCallElement_setDefaultTrigger := defaultTrigger
				}
				Else
				{
					; we faound a first default trigger. Remember its ID
					defaultTrigger := oneElementID
				}
			}
		}
	}
	if (anyManualTrigger and not defaultTrigger)
	{
		; there are manual triggers but none of them is default. We will set one of them as default.
		needToCallElement_setDefaultTrigger := anyManualTrigger
	}
	if (needToCallElement_setDefaultTrigger)
	{
		; we need to call Element_setDefaultTrigger() and set a trigger as default
		Element_setDefaultTrigger(p_FlowID, needToCallElement_setDefaultTrigger)
	}

	_LeaveCriticalSection()
}

;Removes the element or connection. It will be deleted from list of all elements and all connections which start or end there will be deleted, too
Element_Remove(p_FlowID, p_elementID)
{
	if not p_FlowID
	{
		throw exception("internal error! Should remove an element, but FlowID is empty", -1)
		return
	}

	_EnterCriticalSection() ; enter this critical section to ensure data integrity

	;If the element is a connection, call function to delete connection
	IfInString, p_elementID, connection
	{
		Connection_Remove(p_FlowID, p_elementID)
	}
	else
	{
		;remove the element from list of all elements
		_deleteElement(p_FlowID, p_elementID)
		
		;remove the connections which end or start at the element
		allConnectionIDs := _getAllConnectionIDs(p_FlowID)
		for oneID, oneConnectionID in allConnectionIDs
		{
			if ((_getConnectionProperty(p_FlowID, oneConnectionID, "from") = p_elementID) 
				or (_getConnectionProperty(p_FlowID, oneConnectionID, "to") = p_elementID))
			{
				Connection_Remove(p_FlowID, oneConnectionID)
			}
		}
	}

	; if we have deleted a default manual trigger, it needs to be fixed
	Element_checkAndFixDefaultTrigger(p_FlowID)
	
	_LeaveCriticalSection()
}

; returns a default info property of a new element
Element_generateDefaultInfoObject()
{
	info := object()
	info.enabled := False
	info.selected := false
	info.state := "idle"
	info.countRuns := 0
	info.lastrun := 0
	info.ClickPriority := 500
	return info
}

; create a new connection
Connection_New(p_FlowID, p_connectionID="")
{
	if not p_FlowID
	{
		MsgBox internal error! A new connection should be created but FlowID is empty!
		return
	}

	_EnterCriticalSection() ; enter this critical section to ensure data integrity
	
	; create an empty connection object
	newConnection := Object()
	
	if (not p_connectionID)
	{
		; connection ID is empty, so we generate a new unique one
		newConnection.ID := "connection" . format("{1:010u}", _getAndIncrementFlowProperty(p_FlowID,"ElementIDCounter")) 
	}
	else
	{
		; connection ID is set, we use it
		newConnection.ID := p_connectionID
	}
	
	; this ID is unique for all flows
	newConnection.UniqueID := p_FlowID "_" newConnection.ID
	
	; set some default properties
	newConnection.ConnectionType := "normal"
	
	newConnection.type := "Connection"
	newConnection.frompart := ""
	newConnection.topart := ""
	
	; set som initial info (which are not changed on undo/redo actions)
	newConnection.info := Connection_generateDefaultInfoObject()

	; write connection object
	_setConnection(p_FlowID, newConnection.ID, newConnection)

	_LeaveCriticalSection()
	return newConnection.ID
}


;Removes the connection.
Connection_Remove(p_FlowID, p_connectionID)
{
	if not p_FlowID
	{
		throw exception("internal error! Should remove a connection, but FlowID is empty", -1)
		return
	}

	_EnterCriticalSection() ; enter this critical section to ensure data integrity

	;remove the connection from list of all connections
	_deleteConnection(p_FlowID, p_connectionID)
	
	_LeaveCriticalSection()
}

; updates the list of connection from and to all elements.
; This increases performance during execution
UpdateConnectionLists(p_FlowID)
{
	if not p_FlowID
	{
		throw exception("internal error! Should update connection lists, but FlowID is empty", -1)
		return
	}

	_EnterCriticalSection() ; enter this critical section to ensure data integrity
	
	;Loop through all connections and create a list with all elements that have connections
	allConnectionIDs := _getAllConnectionIDs(p_FlowID)
	connectedElementsFrom := []
	connectedElementsTo := []
	for oneID, oneConnectionID in allConnectionIDs
	{
		oneFrom := _getConnectionProperty(p_FlowID, oneConnectionID, "from")
		if (not connectedElementsFrom[oneFrom])
		{
			connectedElementsFrom[oneFrom] := []
		}
		connectedElementsFrom[oneFrom].push(oneConnectionID)

		oneTo := _getConnectionProperty(p_FlowID, oneConnectionID, "to")
		if (not connectedElementsTo[oneTo])
		{
			connectedElementsTo[oneTo] := []
		}
		connectedElementsTo[oneTo].push(oneConnectionID)
	}

	; update the connection lists in the element objects
	allElementsIDs := _getAllElementIds(p_FlowID)
	for oneID, oneElementID in allElementsIDs
	{
		_setElementProperty(p_FlowID, oneElementID, "fromConnections", connectedElementsFrom[oneElementID])
		_setElementProperty(p_FlowID, oneElementID, "toConnections", connectedElementsTo[oneElementID])
	}

	_LeaveCriticalSection()
}

; returns a default info property of a new connection
Connection_generateDefaultInfoObject()
{
	info := object()
	info.selected := false
	info.state := "idle"
	info.ClickPriority := 500
	return info
}