; save all selected elements to clipboard.
SaveToClipboard()
{
	_EnterCriticalSection()
	
	logger("a2","Saving elements to clipboard")
	
	; create object where we will write the elements into
	newClipboard := Object()
	newClipboard.allElements := Object()
	newClipboard.allConnections := Object()
	
	; loop through all elements
	for forIndex, forElementID in _getAllElementIds(FlowID)
	{
		selected := _getElementInfo(FlowID, forElementID, "selected")
		if (not selected) 
		{
			; Skip elements which are not selected
			continue
		}
		
		; copy the selected element to clipboard
		newClipboard.allElements[forElementID] := _getElement(FlowID, forElementID)

		; clear info object
		newClipboard.allElements[forElementID].info := object()

		tempsaveCounter++
	}
	
	; loop through all connections
	for forIndex, forConnectionID in _getAllConnectionIds(FlowID) 
	{
		; get some connection information
		from := _getConnectionProperty(FlowID, forConnectionID, "from")
		to := _getConnectionProperty(FlowID, forConnectionID, "to")
		fromselected := _getElementInfo(FlowID, from, "selected")
		toselected := _getElementInfo(FlowID, to, "selected")

		; A connection will be saved to clipboard if its connected elements are both selected
		if (not (fromselected and toselected))
		{
			continue
		}

		; both elements are selected. We will copy the connection to clipboard
		newClipboard.allConnections[forConnectionID] := _getConnection(FlowID, forConnectionID)
		
		; clear info object
		newClipboard.allConnections[forConnectionID].info := object()
		
		tempsaveCounter++
	}
	
	if (tempsaveCounter > 0)
	{
		logger("a2", "Saved %1% elements to clipboard")
		ToolTip(lang("Saved %1% elements to clipboard", tempsaveCounter))
		toreturn := 0 ;No errors. The return value is needed if user presses Ctrl + x. Now all selected elements will be deleted
		
	}
	else
	{
		logger("a2", "No elements saved to clipboard")
		ToolTip(lang("No elements selected"))
		toreturn := -1
	}
	
	; write elements to clipboard
	; we don't actually use clipboard. Instead use shared variable
	_setShared("clipboard", newClipboard)
	
	_LeaveCriticalSection()
	return toreturn
}

; load elements from clipboard
loadFromClipboard()
{
	_EnterCriticalSection()
	
	logger("a2","Loading elements from clipboard")

	;Unselect all elements
	UnSelectEverything()
	
	;Find mouse position and find out whether the mouse is hovering the editor
	winHWND := _getSharedProperty("hwnds.editGUI" FlowID)
	MouseGetPos, TempMouseX, TempMouseY, tempWin, TempControl, 2
	If (tempWin = winHWND)
	{
		; mouse is hovering the editor. We will paste the elements under the mouse
		zoomFactor := _getFlowProperty(FlowID, "flowSettings.zoomFactor") 
		offsetx := _getFlowProperty(FlowID, "flowSettings.offsetx") 
		offsety := _getFlowProperty(FlowID, "flowSettings.offsety") 
		tempPosUnderMouseX := (TempMouseX / zoomFactor) + offsetx
		tempPosUnderMouseY := (TempMouseY / zoomFactor) + offsety
	}
	else
	{
		; mouse is not hovering the editor. We will paste the elements in the middle of the editor
		visibleArea := _getFlowProperty(FlowID, "DrawResult.visiblearea") 
		tempPosUnderMouseX := (visibleArea.x1 + visiblearea.w / 2)
		tempPosUnderMouseY := (visibleArea.y1 + visiblearea.h / 2)
	}
	
	
	; get elements from clipboard
	; we don't actually use clipboard. Instead use shared variable
	clipboardContent := _getShared("clipboard")	

	; we will write all pasted elements to this list which will help us to paste the connections later
	tempClipboardElementList := Object()

	; paste all copied elements
	for loadElementID, loadElement in clipboardContent.allElements
	{
		tempCountLoadedElements++
		
		; Create new element. Do not pass Element ID, we want to get a new one
		NewElementID := element_New(FlowID)

		; write all element properties to the new element
		_setElement(FlowID, NewElementID, loadElement)

		; Restore the element ID, since we just overwrote it
		_setElementProperty(FlowID, NewElementID, "id", NewElementID)
		
		;Save new element IDs in order to be able to assign the correct elements to the connections
		tempClipboardElementList[loadElementID] := NewElementID
		
		if (not tempOffsetX)
		{
			;On first iteration, calculate the difference between the position of copied element and the designated pasting position
			tempOffsetX := ui_FitGridX(tempPosUnderMouseX - loadElement.X - 0.5 * default_ElementWidth) 
			tempOffsetY := ui_FitGridY(tempPosUnderMouseY - loadElement.Y - 0.5 * default_ElementHeight)
		}
		;Correct the position. Each element should have the same relative position to each other as in the flow where they were copied from
		_setElementProperty(FlowID, NewElementID, "x", ui_FitGridX(loadElement.X + tempOffsetX))
		_setElementProperty(FlowID, NewElementID, "y", ui_FitGridY(loadElement.Y + tempOffsetY))

		; select the pasted element
		_setElementInfo(FlowID, NewElementID, "selected", false)
		SelectOneItem(NewElementID, true)
	}

	; paste all copied connections
	for loadElementID, loadElement in clipboardContent.allConnections
	{
		tempCountLoadedElements++
		
		; Create new element. Do not pass Element ID, we want to get a new one
		NewElementID := connection_new(FlowID)

		; write all element properties to the new element
		_setConnection(FlowID, NewElementID, loadElement)
		
		; Restore the element ID, since we just overwrote it
		_setConnectionProperty(FlowID, NewElementID, "id", NewElementID)

		; Correct the element IDs in parameters "to" and "from"
		_setConnectionProperty(FlowID, NewElementID, "to", tempClipboardElementList[loadElement.to])
		_setConnectionProperty(FlowID, NewElementID, "from", tempClipboardElementList[loadElement.from])

		; select the pasted element
		_setConnectionInfo(FlowID, NewElementID, "selected", false)
		SelectOneItem(NewElementID, true)
	}

	if (tempCountLoadedElements > 0)
	{
		; we pasted some elements.
		; Create a new state
		State_New(FlowID)

		ToolTip(lang("Loaded %1% elements from clipboard", tempCountLoadedElements), 1000)
		logger("a2","Loaded " tempCountLoadedElements " elements from clipboard")
		
		; redraw
		API_Draw_Draw(FlowID)
	}
	else
	{
		; we did not paste any elements
		ToolTip(lang("No elements found in clipboard"),1000)
		logger("a2","No elements found in clipboard")
	}
	
	_LeaveCriticalSection()
}

