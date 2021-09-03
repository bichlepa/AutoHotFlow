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
	for forIndex, forElementID in _getAllElementIds(_FlowID)
	{
		selected := _getElementInfo(_FlowID, forElementID, "selected")
		if (not selected) 
		{
			; Skip elements which are not selected
			continue
		}
		
		; copy the selected element to clipboard
		newClipboard.allElements[forElementID] := _getElement(_FlowID, forElementID)

		; clear info object
		newClipboard.allElements[forElementID].info.enabled := false
		newClipboard.allElements[forElementID].info.selected := false
		newClipboard.allElements[forElementID].info.state := "idle"
		newClipboard.allElements[forElementID].info.countRuns := 0
		newClipboard.allElements[forElementID].info.lastRun := 0
		newClipboard.allElements[forElementID].info.clickPriority := 0

		tempsaveCounter++
	}
	
	; loop through all connections
	for forIndex, forConnectionID in _getAllConnectionIds(_FlowID) 
	{
		; get some connection information
		from := _getConnectionProperty(_FlowID, forConnectionID, "from")
		to := _getConnectionProperty(_FlowID, forConnectionID, "to")
		fromselected := _getElementInfo(_FlowID, from, "selected")
		toselected := _getElementInfo(_FlowID, to, "selected")

		; A connection will be saved to clipboard if its connected elements are both selected
		if (not (fromselected and toselected))
		{
			continue
		}

		; both elements are selected. We will copy the connection to clipboard
		newClipboard.allConnections[forConnectionID] := _getConnection(_FlowID, forConnectionID)
		
		; clear info object
		newClipboard.allConnections[forConnectionID].info.selected := false
		newClipboard.allConnections[forConnectionID].info.state := "idle"
		newClipboard.allConnections[forConnectionID].info.clickPriority := 500
		
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
	winHWND := _getSharedProperty("hwnds.editGUI" _FlowID)
	MouseGetPos, TempMouseX, TempMouseY, tempWin, TempControl, 2
	If (tempWin = winHWND)
	{
		; mouse is hovering the editor. We will paste the elements under the mouse
		zoomFactor := _getFlowProperty(_FlowID, "flowSettings.zoomFactor") 
		offsetx := _getFlowProperty(_FlowID, "flowSettings.offsetx") 
		offsety := _getFlowProperty(_FlowID, "flowSettings.offsety") 
		tempPosUnderMouseX := (TempMouseX / zoomFactor) + offsetx
		tempPosUnderMouseY := (TempMouseY / zoomFactor) + offsety
	}
	else
	{
		; mouse is not hovering the editor. We will paste the elements in the middle of the editor
		visibleArea := _getFlowProperty(_FlowID, "DrawResult.visiblearea") 
		tempPosUnderMouseX := (visibleArea.x1 + visiblearea.w / 2)
		tempPosUnderMouseY := (visibleArea.y1 + visiblearea.h / 2)
	}
	
	
	; get elements from clipboard
	; we don't actually use clipboard. Instead use shared variable
	clipboardContent := _getShared("clipboard")	

	; we will write all pasted elements to this list which will help us to paste the connections later
	tempClipboardElementList := Object()

	; before pasting elements we need to know whether there is a default manual trigger
	defaultManualTrigger := Element_findDefaultTrigger(_FlowID)

	; paste all copied elements
	for loadElementID, loadElement in clipboardContent.allElements
	{
		tempCountLoadedElements++
		
		; Create new element. Do not pass Element ID, we want to get a new one
		NewElementID := element_New(_FlowID)

		; write all element properties to the new element
		_setElement(_FlowID, NewElementID, loadElement)

		; Restore the element ID, since we just overwrote it
		_setElementProperty(_FlowID, NewElementID, "id", NewElementID)
		
		;Save new element IDs in order to be able to assign the correct elements to the connections
		tempClipboardElementList[loadElementID] := NewElementID
		
		if (not tempOffsetX)
		{
			;On first iteration, calculate the difference between the position of copied element and the designated pasting position
			tempOffsetX := ui_FitGridX(tempPosUnderMouseX - loadElement.X - 0.5 * default_ElementWidth) 
			tempOffsetY := ui_FitGridY(tempPosUnderMouseY - loadElement.Y - 0.5 * default_ElementHeight)
		}
		;Correct the position. Each element should have the same relative position to each other as in the flow where they were copied from
		_setElementProperty(_FlowID, NewElementID, "x", ui_FitGridX(loadElement.X + tempOffsetX))
		_setElementProperty(_FlowID, NewElementID, "y", ui_FitGridY(loadElement.Y + tempOffsetY))

		; We have to make sure that if we have one or multiple manual triggers, there must always be one default manual trigger
		ElementClass := _getElementProperty(_FlowID, NewElementID, "class")
		if (ElementClass = "trigger_manual")
		{
			; we have pasted a manual trigger
			if (defaultManualTrigger)
			{
				; the flow already has a default manual trigger. we will call Element_setDefaultTrigger() later, which will remove the "defaultTrigger" flag from all pasted triggers.
				needSetDefaultTrigger := defaultManualTrigger
			}
			Else
			{
				; the flow has no manual trigger yet
				if (_getElementProperty(_FlowID, NewElementID, "defaultTrigger"))
				{
					; the pasted element has the flag "defaultTrigger". We will set it as default trigger.
					needSetDefaultTrigger := NewElementID
				}
				Else
				{
					; this may be the first manual trigger in the flow. Set it as default, if we do not paste any other manual trigger which has the "defaultTrigger" flag set
					if not (needSetDefaultTrigger)
						needSetDefaultTrigger := NewElementID
				}
			}
		}

		; select the pasted element
		_setElementInfo(_FlowID, NewElementID, "selected", false)
		SelectOneItem(NewElementID, true)
	}

	; set default manual trigger, if reuired
	if (needSetDefaultTrigger)
	{
		Element_setDefaultTrigger(_FlowID, needSetDefaultTrigger)
	}

	; paste all copied connections
	for loadElementID, loadElement in clipboardContent.allConnections
	{
		tempCountLoadedElements++
		
		; Create new element. Do not pass Element ID, we want to get a new one
		NewElementID := connection_new(_FlowID)

		; write all element properties to the new element
		_setConnection(_FlowID, NewElementID, loadElement)
		
		; Restore the element ID, since we just overwrote it
		_setConnectionProperty(_FlowID, NewElementID, "id", NewElementID)

		; Correct the element IDs in parameters "to" and "from"
		_setConnectionProperty(_FlowID, NewElementID, "to", tempClipboardElementList[loadElement.to])
		_setConnectionProperty(_FlowID, NewElementID, "from", tempClipboardElementList[loadElement.from])

		; select the pasted element
		_setConnectionInfo(_FlowID, NewElementID, "selected", false)
		SelectOneItem(NewElementID, true)
	}

	if (tempCountLoadedElements > 0)
	{
		; we pasted some elements.
		; Create a new state
		State_New(_FlowID)

		ToolTip(lang("Loaded %1% elements from clipboard", tempCountLoadedElements), 1000)
		logger("a2","Loaded " tempCountLoadedElements " elements from clipboard")
		
		; redraw
		API_Draw_Draw(_FlowID)
	}
	else
	{
		; we did not paste any elements
		ToolTip(lang("No elements found in clipboard"),1000)
		logger("a2","No elements found in clipboard")
	}
	
	_LeaveCriticalSection()
}

