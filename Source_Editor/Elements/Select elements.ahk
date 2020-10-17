;select an element or connection. If parameter additional is true, select it additionally to others
SelectOneItem(p_ID, additional := false)
{
	_EnterCriticalSection()
	
	if (not p_ID)
	{
		throw exception("Cannot select one item. p_ID is empty")
	}

	if (additional = false)
	{
		; unselect all elements. Do not call UpdateSelectedItemsList()
		UnSelectEverything(false)
		
		; Select one element
		if p_ID contains connection
		{
			_setConnectionProperty(FlowID, p_ID, "selected", true)
		}
		else
		{
			_setElementProperty(FlowID, p_ID, "selected", true)
		}
	}
	else ;if (additional=true)
	{
		; Select one element (additionally, unselect if selected)
		if p_ID contains connection
		{
			_setConnectionProperty(FlowID, p_ID, "selected", !_getConnectionProperty(FlowID, p_ID, "selected"))
		}
		else
		{
			_setElementProperty(FlowID, p_ID, "selected", !_getElementProperty(FlowID, p_ID, "selected"))
		}
	}
	
	UpdateSelectedItemsList()

	_LeaveCriticalSection()
}

;Unselect all elements and connections
UnSelectEverything(CreateList = true)
{
	_EnterCriticalSection()
	
	for forIndex, forElementID in _getAllElementIds(FlowID) 
	{
		_setElementProperty(FlowID, forElementID, "selected", false)
	}
	for forIndex, forConnectionID in _getAllConnectionIds(FlowID) ;Add all selected elements into array
	{
		_setConnectionProperty(FlowID, forConnectionID, "selected", false)
	}
	
	if (CreateList)
		UpdateSelectedItemsList()
	
	_LeaveCriticalSection()
}

; select all elements and connections
SelectEverything()
{
	_EnterCriticalSection()
	
	;Select all elements
	for forIndex, forElementID in _getAllElementIds(FlowID)
	{
		_setElementProperty(FlowID, forElementID, "selected", true)
	}
	;Select all connections
	for forIndex, forConnectionID in _getAllConnectionIds(FlowID)
	{
		_setConnectionProperty(FlowID, forConnectionID, "selected", false)
	}
	
	UpdateSelectedItemsList()

	_LeaveCriticalSection()
}

; loop through all elements and write all selected elements into the flow variable selectedElements
UpdateSelectedItemsList()
{
	_EnterCriticalSection()
	
	selectedElements := []

	;Add all selected elements into array
	for forIndex, forElementID in _getAllElementIds(FlowID) 
	{
		if (_getElementProperty(FlowID, forElementID, "selected"))
			selectedElements[forElementID] := forElementID
	}
	;Add all selected connections into array
	for forIndex, forConnectionID in _getAllConnectionIds(FlowID)
	{
		if (_getConnectionProperty(FlowID, forConnectionID, "selected"))
			selectedElements[forConnectionID] := forConnectionID
	}
	
	; do we have a single selected element?
	if (selectedElements.count() = 1)
	{
		; we have a single selected element. Write it into flow variable selectedElement
		_setFlowProperty(FlowID, "selectedElement", selectedElements[1])
	}
	else
	{
		; we have either none or multiple selected elements. Make variable selectedElement empty
		_setFlowProperty(FlowID, "selectedElement", "")
	}
	
	; set flow variable selectedElements
	_setFlowProperty(FlowID, "selectedElements", selectedElements)

	_LeaveCriticalSection()
}