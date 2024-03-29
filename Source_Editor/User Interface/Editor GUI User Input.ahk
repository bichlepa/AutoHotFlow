﻿; react on left mouse click
ui_leftmousebuttonclick()
{
	ui_mouseCick("left")
}
; react on right mouse click
ui_rightmousebuttonclick()
{
	ui_mouseCick("right")
}

; react on a mouse click
ui_mouseCick(button)
{
	global workingOnClick

	If global_CurrentlyMainGuiIsDisabled
	{
		; Prevent interaction with disable gui
		ui_ActionWhenMainGUIDisabled()
		logger("a3", button " mouse button click detected. Skipping. Main GUI is disabled.", _FlowID)
		return
	}

	if workingOnClick
	{
		; we are already busy with an other user action. Ignore this event
		logger("a3", button " mouse button click detected. Skipping. We are already processing a user input.", _FlowID)
	}
	else
	{
		if (button = "right")
		{
			; Scroll with using right mouse button
			logger("a3", button " mouse button click detected. Going to scroll with mouse.", _FlowID)
			ui_scrollwithMouse("rbutton")
		}
		else
		{
			; user clicked with the left mouse button
			; Go to label clickonpicture in order to react on user click.
			logger("a3", button " mouse button click detected. Going to process the click.", _FlowID)
			SetTimer, clickonpicture, -1 
		}
	}
}

; user did a double click with left mouse button
ui_leftmousebuttondoubleclick()
{
	if global_CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
	{
		ui_ActionWhenMainGUIDisabled()
		logger("a3", "left mouse button double click detected. Skipping. Main GUI is disabled.", _FlowID)
		return
	}
	logger("a3", "left mouse button double click detected. Going to process double click.", _FlowID)
	
	; track changes with those variables
	UserChangedSomething := false
	UserCancelledAction := false

	; get selected element
	selectedElement := _getFlowProperty(_FlowID, "selectedElement")
	if (selectedElement) ;if a single element is selected
	{
		if instr(selectedElement, "connection")
		{
			logger("a3", "a single selected connection found: " selectedElement ". Going to change chonnection type", _FlowID)

			 ;Change connection type and wait for results
			ret := ElementSettingsConnectionTypeSelector.open(selectedElement)
			if (ret = "aborted")
				UserCancelledAction := true
			else if (ret != "0 changes")
				UserChangedSomething := true
		}
		else
		{
			logger("a3", "a single selected element found: " selectedElement ". Going to edit element settings", _FlowID)

			;Change element settings and wait for results
			ret := ElementSettings.open(selectedElement)
			if (ret = "aborted")
				UserCancelledAction := true
			else if (ret != "0 changes")
				UserChangedSomething := true
		}

		; if something was changed, handle last steps
		endworkingOnClick(UserChangedSomething, UserCancelledAction)
	}
	Else
	{
		logger("a3", "no single selected connection or element found", _FlowID)
	}
}

 ;react on left mouse clicks of the user
clickOnPicture() ;react on clicks of the user
{
	global workingOnClick

	;Ignore if a click of user is already processed
	if (workingOnClick)
	{
		logger("a3", "do not process click on picture. We are already processing a user input.", _FlowID)
		return
	}
	
	; make sure, we only process one click of user
	workingOnClick := true
	
	;Get the mouse position
	MouseGetPos, mx, my

	;Find out whether user presses the control key
	GetKeyState, ControlKeyState, control

	; track changes with those variables
	UserChangedSomething := false
	UserCancelledAction := false

	; get selected elements
	selectedElement := _getFlowProperty(_FlowID, "selectedElement")
	selectedElements := _getFlowProperty(_FlowID, "selectedElements")

	; get element user clicked on
	clickedItem := ui_findElementUnderMouse(mx, my)
	clickedElement := clickedItem.element
	partOfclickedElement := clickedItem.part
	
	if (not clickedElement) ;If user clicke on empty space.
	{
		logger("a3", "user clicked on an empty space. Going to detect movement", _FlowID)

		; detect whether user drags with mouse
		if (ui_detectMovement()=false)
		{
			logger("a3", "no movement detected. control key state: " ControlKeyState, _FlowID)
			; user did not drag mouse.
			; if uses presses control key, do nothing
			if (ControlKeyState != "d")
			{
				logger("a3", "unselect elements", _FlowID)
				; Unselect all elements
				if (selectedElements.count())
				{
					UnSelectEverything()
					ui_UpdateStatusbartext()
				}
			}
		}
		else
		{
			logger("a3", "movement detected. Start scrolling", _FlowID)
			; user drags with mouse. Start scrolling
			ui_scrollwithMouse()
		}
	}
	else if (clickedElement = "MenuCreateNewAction" or clickedElement = "MenuCreateNewCondition" or clickedElement = "MenuCreateNewLoop" or clickedElement = "MenuCreateNewTrigger") ;User click either on "Create new action" or ".. condtion" in the drawn menu
	{
		logger("a3", "user clicked on the new element menu " clickedElement, _FlowID)

		; user clicked on the icon for creating a new element
		; create the new element
		if (clickedElement = "MenuCreateNewAction")
			newElement := Element_New(_FlowID, "action")
		else if (clickedElement = "MenuCreateNewCondition")
			newElement := Element_New(_FlowID, "Condition")
		else if (clickedElement = "MenuCreateNewLoop")
			newElement := Element_New(_FlowID, "Loop")
		else if (clickedElement = "MenuCreateNewTrigger")
			newElement := Element_New(_FlowID, "Trigger")
		else
		{
			throw exception("unexpected internal ERROR! A new element should be created. But I don't known which one!")
			return 
		}
		
		logger("a3", "new element created: " newElement, _FlowID)

		; place the element under the mouse cursor
		tempZoomFactor := _getFlowProperty(_FlowID, "flowSettings.zoomfactor")
		tempOffsetX := _getFlowProperty(_FlowID, "flowSettings.offsetx")
		tempOffsetY := _getFlowProperty(_FlowID, "flowSettings.offsety")
		_setElementProperty(_FlowID, newElement, "x", mx / tempZoomFactor + tempOffsetX - default_ElementWidth / 2)
		_setElementProperty(_FlowID, newElement, "y", my / tempZoomFactor + tempOffsetY - default_ElementHeight / 2)

		; select the element
		SelectOneItem(newElement)

		; user may hold mouse button down while dragging or klick, move and klick again
		if (ui_detectMovement()) ;If user moves the mouse while holding the mouse button
		{
			logger("a3", "user moved mouse right after creating the new element. Stop moving when user releases the mouse button", _FlowID)

			;move the element. Stop moving when user releases the mouse button
			ret := ui_moveSelectedElements(newElement)
		}
		else
		{
			logger("a3", "user released mouse button right after creating the new element. Stop moving when user presses the mouse button", _FlowID)

			;move the element. Stop moving when user clicks
			ret := ui_moveSelectedElements(newElement, , "InvertLbutton")
		}
		if (ret.Aborted) ;if user cancelled movement
		{
			logger("a3", "user cancelled movement", _FlowID)
			; this will undo the action later
			UserCancelledAction := true
		}
		else
		{
			logger("a3", "user finished movement. Going to select sub type of element", _FlowID)

			; select element subtype and wait for result
			ret := ElementSettingsElementClassSelector.open(newElement)
			if (ret = "aborted")
			{
				logger("a3", "user aborted element type selection", _FlowID)
				; this will undo the action later
				UserCancelledAction := true
			}
			else
			{
				logger("a3", "user finished element type selection. Going to open element settings", _FlowID)
				;open settings of element
				ret := ElementSettings.open(newElement)
				if (ret = "aborted")
				{
					logger("a3", "user aborted editing element settings", _FlowID)
					; this will undo the action later
					UserCancelledAction := true
				}
				else
				{
					logger("a3", "user finished editing element settings", _FlowID)
					; it doesnt matter, whether user did changes in the editor or not, since it is a new element
					UserChangedSomething := true
				}
			}
		}
	}
	else if (clickedElement = "PlusButton" or clickedElement = "PlusButton2") ;user click on plus button
	{
		logger("a3", "user clicked on a plus button: " clickedElement, _FlowID)

		IfInString, selectedElement, Connection ;The selected element is connection
		{
			logger("a3", "connection " selectedElement " is selected. Going to create a new connection and move them", _FlowID)

			;Create a new connection
			tempConnection2 := Connection_New(_FlowID)
			
			; get the elements where the connection starts and stops
			tempFrom := _getConnectionProperty(_FlowID, selectedElement, "from")
			tempTo := _getConnectionProperty(_FlowID, selectedElement, "to")

			;Create a new connection
			tempConnection2 := Connection_New(_FlowID)

			; move both connections
			ret := ui_MoveConnection(selectedElement, tempFrom, tempConnection2, tempTo)
			if (ret = "aborted")
			{
				logger("a3", "user aborted moving connections", _FlowID)
				; this will undo the action later
				UserCancelledAction := true
			}
			else
			{
				logger("a3", "user finished moving connections", _FlowID)
				UserChangedSomething := true
			} 
		}
		else ;The selected element is either action, condition or trigger or loop
		{
			logger("a3", "element " selectedElement " is selected. Going to create a new connection and move it", _FlowID)

			;Create new connection
			tempConnection1 := Connection_New(_FlowID)
			
			; check whether the selected element is a loop
			tempType := _getElementProperty(_FlowID, selectedElement, "type")
			if (tempType = "loop")
			{
				logger("a3", "selected element is a loop. Define frompart of connection", _FlowID)
				if (clickedElement = "PlusButton")
				{
					; User clicked the first plus button. The connections starts from the head of the loop
					_setConnectionProperty(_FlowID, tempConnection1, "frompart", "HEAD")
				}
				else if (clickedElement = "PlusButton2")
				{
					; User clicked the second plus button. The connections starts from the tail of the loop
					_setConnectionProperty(_FlowID, tempConnection1, "frompart", "TAIL")
				}
			}
			
			; move the connection
			ret := ui_MoveConnection(tempConnection1, selectedElement)
			if (ret = "aborted")
			{
				logger("a3", "user aborted moving connection", _FlowID)
				; this will undo the action later
				UserCancelledAction:=true
			}
			else
			{
				logger("a3", "user finished moving connection", _FlowID)
				UserChangedSomething:=true
			}
		}
	}
	else if (clickedElement = "MoveButton1") ;if a connection is selected and user wants to move the start of connection
	{
		logger("a3", "user clicked on the move button 1 of connection " selectedElement ". Going to move the start of the connection", _FlowID)
		
		; get the element at the end of the connection
		tempTo := _getConnectionProperty(_FlowID, selectedElement, "to")

		; move the connection
		ret := ui_MoveConnection(, , selectedElement, tempTo)
		if (ret = "aborted")
		{
			logger("a3", "user aborted moving connection", _FlowID)
			; this will undo the action later
			UserCancelledAction := true
		}
		else
		{
			logger("a3", "user finished moving connection", _FlowID)
			UserChangedSomething := true
		}
	}
	else if (clickedElement = "MoveButton2") ;if a connection is selected and user wants to move the end of connection
	{
		logger("a3", "user clicked on the move button 2 of connection " selectedElement ". Going to move the end of the connection", _FlowID)

		; get the element at the start of the connection
		tempFrom := _getConnectionProperty(_FlowID, selectedElement, "from")

		; move the connection
		ret := ui_MoveConnection(selectedElement, tempFrom)
		if (ret = "aborted")
		{
			logger("a3", "user aborted moving connection", _FlowID)
			; this will undo the action later
			UserCancelledAction := true
		}
		else
		{
			logger("a3", "user finished moving connection", _FlowID)
			UserChangedSomething := true
		}
	}
	else if (clickedElement = "TrashButton") ;if something is selected and user clicks on the trash button
	{

		; check whether the selected item is connection or element
		if instr(selectedElement, "connection")
		{
			; The item is a connection
			logger("a3", "user clicked on trash button of connection " selectedElement ". Going to delete it", _FlowID)

			; Confirm deletion
			tempType := _getConnectionProperty(_FlowID, selectedElement, "type")
			MsgBox, 4, % lang("Delete Object") , % lang("Do you really want to delete the %1%?", tempType, "`n")
		}
		else
		{
			; The item is an element
			logger("a3", "user clicked on trash button of element " selectedElement ". Going to delete it", _FlowID)
			
			; Confirm deletion
			tempType := _getElementProperty(_FlowID, selectedElement, "type")
			tempName := _getElementProperty(_FlowID, selectedElement, "name")
			MsgBox, 4, % lang("Delete Object") , % lang("Do you really want to delete the %1% '%2%'?",lang(tempType), "`n" tempName "`n")
		}
		
		IfMsgBox yes ; did user agree?
		{
			logger("a3", "user confirmed deletion of element or connection", _FlowID)

			; delete selected item
			Element_Remove(_FlowID, selectedElement)
			UserChangedSomething := true
		}
		Else
		{
			
			logger("a3", "user aborted deletion of element or connection", _FlowID)
		}
		
		; since we deleted the selected element, recreate the selected list
		UpdateSelectedItemsList()
	}
	else if (clickedElement="EditButton")  ;if something is selected and user clicks on the edit button
	{

		; check whether the selected item is connection or element
		if instr(selectedElement, "connection")
		{
			logger("a3", "user clicked on the edit button of connection " selectedElement ". Going to edit its type", _FlowID)

			; select connection type
			ret := ElementSettingsConnectionTypeSelector.open(selectedElement)
			if (ret = "aborted")
			{
				logger("a3", "user aborted changing connection type", _FlowID)
				; this will undo the action later
				UserCancelledAction := true
			}
			else
			{
				logger("a3", "user finished changing connection type", _FlowID)
				UserChangedSomething := true
			}
		}
		else
		{
			logger("a3", "user clicked on the edit button of element " selectedElement ". Going to edit its parameters", _FlowID)

			;open settings of the selected element
			ret := ElementSettings.open(selectedElement) 
			if (ret = "aborted")
			{
				logger("a3", "user aborted changing element parameters", _FlowID)
				; this will undo the action later
				UserCancelledAction:=true
			}
			else if (ret!="0 changes" )
			{
				logger("a3", "user finished changing element parameters", _FlowID)
				; user did some changes in the properties
				UserChangedSomething:=true
			}
		}
	}
	else if (clickedElement = "SwitchOnButton")  ;if a trigger is selected and user clicks on the switch on button
	{
		logger("a3", "user clicked on the switch on button of trigger " selectedElement ". Going to disable the trigger", _FlowID)

		; disable the trigger
		disableOneTrigger(_FlowID, selectedElement)
	}
	else if (clickedElement = "SwitchOffButton")  ;if a trigger is selected and user clicks on the switch off button
	{
		logger("a3", "user clicked on the switch off button of trigger " selectedElement ". Going to enable the trigger", _FlowID)

		; enable the trigger
		enableOneTrigger(_FlowID, selectedElement)
	}
	else if (clickedElement = "StarEmptyButton")  ;if a manual trigger is selected and user clicks on the empty star button
	{
		logger("a3", "user clicked on the empty star button of manual trigger " selectedElement ". Going to set this trigger as default", _FlowID)

		; Set this trigger as default
		Element_setDefaultTrigger(_FlowID, selectedElement)
		UserChangedSomething := true
	}
	else if (clickedElement = "StarFilledButton")  ;if a manual trigger is selected and user clicks on the filled start button
	{
		logger("a3", "user clicked on the filled star button of manual trigger " selectedElement ". Nothing to do", _FlowID)

		;Nothing to do, since a flow always must have a default trigger (if it has a manual trigger )
	}
	else if (clickedElement != "") ;if user clicked on an element
	{
		logger("a3", "user clicked on the element or connection " selectedElement ". Going to detect mouse movement", _FlowID)

		; check whether user moves the mouse
		if (!ui_detectMovement()) ;If user did not move the mouse
		{
			if (ControlKeyState = "d") ;if user presses Control key
			{
				logger("a3", "user did not move the mouse and holds the control key. Going to toggle select the item", _FlowID)
				; if user holds the control button
				; select or unselect the clicked item additionally
				SelectOneItem(clickedElement, true)
			}
			else
			{
				logger("a3", "user did not move the mouse and holds the control key. Going to select the item while unselecting others", _FlowID)
				; select the clicked item and unselect others
				SelectOneItem(clickedElement) ;select one element and unselect others
			}
		}
		else ;If user moves the mouse
		{
			if instr(selectedElement, "connection") ; do nothing if user drags a connection
			{
				logger("a3", "user started moving the mouse. He clicked on a connection. Nothing to do.", _FlowID)
			}
			Else
			{
				logger("a3", "user started moving the mouse. He clicked on an element. Going to move the element(s)", _FlowID)

				if (_getElementInfo(_FlowID, clickedElement, "selected")) ;If the element under the mouse is already selected
				{
					logger("a3", "Element is already selected. Move the selected elements", _FlowID)

					;move the selected elements
					ret := ui_moveSelectedElements(clickedElement, partOfclickedElement)
				}
				else if ((ControlKeyState != "d")) ;if clicked element is not selected and user does not press the control key
				{
					logger("a3", "Element is not selected and user does not hold the control key. Select it exclusively and move the selected element", _FlowID)

					; select the clicked item and unselect others
					SelectOneItem(clickedElement)
					;move the selected element
					ret := ui_moveSelectedElements(clickedElement, partOfclickedElement)
				}
				else ;if clicked element is not selected and user presses Control key
				{
					logger("a3", "Element is not selected and user holds the control key. Select it additionally and move the selected elements", _FlowID)

					; select the clicked item additionally
					SelectOneItem(clickedElement, true) 
					;move the selected elements
					ret := ui_moveSelectedElements(clickedElement, partOfclickedElement)
				}
				
				if (ret.aborted)
				{
					logger("a3", "user aborted moving the elements", _FlowID)
					; this will undo the action later
					UserCancelledAction := true
				}
				else if (ret.moved = true) ;if user actually moved the elements
				{
					logger("a3", "user finished moving the elements", _FlowID)
					UserChangedSomething := true
				}
			}
		}
		; update the satus bar text, which shows the selected element
		ui_UpdateStatusbartext()
	}

	; User finished the interaction.
	; do last needed tasks after that.
	endworkingOnClick(UserChangedSomething, UserCancelledAction)	
}

; Called when user finished an interaction with the gui
; If user made a change, we need to make a new state
; If user cancelled the action, we need to undo andy already made changes
endworkingOnClick(changedSomething, cancelled)
{
	global workingOnClick
	if (cancelled) ; user cancelled the action
	{
		logger("a2", "User cancelled an action, restore current state", _FlowID)
		; restore the current state and undo all eventual changes from user
		State_RestoreCurrent(_FlowID)
		UpdateSelectedItemsList()
	}
	else if (changedSomething) ; user change something
	{
		logger("a2", "User changed something, create a new state", _FlowID)

		;make a new state. If user presses Ctrl+Z, the change will be undone
		State_New(_FlowID)
	}

	; redraw the gui
	API_Draw_Draw(_FlowID) 

	; now we can handle a new interaction
	workingOnClick := false
	return
}

; find the element which is under the mouse. Called when user clicks on the picture
ui_findElementUnderMouse(mx, my, par_filter="", par_priority = "highest")
{
	global default_SizeOfButtons

	clickedElement:=""
	partOfclickedElement:=""
	elementBestPriority:=""
	selectedElementWithLowestPriority:=""
	selectedElementLowestPriority:=""

	; get the information about the locations of the elements in the picture
	drawResultFlow := _getFlowProperty(_FlowID, "DrawResult")

	; define what we search for
	mode_searchForButtons := true
	mode_searchForElements := true
	mode_searchForConnections := true
	if (par_filter = "OnlyElements")
	{
		mode_searchForButtons := false
		mode_searchForConnections := false
	}

	if (mode_searchForButtons)
	{
		;check whether user wants to create a new element (click on a field on top left corner)
		if ((0 < mx) and (0 < my) and ((drawResultFlow.NewElementIconWidth * 1.2)  > mx) and ((drawResultFlow.NewElementIconHeight * 1.2) > my))
			clickedElement := "MenuCreateNewAction"
		if (((drawResultFlow.NewElementIconWidth * 1.2) < mx) and (0 < my) and ((drawResultFlow.NewElementIconWidth * 1.2 * 2)  > mx) and ((drawResultFlow.NewElementIconHeight * 1.2) > my))
			clickedElement := "MenuCreateNewCondition"
		if (((drawResultFlow.NewElementIconWidth * 1.2 * 2) < mx) and (0 < my) and ((drawResultFlow.NewElementIconWidth * 1.2 * 3)  > mx) and ((drawResultFlow.NewElementIconHeight * 1.2) > my))
			clickedElement := "MenuCreateNewLoop"
		if (((drawResultFlow.NewElementIconWidth * 1.2 * 3) < mx) and (0 < my) and ((drawResultFlow.NewElementIconWidth * 1.2 * 4)  > mx) and ((drawResultFlow.NewElementIconHeight * 1.2) > my))
			clickedElement := "MenuCreateNewTrigger"
	

		;check whether user clicked a button near to the selected element
		if (drawResultFlow.PlusButtonExist and Sqrt((drawResultFlow.middlePointOfPlusButtonX - mx) * (drawResultFlow.middlePointOfPlusButtonX - mx) + (drawResultFlow.middlePointOfPlusButtonY - my) * (drawResultFlow.middlePointOfPlusButtonY - my)) < default_SizeOfButtons/2)
			clickedElement := "PlusButton"
		else if (drawResultFlow.PlusButton2Exist and Sqrt((drawResultFlow.middlePointOfPlusButton2X - mx) * (drawResultFlow.middlePointOfPlusButton2X - mx) + (drawResultFlow.middlePointOfPlusButton2Y - my) * (drawResultFlow.middlePointOfPlusButton2Y - my)) < default_SizeOfButtons/2)
			clickedElement := "PlusButton2"
		else if (drawResultFlow.EditButtonExist and Sqrt((drawResultFlow.middlePointOfEditButtonX  - mx) * (drawResultFlow.middlePointOfEditButtonX - mx) + (drawResultFlow.middlePointOfEditButtonY  - my) * (drawResultFlow.middlePointOfEditButtonY  - my)) < default_SizeOfButtons/2)
			clickedElement := "EditButton"
		else if (drawResultFlow.TrashButtonExist and Sqrt((drawResultFlow.middlePointOfTrashButtonX - mx) * (drawResultFlow.middlePointOfTrashButtonX - mx) + (drawResultFlow.middlePointOfTrashButtonY - my) * (drawResultFlow.middlePointOfTrashButtonY - my)) < default_SizeOfButtons/2)
			clickedElement := "TrashButton"
		else if (drawResultFlow.MoveButton2Exist and Sqrt((drawResultFlow.middlePointOfMoveButton2X - mx) * (drawResultFlow.middlePointOfMoveButton2X - mx) + (drawResultFlow.middlePointOfMoveButton2Y - my) * (drawResultFlow.middlePointOfMoveButton2Y - my)) < default_SizeOfButtons/2)
			clickedElement := "MoveButton2"
		else if (drawResultFlow.MoveButton1Exist and Sqrt((drawResultFlow.middlePointOfMoveButton1X - mx) * (drawResultFlow.middlePointOfMoveButton1X - mx) + (drawResultFlow.middlePointOfMoveButton1Y - my) * (drawResultFlow.middlePointOfMoveButton1Y - my)) < default_SizeOfButtons/2)
			clickedElement := "MoveButton1"		
		else if (drawResultFlow.SwitchOnButtonExist and (drawResultFlow.PosOfSwitchOnButtonX1 < mx) and (drawResultFlow.PosOfSwitchOnButtonX2 > mx) and (drawResultFlow.PosOfSwitchOnButtonY1 < my) and (drawResultFlow.PosOfSwitchOnButtonY2 > my) )
			clickedElement := "SwitchOnButton"	
		else if (drawResultFlow.SwitchOffButtonExist and (drawResultFlow.PosOfSwitchOffButtonX1 < mx) and (drawResultFlow.PosOfSwitchOffButtonX2 > mx) and (drawResultFlow.PosOfSwitchOffButtonY1 < my) and (drawResultFlow.PosOfSwitchOffButtonY2 > my) )
			clickedElement := "SwitchOffButton"		
		else if (drawResultFlow.StarFilledButtonExist and (drawResultFlow.PosOfStarFilledButtonX1 < mx) and (drawResultFlow.PosOfStarFilledButtonX2 > mx) and (drawResultFlow.PosOfStarFilledButtonY1 < my) and (drawResultFlow.PosOfStarFilledButtonY2 > my) )
			clickedElement := "StarFilledButton"	
		else if (drawResultFlow.StarEmptyButtonExist and (drawResultFlow.PosOfStarEmptyButtonX1 < mx) and (drawResultFlow.PosOfStarEmptyButtonX2 > mx) and (drawResultFlow.PosOfStarEmptyButtonY1 < my) and (drawResultFlow.PosOfStarEmptyButtonY2 > my) )
			clickedElement := "StarEmptyButton"
	}
	
	;nothing found yet, search for an element under the mouse cursor
	if (mode_searchForElements and not clickedElement)
	{
		;The highest priority decides which element will be selected.
		;The priority reduces a little bit when the element was selected, and increases every time the user clicks on it but something else is selected.
		;This way it is possible to click through the elements which overlap each other.
		elementBestPriority := par_priority = "highest" ? 0 : 1000000

		; loop though all elements
		for forElementIndex, forElementID in _getAllElementIds(_FlowID)
		{
			; get the position data of the element
			drawResultElement := drawResultFlow.elements[forElementID]
			; get additional data
			clickPriority := _getElementInfo(_FlowID, forElementID, "ClickPriority")
			if not clickPriority
				clickPriority := 500
			selected := _getElementInfo(_FlowID, forElementID, "selected")

			;Some elements consist of multiple parts, so we need to loop through all of them
			found := false
			Loop % drawResultElement.CountOfParts
			{
				; check position
				if (drawResultElement["part" a_index "x1"] < mx and drawResultElement["part" a_index "y1"] < my and drawResultElement["part" a_index "x2"] > mx and drawResultElement["part" a_index "y2"] > my)
				{
					; element is under the mouse cursor
					found := true
					foundPart := A_Index
				}
			}
			if (found) ; if this element is under the mouse cursor
			{
				;Check whether we already found an other element with higher priority
				if ((par_priority = "highest" and elementBestPriority < clickPriority) or (par_priority = "lowest" and elementBestPriority > clickPriority))
				{
					elementBestPriority := clickPriority
					partOfclickedElement := foundPart
					clickedElement := forElementID
				}
			}

			;Increase priority
			if (clickPriority < 500)
			{
				_getAndIncrementElementInfo(_FlowID, forElementID, "ClickPriority")
			}
		}
		
		; set the priority of the found element to a lower value
		if (clickedElement != "")
		{
			_setElementInfo(_FlowID, clickedElement, "ClickPriority", 490)
		}
	}
	
	
	;nothing found yet, search for a connection under the mouse cursor
	if (mode_searchForConnections and clickedElement="")
	{
		; Same as elements, we select the element with highest priority
		elementBestPriority := par_priority = "highest" ? 0 : 1000000
		
		; loop though all connections
		for forElementIndex, forElementID in _getAllConnectionIds(_FlowID)
		{
			; get the position data of the element
			drawResultElement:=drawResultFlow.elements[forElementID]

			; get additional data
			clickPriority := _getConnectionInfo(_FlowID, forElementID, "ClickPriority")
			if not clickPriority
				clickPriority := 500

			;Connections consist of multiple parts, so we need to loop through all of them
			found := false
			Loop % drawResultElement.CountOfParts
			{
				; check position
				if (drawResultElement["part" a_index "x1"] < mx and drawResultElement["part" a_index "y1"] < my and drawResultElement["part" a_index "x2"] > mx and drawResultElement["part" a_index "y2"] > my)
				{
					; connection is under the mouse cursor
					found := true
					foundPart := A_Index
				}
			}
			
			if (found) ; if this connection is under the mouse cursor
			{
				;Check whether we already found an other connection with higher priority
				if ((par_priority = "highest" and elementBestPriority < clickPriority) or (par_priority = "lowest" and elementBestPriority > clickPriority))
				{
					elementBestPriority := clickPriority
					partOfclickedElement := foundPart
					clickedElement := forElementID
				}
			}

			;Increase priority
			if (clickPriority < 200) ;Increase priority if connection has low priority. 
			{
				_getAndIncrementConnectionInfo(_FlowID, forElementID, "ClickPriority")
			}
		}
		
		; set the priority of the found connection to a lower value
		if (clickedElement)
		{
			_setConnectionInfo(_FlowID, clickedElement, "ClickPriority", 190)
		}

	}
	
	return {element: clickedElement, part: partOfclickedElement}
}

; move the selected elements
ui_moveSelectedElements(clickedElement, partOfclickedElement = "", option="")
{
	global default_Gridy

	; get some information about the location of the element
	oldposx := _getElementProperty(_FlowID, clickedElement, "x") ;Store the old position of the element
	firstposx := oldposx
	firstoffsetx := _getFlowProperty(_FlowID, "flowSettings.offsetx")
	firstmx := mx
	oldposy := _getElementProperty(_FlowID, clickedElement, "y") ;Store the old position of the element
	firstposy := oldposy
	firstoffsety := _getFlowProperty(_FlowID, "flowSettings.offsety")
	firstmy := my
	elementType := _getElementProperty(_FlowID, clickedElement, "type") 

	; get the initial mouse position
	MouseGetPos, firstmx, firstmy

	; create variables which will be returned
	moved:=false
	MovementAborted:=false
	
	; check whether we need to move the tail of a loop.
	; if the loop is the only selected element && this is a loop && user clicked on the tail (which is part 3 & 4)
	if (_getFlowProperty(_FlowID, "selectedElement") = clickedElement && elementType = "loop" && partOfclickedElement>=3)
	{
		; get old height of the vertical bar
		oldHeightOfVerticalBar := _getElementProperty(_FlowID, clickedElement, "HeightOfVerticalBar")
		
		Loop ;Move element(s)
		{
			; check whether user holds the left mouse button (or does not if inverted)
			lbuttonDown := getkeystate("lbutton")
			if (option != "InvertLbutton" and !lbuttonDown or option = "InvertLbutton" and lbuttonDown)
			{
				; user released the mouse button. We kan drop the elements now
				;Fit the element position to grid
				newHeightOfVerticalBar := _getElementProperty(_FlowID, clickedElement, "HeightOfVerticalBar")
				newHeightOfVerticalBar := ui_FitGridx(newHeightOfVerticalBar)
				_setElementProperty(_FlowID, clickedElement, "HeightOfVerticalBar", newHeightOfVerticalBar)
				
				; check whether the position has changed after all
				if (newHeightOfVerticalBar != oldHeightOfVerticalBar)
					moved := true
				
				; redraw the picture
				API_Draw_Draw(_FlowID)
			
				break
			}
			; check whether user holds escape button to cancel the movement
			if (getkeystate("esc"))
			{
				; set the return value, which should trigger an undo later
				moved := false
				MovementAborted := true
				break
			}
			; check whether user holds the right button to either cancel the movement or to scroll
			if (getkeystate("rbutton")) ;If user cancels movement, move back
			{
				if (ui_detectMovement(,"rbutton"))
				{
					; user drags with the right mouse button. We will scroll
					ui_scrollwithMouse("rbutton")
				}
				else
				{
					; user did not drag. We will cancel movement
					; set the return value, which should trigger an undo later
					moved := false
					MovementAborted := true
					break
				}
			}
			
			;get mouse position and calculate the new position of the element
			MouseGetPos, newmx, newmy
			if (newmx != oldposx OR newmy != oldposy) ;If mouse position has changed
			{
				; keep old mouse position in mind
				oldposx := newmx
				oldposy := newmy

				; get zoom factor and offset (user can change that while he is moving the elements)
				zoomfactor := _getFlowProperty(_FlowID, "flowSettings.zoomfactor")
				offsety := _getFlowProperty(_FlowID, "flowSettings.offsety")
				
				; calculate the new height of the vertical bar
				newHeightOfVerticalBar := (oldHeightOfVerticalBar + (newmy - firstmy) / zoomfactor) - firstoffsety + offsety
				if (newHeightOfVerticalBar < default_Gridy*2)
					newHeightOfVerticalBar := default_Gridy*2

				; write the new height
				_setElementProperty(_FlowID, clickedElement, "HeightOfVerticalBar", newHeightOfVerticalBar)
				
				; redraw
				API_Draw_Draw(_FlowID)
			}
			else ;If mouse is currently not moving
			{
				sleep,10 ;Save processor load
			}
			
		}
		
	}
	else ; we do not move a loop tail, so we move the elements normally
	{
		; get all selected elements
		selectedElements := _getFlowProperty(_FlowID, "selectedElements")

		; save the old positions of all elements
		oldElementsPos := object()
		for forIndex, forElementID in selectedElements  ;Preparing to move
		{
			oldElementsPos[forElementID] := Object()
			oldElementsPos[forElementID].x := _getElementProperty(_FlowID, forElementID, "x")
			oldElementsPos[forElementID].y := _getElementProperty(_FlowID, forElementID, "y")
		}

		Loop ;Move element(s)
		{
			; check whether user holds the left mouse button (or does not if inverted)
			lbuttonDown := getkeystate("lbutton")
			if (option != "InvertLbutton" and !lbuttonDown or option = "InvertLbutton" and lbuttonDown)
			{
				; user released the mouse button. We kan drop the elements now
				;loop through all selected elements
				for forIndex, forElementID in selectedElements
				{
					;Fit the element position to grid
					newposx := ui_FitGridX(_getElementProperty(_FlowID, forElementID, "x"))
					newposy := ui_FitGridY(_getElementProperty(_FlowID, forElementID, "y"))
					_setElementProperty(_FlowID, forElementID, "x", newposx)
					_setElementProperty(_FlowID, forElementID, "y", newposy)
					
					; check whether the position has changed after all
					if (oldElementsPos[forElementID].x != newposx or oldElementsPos[forElementID].y != newposy)
						moved := true
				}
				
				; redraw the picture
				API_Draw_Draw(_FlowID)
				
				break
			}
			
			; check whether user holds escape button to cancel the movement
			if (getkeystate("esc"))
			{
				; set the return value, which should trigger an undo later
				moved := false
				MovementAborted := true
				break
			}
			; check whether user holds the right button to either cancel the movement or to scroll
			if (getkeystate("rbutton")) ;If user cancels movement, move back
			{
				if (ui_detectMovement(,"rbutton"))
				{
					; user drags with the right mouse button. We will scroll
					ui_scrollwithMouse("rbutton")
				}
				else
				{
					; user did not drag. We will cancel movement
					; set the return value, which should trigger an undo later
					moved := false
					MovementAborted := true
					break
				}
			}
			
			;get mouse position and calculate the new position of the element
			MouseGetPos, newmx, newmy ;get mouse position and calculate the new position of the element
			if (newmx != oldposx OR newmy != oldposy) ;If mouse is currently moving
			{
				; keep old mouse position in mind
				oldposx:=newmx
				oldposy:=newmy
				
				; get zoom factor and offset (user can change that while he is moving the elements)
				zoomfactor := _getFlowProperty(_FlowID, "flowSettings.zoomfactor")
				offsetx := _getFlowProperty(_FlowID, "flowSettings.offsetx")
				offsety := _getFlowProperty(_FlowID, "flowSettings.offsety")
				;loop through all selected elements to move them all
				for forIndex, forElementID in selectedElements
				{
					; calculate the new position of the element
					newposx := (oldElementsPos[forElementID].x + (newmx - firstmx) / zoomfactor) - firstoffsetx + offsetx
					newposy := (oldElementsPos[forElementID].y + (newmy - firstmy) / zoomfactor) - firstoffsety + offsety
					
					; write the new position of the element
					_setElementProperty(_FlowID, forElementID, "x", newposx)
					_setElementProperty(_FlowID, forElementID, "y", newposy)
				}

				; redraw
				API_Draw_Draw(_FlowID)
			}
			else ;If mouse is not currently moving
			{
				sleep,10 ;Save processor load
			}
		}
		
	}
	return {moved:moved, Aborted: MovementAborted}
}

; detects whether user moves the mouse.
; it returns when user either moves the mouse or releases the button
; the threshold defines how many times a change of the mouse position needs to be detected until it returns (it's not the distance)
ui_detectMovement(threshold=2, button="lbutton")
{
	howMuchMoved := 0

	;get intial mouse position
	MouseGetPos,xold,yold

	;check mouse position all the time
	Loop 
	{
		; check whether user still holds the mouse
		if (not getkeystate(button))
		{
			; user released the mouse, so no movement detected
			return false
		}

		;get mouse position
		MouseGetPos,xnew,ynew 
		
		; check whether mouse has moved
		if (xnew!=xold OR yold!=ynew) 
		{
			; mouse has moved, update old mouse position
			yold:=ynew
			xold:=xnew
			
			; increase and compare counter
			howMuchMoved++
			if (howMuchMoved >= threshold)
			{
				; counter has been reached. User moves the mouse
				return true
			}
		}
		
		sleep,10 ;Save processor load
	}
}

ui_detectMovementWithoutBlocking(threshold=1)
{
	static yold =0
	static xold =0

	MouseGetPos,xnew,ynew ;get mouse position and calculate the new position of the element
	
	if (xnew!=xold OR yold!=ynew) ;If mouse is currently moving
	{
		yold:=ynew
		xold:=xnew
		
		howMuchMoved++
		if (howMuchMoved>=threshold)
		{
			
			return true
		}
	}
	
	sleep,10 ;Save processor load

	return false ;When it did't nome return noMov
	
}

; scroll the screen with the mouse
ui_scrollwithMouse(ScrollButton="lbutton")
{
	;Store the first offset position
	zoomfactor := _getFlowProperty(_FlowID, "flowSettings.zoomfactor")
	firstOffsetx := _getFlowProperty(_FlowID, "flowSettings.offsetx")
	firstOffsety := _getFlowProperty(_FlowID, "flowSettings.offsety")
	
	;Get the initial mouse position
	MouseGetPos, firstmx, firstmy

	somethingScrolled := false
	
	loop
	{
		; check whether user released the button
		if (not getkeystate(ScrollButton))
		{
			; user released the button. Stop scrolling
			; redraw and update status bar
			ui_UpdateStatusbartext("pos")
			API_Draw_Draw(_FlowID)
			break
		}
		
		;Get mouse position and calculate
		MouseGetPos,newmx,newmy

		; calculate the new offsets
		newOffsetx := (firstOffsetx - (newmx - firstmx) / zoomfactor)
		newOffsety := (firstOffsety - (newmy - firstmy) / zoomfactor)
		
		if (newposx != oldOffsetx OR newOffsety != oldOffsety) ;If mouse is moving currently
		{
			; keep the new offset in mind
			oldOffsetx := newOffsetx
			oldOffsety := newOffsety

			; write the new offset
			_setFlowProperty(_FlowID, "flowSettings.Offsetx", newOffsetx)
			_setFlowProperty(_FlowID, "flowSettings.Offsety", newOffsety)
			
			; redraw and update status bar
			ui_UpdateStatusbartext("pos")
			API_Draw_Draw(_FlowID)

			somethingScrolled := true
		}
		sleep,10 ;Save processor load
	}
	
	return somethingScrolled
}


; Lets the user move one or multiple connections.
; The user can move it either to an other element or to an empty space, which will create a new element
; Return value: "aborted" if user cancelled action
; any of the parameters can be empty, but not all at once. Following combinations are possible:
; connection1 & element1 given: move the end of the connection
; connection2 & element2 given: move the start of the connection
; all parameters given: move the end of the first conncection and the start of the second connection.
;   It is used to split an existing connection. The connection which is going to be split must be connection1 and the new one connection2.
ui_MoveConnection(connection1 = "", element1 = "", connection2 = "", element2 = "")
{
	global default_ElementWidth, default_ElementHeight

	; unselect everything and select the defined connections
	UnSelectEverything()
	if (connection1)
		SelectOneItem(connection1)
	if (connection2)
		SelectOneItem(connection2, true)
	
	; if connection 1 is defined
	if (connection1)
	{
		;The end of the connection should follow the mouse
		_setConnectionProperty(_FlowID, connection1, "to", "MOUSE")
		; Start the connection from element1 (needed if this is a new connection)
		_setConnectionProperty(_FlowID, connection1, "from", element1)
	}
	
	; if connection 2 is defined
	if (connection2)
	{
		;The start of the connection should follow the mouse
		_setConnectionProperty(_FlowID, connection2, "from", "MOUSE")
		; End the connection to element2 (needed if this is a new connection or if a connection was split)
		_setConnectionProperty(_FlowID, connection2, "to", element2)
	}
	
	; If both connections defined, a connection was split
	if (connection1 and connection2)
	{
		; since connection1 is the old connection, connection2 has now to end, where connection1 has ended before.
		connection1toPart := _getConnectionProperty(_FlowID, connection1, "toPart")
		_setConnectionProperty(_FlowID, connection2, "toPart", connection1toPart)
		; delete the part information from connection 1
		_deleteConnectionProperty(_FlowID, connection1, "toPart")
	}
	
	; we want to draw a plus icon under the mouse to hide the lose ends of the connections
	_setFlowProperty(_FlowID, "draw.DrawMoveButtonUnderMouse", true)
	
	; check whether user moves the mouse
	if (ui_detectMovement()) ;If user moves the mouse
		untilRelease:=true ;move until user releases mouse
	else
		untilRelease:=false ;move untli user clicks

	Loop ;Move connection(s)
	{
		; check whether user holds the left mouse button (or does not if inverted)
		lbuttonDown := getkeystate("lbutton")
		if (untilRelease and !lbuttonDown or not untilRelease and lbuttonDown)
		{
			; user released the mouse button. We kan drop the connections now
			
			; we will handle everything after the end of the loop
			break
		}
		
		; check whether user holds escape button to cancel the movement
		if (getkeystate("esc"))
		{
			; set the return value, which should trigger an undo later
			moved := false
			MovementAborted := true
			break
		}
		; check whether user holds the right button to either cancel the movement or to scroll
		if (getkeystate("rbutton")) ;If user cancels movement, move back
		{
			if (ui_detectMovement(,"rbutton"))
			{
				; user drags with the right mouse button. We will scroll
				ui_scrollwithMouse("rbutton")
			}
			else
			{
				; user did not drag. We will cancel movement
				; set the return value, which should trigger an undo later
				moved := false
				MovementAborted := true
				break
			}
		}
		
		;get mouse position
		MouseGetPos, mx, my
		if (mx != oldposx OR my != oldposy) ;If mouse is currently moving
		{
			; keep old mouse position in mind
			oldposx:=mx
			oldposy:=my
			
			; redraw
			API_Draw_Draw(_FlowID)
		}
		else ;If mouse is not currently moving
		{
			sleep,10 ;Save processor load
		}
	}

	
	; we can stop to draw the move button now
	_setFlowProperty(_FlowID, "draw.DrawMoveButtonUnderMouse", false)
	
	if (MovementAborted)
	{
		; since user cancelled the movement, we can return now
		return "aborted"
	}
	
	;Search for an element under the mouse cursor. Do not get one from the background
	clickedItem := ui_findElementUnderMouse(mx, my, "OnlyElements", "lowest")
	clickedElement := clickedItem.element
	clickedElementPart := clickedItem.part
	
	; did user move the connection to an element?
	if (not clickedElement) 
	{
		;User pulled the end of the connection to empty space. Create new element

		; create new element
		clickedElement := Element_New(_FlowID)
		newElementCreated := true
		
		; set user choose element type
		ret := ElementSettingsContainerTypeSelector.open(clickedElement)
		if (ret = "aborted")
		{
			; user cancelled
			return "aborted"
		}

		; calculate and set the position of the new element
		zoomfactor := _getFlowProperty(_FlowID, "flowSettings.zoomfactor")
		offsetx := _getFlowProperty(_FlowID, "flowSettings.offsetx")
		offsety := _getFlowProperty(_FlowID, "flowSettings.offsety")

		tempx := (mx) / zoomfactor + Offsetx - default_ElementWidth / 2
		tempy := (my) / zoomfactor + offsety  - default_ElementHeight / 2
		tempx := ui_FitGridX(tempx)
		tempy := ui_FitGridY(tempy)
		_setElementProperty(_FlowID, clickedElement, "x", tempx)
		_setElementProperty(_FlowID, clickedElement, "y", tempy)
		
		if (connection1)
		{
			; the first connection (if any) will end at the new element
			connection1To := clickedElement
			_setConnectionProperty(_FlowID, connection1, "to", clickedElement)
		}
		
		if (connection2)
		{
			; the second connection (if any) will start at the new element
			connection2From := clickedElement
			_setConnectionProperty(_FlowID, connection2, "from", clickedElement)
		}
		
		; let user define other propierties of the connections, if needed
		gosub, ui_MoveConnectionCheckAndCorrect
		if MovementAborted
		{
			; user cancelled
			return "aborted"
		}
		
		; select the new element
		SelectOneItem(clickedElement)
		
		; since we have a new element, user can now edit its settings
		; select subtype
		ret := ElementSettingsElementClassSelector.open(clickedElement)
		if (ret = "aborted") ;If user aborted
		{
			; user cancelled
			return "aborted"
		}
		
		;open settings of element
		ret := ElementSettings.open(clickedElement)
		if (ret = "aborted") ;If user aborted
		{
			; user cancelled
			return "aborted"
		}
		
	}
	else ;If user pulled the end of the connection to an existing element
	{
		; we didn't create a new element (we need this information later)
		newElementCreated := false
		
		if (connection1 != "")
		{
			; the first connection (if any) will end at the clicked element
			connection1To := clickedElement
			_setConnectionProperty(_FlowID, connection1, "to", clickedElement)
		}
		
		if (connection2 != "")
		{
			; the second connection (if any) will start at the clicked element
			connection2From := clickedElement
			_setConnectionProperty(_FlowID, connection2, "from", clickedElement)
		}

		;Check whether Connection is possible
		elementType := _getElementProperty(_FlowID, clickedElement, "Type")
		if (elementType = "Trigger" && connection1)
		{
			; user dragged the end of connection1 to a trigger
			Msgbox,% lang("You_cannot_connect_to_trigger!")
			return "aborted"
		}
		if (clickedElement = Element1 OR clickedElement = Element2)
		{
			; user created a loop with only one element within it
			Msgbox,% lang("The_connection_cannot_start_and_end_on_the_same_element!")
			return "aborted"
		}
		
		; let user define other propierties of the connections, if needed
		gosub, ui_MoveConnectionCheckAndCorrect
		if MovementAborted
		{
			; user cancelled
			return "aborted"
		}
		
		if (Connection1!="" and Connection2!="") 
		{
			;if user has split a connection and moved it to an existing element
			; select the element
			SelectOneItem(clickedElement)
		}
		;else keep the new or modified connection selected
		
	}

	; redraw
	API_Draw_Draw(_FlowID)
	return
	
	; let user define other propierties of the connections, if needed
	ui_MoveConnectionCheckAndCorrect:
	
		
	; Check whether connection 1 ends at a loop or connection 2 starts at a loop
	elementType := _getElementProperty(_FlowID, clickedElement, "Type")
	if (elementType = "Loop") ;If user pulled to a loop, assign parts
	{
		if newElementCreated
		{
			 ;If a new connection was created, define default parts
			_setConnectionProperty(_FlowID, connection1, "toPart", "HEAD")
			_setConnectionProperty(_FlowID, connection2, "fromPart", "TAIL")
		}
		else ;If user has pulled to an existing loop, decide depending on which part he dropped it
		{
			if (Connection1!="" and Connection2!="")
			{
				;both connections is defined. assign default parts
				_setConnectionProperty(_FlowID, connection1, "toPart", "HEAD")
				_setConnectionProperty(_FlowID, connection2, "fromPart", "TAIL")
			}
			else
			{
				; only one connection is defined
				if (clickedElementPart=1 or clickedElementPart=2) ; head or side part of the loop
				{
					; set the start or end of the connection to head
					_setConnectionProperty(_FlowID, connection1, "toPart", "HEAD")
					_setConnectionProperty(_FlowID, connection2, "fromPart", "HEAD")
				}
				else if (clickedElementPart=3) ; tail of the loop
				{
					; set the start or end of the connection to tail
					_setConnectionProperty(_FlowID, connection1, "toPart", "TAIL")
					_setConnectionProperty(_FlowID, connection2, "fromPart", "TAIL")
				}
				else if (clickedElementPart=4) ; the break field in the tail of the loop
				{
					; set the end of the connection1 (if any) to break
					; since connection2 (if any) can't start from break, assign it to tail
					_setConnectionProperty(_FlowID, connection1, "toPart", "BREAK" )
					_setConnectionProperty(_FlowID, connection2, "fromPart", "TAIL")
				}
			}
		}
	}
	else ;if user did not pull to the loop, delete part informations
	{
		_deleteConnectionProperty(_FlowID, Connection1, "toPart")
		_deleteConnectionProperty(_FlowID, Connection2, "fromPart")
	}

	if (Connection1 != "") ;If connection 1 exists
	{
		; get some information
		connection1From := _getConnectionProperty(_FlowID, Connection1, "from")
		elementType := _getElementProperty(_FlowID, connection1From, "Type")
		connectionType := _getConnectionProperty(_FlowID, connection1, "connectiontype")

		if (elementType = "Condition" )
		{
			;if pulled to condition, check whether the connection type is suitable
			if (connectionType != "exception" 
				and connectionType != "no" 
				and connectionType != "yes") 
			{
				; the connection type is not suitable. let user select a new one
				ret := ElementSettingsConnectionTypeSelector.open(Connection1)
				if (ret = "aborted")
				{
					; user cancelled
					MovementAborted := True
					return ; back to the gosub call
				}
			}
		}
		else 
		{
			;if pulled to anything else, check whether it is normal or exception
			if (connectionType != "normal" and connectionType != "exception")
			{
				; set connection type to normal silently
				_setConnectionProperty(_FlowID, connection1, "connectiontype", "normal")
			}
		}
	}
	
	if (Connection2 != "") ;If connection 2 exists
	{
		; get some information
		elementType := _getElementProperty(_FlowID, connection2From, "Type")
		connectionType := _getConnectionProperty(_FlowID, connection2, "connectiontype")

		if (elementType = "Condition")
		{
			;if pulled to condition, check whether the connection type is suitable
			if (connectionType != "exception" 
				and connectionType != "no" 
				and connectionType != "yes")
			{
				; the connection type is not suitable. let user select a new one
				ret:=ElementSettingsConnectionTypeSelector.open(Connection2)
				if (ret = "aborted")
				{
					; user cancelled
					MovementAborted := True
					return ; back to the gosub call
				}
			}
		}
		else
		{
			;if pulled to anything else, check whether it is normal or exception
			if (connectionType != "normal" and connectionType != "exception")
			{
				; set connection type to normal silently
				_setConnectionProperty(_FlowID, connection2, "connectiontype", "normal")
			}
		}
	}

	;Check whether user created an already existing connection
	; gather informations
	Connection1Type := _getConnectionProperty(_FlowID, Connection1, "ConnectionType")
	Connection2Type := _getConnectionProperty(_FlowID, Connection2, "ConnectionType")
	Connection1From := _getConnectionProperty(_FlowID, Connection1, "from")
	Connection2From := _getConnectionProperty(_FlowID, Connection2, "from")
	Connection1To := _getConnectionProperty(_FlowID, Connection1, "to")
	Connection2To := _getConnectionProperty(_FlowID, Connection2, "to")
	Connection1FromPart := _getConnectionProperty(_FlowID, Connection1, "fromPart")
	Connection2FromPart := _getConnectionProperty(_FlowID, Connection2, "fromPart")
	Connection1ToPart := _getConnectionProperty(_FlowID, Connection1, "toPart")
	Connection2ToPart := _getConnectionProperty(_FlowID, Connection2, "toPart")

	for forIndex, forConnectionID in _getAllConnectionIds(_FlowID)
	{
		forConnectionFrom := _getConnectionProperty(_FlowID, forConnectionID, "from")
		forConnectionTo := _getConnectionProperty(_FlowID, forConnectionID, "to")

		if (forConnectionID != Connection1)
		{
			if (Connection1From = forConnectionFrom and Connection1To = forConnectionTo)
			{
				forConnectionType := _getConnectionProperty(_FlowID, forConnectionID, "ConnectionType")

				if (Connection1Type = forConnectionType)
				{
					forConnectionFromPart := _getConnectionProperty(_FlowID, forConnectionID, "fromPart")
					forConnectionToPart := _getConnectionProperty(_FlowID, forConnectionID, "toPart")
					if (Connection1FromPart = forConnectionFromPart and Connection1ToPart = forConnectionToPart)
					{
						msgbox,% lang("This_connection_already_exists!")
						MovementAborted:=true
						return ; back to the gosub call
					}
				}
			}
		}
		if (forConnectionID != Connection2)
		{
			if (Connection2From = forConnectionFrom and Connection2To = forConnectionTo )
			{
				forConnectionType := _getConnectionProperty(_FlowID, forConnectionID, "ConnectionType")

				if (Connection2Type = forConnectionType)
				{
					forConnectionFromPart := _getConnectionProperty(_FlowID, forConnectionID, "fromPart")
					forConnectionToPart := _getConnectionProperty(_FlowID, forConnectionID, "toPart")
					if (Connection1FromPart = forConnectionFromPart and Connection1ToPart = forConnectionToPart)
					{
						msgbox,% lang("This_connection_already_exists!")
						MovementAborted:=true
						return ; back to the gosub call
					}
				}
			}
		}
	}
		
	return ; back to the gosub call
}

; when user pressed "delete", delete selected element
key_del()
{
	;remove all selected elements
	for index, selectedElement in _getFlowProperty(_FlowID, "selectedElements") 
	{
		Element_Remove(_FlowID, selectedElement)
	}
	; we have deleted the selected elements and need to update some variables
	UpdateSelectedItemsList()
	
	; we changed something, so create a new state
	State_New(_FlowID)

	; redraw
	ui_UpdateStatusbartext()
	API_Draw_Draw(_FlowID)
	return
}


;Zoom out
mouse_wheeldown()
{
	mouse_wheel("down")
}
;Zoom in
mouse_wheelup()
{
	mouse_wheel("up")
}

; zoom in or out
mouse_wheel(direction)
{
	global default_zoomFactorMin, default_zoomFactorMax

	; get some info about the position and the zoom factor
	tempZoomZoomFactor := _getFlowProperty(_FlowID, "flowSettings.zoomfactor")
	tempZoomOffsetX := _getFlowProperty(_FlowID, "flowSettings.offsetx")
	tempZoomOffsetY := _getFlowProperty(_FlowID, "flowSettings.offsety")

	;Get the mouse position
	MouseGetPos,mx5,my5 

	;Get coordinates where the mouse points to
	mx5old := mx5 / tempZoomZoomFactor
	my5old := my5 / tempZoomZoomFactor

	;Change zoom factor
	zoomFactorOld := tempZoomZoomFactor

	if (direction = "up")
	{
		; zoom in
		tempZoomZoomFactor := tempZoomZoomFactor * 1.1
		if (tempZoomZoomFactor > default_zoomFactorMax)
		{
			; prevent that user zooms too far in
			tempZoomZoomFactor := default_zoomFactorMax
		}
	}		
	else if (direction = "down")
	{
		; zoom out
		tempZoomZoomFactor := tempZoomZoomFactor / 1.1
		if (tempZoomZoomFactor < default_zoomFactorMin)
		{
			; prevent that user zooms too far out
			tempZoomZoomFactor := default_zoomFactorMin
		}
	}

	;Get new position where the mouse points to
	mx5new := mx5 / tempZoomZoomFactor
	my5new := my5 / tempZoomZoomFactor

	;Move everything, so the mouse will still point at the same position
	tempZoomOffsetX :=  tempZoomOffsetX + mx5old - mx5new 
	tempZoomOffsetY := tempZoomOffsetY + my5old  - my5new

	; write the info about the position and the zoom factor
	_setFlowProperty(_FlowID, "flowSettings.zoomfactor", tempZoomZoomFactor)
	_setFlowProperty(_FlowID, "flowSettings.offsetx", tempZoomOffsetX)
	_setFlowProperty(_FlowID, "flowSettings.offsety", tempZoomOffsetY)

	; redraw
	ui_UpdateStatusbartext("pos")
	API_Draw_Draw(_FlowID)

}

; user pressed ctrl + x. Cut selected elements
key_ctrl_x()
{
	; save selected elements to clipboard
	ret := SaveToClipboard()
	if (ret = 0)
	{ 	
		;Delete all selected elements
		for selectedElementID, selectedElement in _getFlowProperty(_FlowID, "selectedElements") 
		{
			Element_Remove(_FlowID, selectedElement)
		}
		
		; we have deleted the selected elements and need to update some variables
		UpdateSelectedItemsList()
		
		; we changed something. Make new state
		State_New(_FlowID)

		; redraw
		ui_UpdateStatusbartext()
		API_Draw_Draw(_FlowID)
	}
}

; user pressed ctrl + x. Copy selected elements
key_ctrl_c()
{
	SaveToClipboard()
}

; user pressed ctrl + v. Paste selected elements
key_ctrl_v()
{
	loadFromClipboard()
	return
}

; user pressed ctrl + s. Save flow
key_ctrl_s()
{
	saveFlow(_FlowID)
	return
}

; user pressed ctrl + z. Undo a change
key_ctrl_z()
{
	; undo a change
	State_Undo(_FlowID)

	; update selected elements (if elements were removed)
	UpdateSelectedItemsList()

	; redraw
	ui_UpdateStatusbartext()
	API_Draw_Draw(_FlowID)
	return
}

; user pressed ctrl + y. Redo a change
key_ctrl_y()
{
	; redo a change
	State_Redo(_FlowID)
	
	; update selected elements (if elements were removed)
	UpdateSelectedItemsList()

	; redraw
	ui_UpdateStatusbartext()
	API_Draw_Draw(_FlowID)
	return
}

; user pressed ctrl + a. Select all elements
key_ctrl_a()
{
	; select all elements
	SelectEverything()

	; redraw
	ui_UpdateStatusbartext()
	API_Draw_Draw(_FlowID)
	return
}

