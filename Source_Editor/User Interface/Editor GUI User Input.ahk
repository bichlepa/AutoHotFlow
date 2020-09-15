; TODO; put everything inside functions and remove this goto
goto,jumpoverclickstuff

ui_leftmousebuttonclick()
{
	ui_mouseCick("left")
}
ui_rightmousebuttonclick()
{
	ui_mouseCick("right")
}

ui_mouseCick(button)
{
	global CurrentlyMainGuiIsDisabled
	global workingOnClick
	global UserClickedRbutton

	If CurrentlyMainGuiIsDisabled
	{
		; Prevent interaction with disable gui
		ui_ActionWhenMainGUIDisabled()
		return
	}

	if (button = "right")
	{
		if workingOnClick
		{
			; ; TODO: evaluate right clicks in the pseudo-thread which is busy with the user action

			; ; we are already busy with a user action.
			; ; We will find out whether user clicks or drags the right button.
			; if (ui_detectMovement(,"rbutton"))
			; {
			; 	; user drags with the right mouse button. We will scroll
			; 	ui_scrollwithMouse("rbutton")
			; }
			; else
			; {
			; 	; User did only a click. We will inform the other pseudo-thread about this user action
			; 	UserClickedRbutton:=true
			; }
		}
		else
		{	
			; Scroll with using right mouse button
			ui_scrollwithMouse("rbutton")
		}
	}
	else
	{
		; user clicked with the left mouse button
		; Go to label clickonpicture in order to react on user click.
		SetTimer,clickonpicture,-1 
	}
}

; user did a double click with left mouse button
ui_leftmousebuttondoubleclick()
{
	global CurrentlyMainGuiIsDisabled

	if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
	{
		ui_ActionWhenMainGUIDisabled()
		return
	}
	
	; track changes with those variables
	UserChangedSomething:=false
	UserCancelledAction:=false

	; get marked element
	selectedElement := _getFlowProperty(FlowID, "selectedElement")
	if (selectedElement != "") ;if a single element is marked
	{
		if instr(selectedElement, "connection")
		{
			 ;Change connection type and wait for results
			ret:=selectConnectionType(selectedElement,"wait")
			if (ret = "aborted")
				UserCancelledAction:=true
			else if (ret!="0 changes")
				UserChangedSomething:=true
		}
		else
		{
			;Change element settings and wait for results
			ret:=ElementSettings.open(selectedElement,"wait")
			if (ret = "aborted")
				UserCancelledAction:=true
			else if (ret!="0 changes")
				UserChangedSomething:=true
		}

		; if something was changed, handle last steps
		endworkingOnClick(UserChangedSomething, UserCancelledAction)
	}
}
return

 ;react on left mouse clicks of the user
clickOnPicture() ;react on clicks of the user
{
	global workingOnClick
	global CurrentlyMainGuiIsDisabled
	global default_ElementWidth, default_ElementHeight

	;Ignore if a click of user is already processed
	if (workingOnClick)
		return
	; make sure, we only process one click of user
	workingOnClick := true
	
	;Get the mouse position
	MouseGetPos,mx,my

	;Find out whether user presses the control key
	GetKeyState,ControlKeyState,control

	; track changes with those variables
	UserChangedSomething := false
	UserCancelledAction := false

	; get marked elements
	selectedElement := _getFlowProperty(FlowID, "selectedElement")
	selectedElements := _getFlowProperty(FlowID, "selectedElements")

	; get element user clicked on
	clickedItem := ui_findElementUnderMouse(mx, my)
	clickedElement := clickedItem.element
	partOfclickedElement := clickedItem.part
	if (not clickedElement) ;If user clicke on empty space.
	{
		; detect whether user drags with mouse
		if (ui_detectMovement()=false)
		{
			; user did not drag mouse.
			; if uses presses control key, do nothing
			if (ControlKeyState!="d")
			{
				; Unmark all elements
				if (selectedElements.count())
				{
					UnSelectEverything()
					ui_UpdateStatusbartext()
				}
			}
		}
		else
		{
			; user drags with mouse. Start scrolling
			ui_scrollwithMouse()
		}
	}
	else if (clickedElement="MenuCreateNewAction" or clickedElement="MenuCreateNewCondition" or clickedElement="MenuCreateNewLoop" or clickedElement="MenuCreateNewTrigger") ;User click either on "Create new action" or ".. condtion" in the drawn menu
	{
		; user clicked on the icon for creating a new element
		; create the new element
		if (clickedElement = "MenuCreateNewAction")
			newElement:=Element_New(FlowID, "action")
		else if (clickedElement = "MenuCreateNewCondition")
			newElement:=Element_New(FlowID, "Condition")
		else if (clickedElement = "MenuCreateNewLoop")
			newElement:=Element_New(FlowID, "Loop")
		else if (clickedElement = "MenuCreateNewTrigger")
			newElement:=Element_New(FlowID, "Trigger")
		else
		{
			throw exception("unexpected internal ERROR! A new element should be created. But I don't known which one!")
			return 
		}
		
		; place the element under the mouse cursor
		tempZoomFactor := _getFlowProperty(FlowID, "flowSettings.zoomfactor")
		tempOffsetX := _getFlowProperty(FlowID, "flowSettings.offsetx")
		tempOffsetY := _getFlowProperty(FlowID, "flowSettings.offsety")
		_setElementProperty(FlowID, newElement, "x", (mx)/tempZoomFactor + tempOffsetX - default_ElementWidth/2)
		_setElementProperty(FlowID, newElement, "y", (my)/tempZoomFactor + tempOffsetY - default_ElementHeight/2)

		; select the element
		SelectOneItem(newElement)
		; user may hold mouse button down while dragging or klick, move and klick again
		if (ui_detectMovement()) ;If user moves the mouse while holding the mouse button
		{
			;move the element. Stop moving when user releases the mouse button
			ret:=ui_moveSelectedElements(newElement)
		}
		else
		{
			;move the element. Stop moving when user clicks
			ret:=ui_moveSelectedElements(newElement,, "InvertLbutton")
		}
		if (ret.Aborted) ;if user cancelled movement
		{
			; this will undo the action later
			UserCancelledAction:=true
		}
		else
		{
			; select element subtype and wait for result
			ret := selectSubType(newElement,"wait")
			if (ret="aborted")
			{
				; this will undo the action later
				UserCancelledAction:=true
			}
			else
			{
				;open settings of element
				ret := ElementSettings.open(newElement,"wait")
				if (ret="aborted")
				{
					; this will undo the action later
					UserCancelledAction:=true
				}
				else
				{
					; it doesnt matter, whether user did changes in the editor or not, since it is a new element
					UserChangedSomething:=true
				}
			}
		}
	}
	else if (clickedElement = "PlusButton" or clickedElement = "PlusButton2") ;user click on plus button
	{
		IfInString, selectedElement, Connection ;The selected element is connection
		{
			;Create a new connection
			tempConnection2 := Connection_New(FlowID)
			
			; get the elements where the connection starts and stops
			tempFrom := _getConnectionProperty(FlowID, selectedElement, "from")
			tempTo := _getConnectionProperty(FlowID, selectedElement, "to")

			;Create a new connection
			tempConnection2 := Connection_New(FlowID)

			; move both connections
			ret:=ui_MoveConnection(selectedElement, tempFrom, tempConnection2, tempTo)
			if (ret="aborted")
			{
				; this will undo the action later
				UserCancelledAction:=true
			}
			else
			{
				UserChangedSomething:=true
			} 
		}
		else ;The selected element is either action, condition or trigger or loop
		{
			;Create new connection
			tempConnection1 := Connection_New(FlowID)
			
			; check whether the selected element is a loop
			tempType := _getElementProperty(FlowID, selectedElement, "type")
			if (tempType = "loop")
			{
				if (clickedElement="PlusButton")
				{
					; User clicked the first plus button. The connections starts from the head of the loop
					_setConnectionProperty(FlowID, tempConnection1, "frompart", "HEAD")
				}
				else if (clickedElement="PlusButton2")
				{
					; User clicked the second plus button. The connections starts from the tail of the loop
					_setConnectionProperty(FlowID, tempConnection1, "frompart", "TAIL")
				}
			}
			
			; move the connection
			ret := ui_MoveConnection(tempConnection1, selectedElement)
			if (ret="aborted")
			{
				; this will undo the action later
				UserCancelledAction:=true
			}
			else
			{
				UserChangedSomething:=true
			}
			
		}
	}
	else if (clickedElement = "MoveButton1") ;if a connection is selected and user wants to move the start of connection
	{
		; get the element at the end of the connection
		tempTo := _getConnectionProperty(FlowID, selectedElement, "to")

		; move the connection
		ret := ui_MoveConnection(, , selectedElement, tempTo)
		if (ret = "aborted")
		{
			; this will undo the action later
			UserCancelledAction:=true
		}
		else
		{
			UserChangedSomething:=true
		}
	}
	else if (clickedElement="MoveButton2") ;if a connection is selected and user wants to move the end of connection
	{
		; get the element at the start of the connection
		tempFrom := _getConnectionProperty(FlowID, selectedElement, "from")

		; move the connection
		ret:=ui_MoveConnection(selectedElement, tempFrom)
		if (ret = "aborted")
		{
			; this will undo the action later
			UserCancelledAction:=true
		}
		else
		{
			UserChangedSomething:=true
		}
	}
	else if (clickedElement="TrashButton") ;if something is selected and user clicks on the trash button
	{
		; check whether the selected item is connection or element
		if instr(selectedElement, "connection")
		{
			; The item is a connection

			; Confirm deletion
			tempType := _getConnectionProperty(FlowID, selectedElement, "type")
			MsgBox, 4, % lang("Delete Object") , % lang("Do you really want to delete the %1%?", tempType, "`n")
		}
		else
		{
			; The item is an element
			
			; Confirm deletion
			tempType := _getElementProperty(FlowID, selectedElement, "type")
			tempName := _getElementProperty(FlowID, selectedElement, "name")
			MsgBox, 4, % lang("Delete Object") , % lang("Do you really want to delete the %1% '%2%'?",lang(tempType), "`n" tempName "`n")
		}
		
		IfMsgBox yes ; did user agree?
		{
			; delete selected item
			Element_Remove(FlowID, selectedElement)
			UserChangedSomething:=true
		}
		
		; since we deleted the selected element, recreate the selected list
		UpdateSelectedItemsList()
	}
	else if (clickedElement="EditButton")  ;if something is selected and user clicks on the edit button
	{
		; check whether the selected item is connection or element
		if instr(selectedElement, "connection")
		{
			; select connection type
			ret := selectConnectionType(selectedElement,"wait")
			if (ret = "aborted")
			{
				; this will undo the action later
				UserCancelledAction:=true
			}
			else
			{
				UserChangedSomething:=true
			}
		}
		else
		{
			;open settings of the selected element
			ret := ElementSettings.open(selectedElement,"wait") 
			if (ret = "aborted")
			{
				; this will undo the action later
				UserCancelledAction:=true
			}
			else if (ret!="0 changes" )
			{
				; user did some changes in the properties
				UserChangedSomething:=true
			}
		}
		

	}
	else if (clickedElement="SwitchOnButton")  ;if a trigger is selected and user clicks on the switch on button
	{
		; disable the trigger
		disableOneTrigger(FlowID, selectedElement)
	}
	else if (clickedElement="SwitchOffButton")  ;if a trigger is selected and user clicks on the switch off button
	{
		; enable the trigger
		enableOneTrigger(FlowID, selectedElement)
	}
	else if (clickedElement="StarEmptyButton")  ;if a manual trigger is selected and user clicks on the empty star button
	{
		; Set this trigger as default
		Element_setDefaultTrigger(FlowID, selectedElement)
		UserChangedSomething := true
	}
	else if (clickedElement="StarFilledButton")  ;if a manual trigger is selected and user clicks on the filled start button
	{
		;Nothing to do, since a flow always must have a default trigger (if it has a manual trigger )
	}
	else if (clickedElement!="") ;if user clicked on an element
	{
		; check whether user moves the mouse
		if (!ui_detectMovement()) ;If user did not move the mouse
		{
			if (ControlKeyState="d") ;if user presses Control key
			{
				; if user holds the control button
				; select or unselect the clicked item additionally
				SelectOneItem(clickedElement,true)
			}
			else
			{
				; select the clicked item and unselect others
				SelectOneItem(clickedElement) ;mark one element and unmark others
			}
		}
		else ;If user moves the mouse
		{
			if !instr(selectedElement, "connection") ; do nothing if user drags a connection
			{
				if (_getElementProperty(FlowID, clickedElement, "marked")) ;If the element under the mouse is already selected
				{
					;move the selected elements
					ret := ui_moveSelectedElements(clickedElement, partOfclickedElement)
				}
				else if ((ControlKeyState!="d")) ;if clicked element is not selected and user does not press the control key
				{
					; select the clicked item and unselect others
					SelectOneItem(clickedElement)
					;move the selected element
					ret := ui_moveSelectedElements(clickedElement, partOfclickedElement)
				}
				else ;if clicked element is not selected and user presses Control key
				{
					; select the clicked item additionally
					SelectOneItem(clickedElement,true) 
					;move the selected elements
					ret := ui_moveSelectedElements(clickedElement, partOfclickedElement)
				}
				
				if (ret.aborted)
				{
					; this will undo the action later
					UserCancelledAction:=true
				}
				else if (ret.moved = true) ;if user actually moved the elements
				{
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

return

; Called when user finished an interaction with the gui
; If user made a change, we need to make a new state
; If user cancelled the action, we need to undo andy already made changes
endworkingOnClick(changedSomething, cancelled)
{
	global workingOnClick
	if (cancelled) ; user cancelled the action
	{
		; restorr the current state and undo all eventual changes from user
		State_RestoreCurrent(FlowID)
		UpdateSelectedItemsList()
	}
	else if (changedSomething) ; user change something
	{
		;make a new state. If user presses Ctrl+Z, the change will be undone
		State_New(FlowID)
	}

	; redraw the gui
	API_Draw_Draw(FlowID) 

	; now we can handle a new interaction
	workingOnClick := false
	return
}

; find the element which is under the mouse. Called when user clicks on the picture
ui_findElementUnderMouse(mx, my, par_filter="", par_priority="highest")
{
	global default_SizeOfButtons

	clickedElement:=""
	partOfclickedElement:=""
	elementBestPriority:=""
	selectedElementWithLowestPriority:=""
	selectedElementLowestPriority:=""

	; get the information about the locations of the elements in the picture
	drawResultFlow := _getFlowProperty(FlowID, "DrawResult")

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
		for forElementIndex, forElementID in _getAllElementIds(FlowID)
		{
			; get the position data of the element
			drawResultElement := drawResultFlow.elements[forElementID]
			; get additional data
			clickPriority := _getElementProperty(FlowId, forElementID, "ClickPriority")
			marked := _getElementProperty(FlowId, forElementID, "marked")

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
				_getAndIncrementElementProperty(FlowID, forElementID, "ClickPriority")
			}
		}
		
		; set the priority of the found element to a lower value
		if (clickedElement != "")
		{
			_setElementProperty(FlowID, clickedElement, "ClickPriority", 490)
		}
	}
	
	
	;nothing found yet, search for a connection under the mouse cursor
	if (mode_searchForConnections and clickedElement="")
	{
		; Same as elements, we select the element with highest priority
		elementBestPriority := par_priority = "highest" ? 0 : 1000000
		
		; loop though all connections
		for forElementIndex, forElementID in _getAllConnectionIds(FlowID)
		{
			; get the position data of the element
			drawResultElement:=drawResultFlow.elements[forElementID]

			; get additional data
			clickPriority := _getConnectionProperty(FlowId, forElementID, "ClickPriority")

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
				_getAndIncrementConnectionProperty(FlowID, forElementID, "ClickPriority")
			}
		}
		
		; set the priority of the found connection to a lower value
		if (clickedElement)
		{
			_setConnectionProperty(FlowID, clickedElement, "ClickPriority", 190)
		}

	}
	
	return {element: clickedElement, part: partOfclickedElement}
}

; move the selected elements
ui_moveSelectedElements(clickedElement, partOfclickedElement = "", option="")
{
	global default_Gridy

	; get some information about the location of the element
	oldposx := _getElementProperty(FlowID, clickedElement, "x") ;Store the old position of the element
	firstposx := oldposx
	firstoffsetx := _getFlowProperty(FlowID, "flowSettings.offsetx")
	firstmx := mx
	oldposy := _getElementProperty(FlowID, clickedElement, "y") ;Store the old position of the element
	firstposy := oldposy
	firstoffsety := _getFlowProperty(FlowID, "flowSettings.offsety")
	firstmy := my
	elementType := _getElementProperty(FlowID, clickedElement, "type") 

	; get the initial mouse position
	MouseGetPos, firstmx, firstmy

	; create variables which will be returned
	moved:=false
	MovementAborted:=false
	
	; check whether we need to move the tail of a loop.
	; if the loop is the only selected element && this is a loop && user clicked on the tail (which is part 3 & 4)
	if (_getFlowProperty(FlowID, "selectedElement") = clickedElement && elementType = "loop" && partOfclickedElement>=3)
	{
		; get old height of the vertical bar
		oldHeightOfVerticalBar := _getElementProperty(FlowID, clickedElement, "HeightOfVerticalBar")
		
		Loop ;Move element(s)
		{
			; check whether user holds the left mouse button (or does not if inverted)
			lbuttonDown := getkeystate("lbutton")
			if (option != "InvertLbutton" and !lbuttonDown or option = "InvertLbutton" and lbuttonDown)
			{
				; user released the mouse button. We kan drop the elements now
				;Fit the element position to grid
				newHeightOfVerticalBar := _getElementProperty(FlowID, clickedElement, "HeightOfVerticalBar")
				newHeightOfVerticalBar := ui_FitGridx(newHeightOfVerticalBar)
				_setElementProperty(FlowID, clickedElement, "HeightOfVerticalBar", newHeightOfVerticalBar)
				
				; check whether the position has changed after all
				if (newHeightOfVerticalBar != oldHeightOfVerticalBar)
					moved := true
				
				; redraw the picture
				API_Draw_Draw(FlowID)
			
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
				zoomfactor := _getFlowProperty(FlowID, "flowSettings.zoomfactor")
				offsety := _getFlowProperty(FlowID, "flowSettings.offsety")
				
				; calculate the new height of the vertical bar
				newHeightOfVerticalBar := (oldHeightOfVerticalBar + (newmy - firstmy) / zoomfactor) - firstoffsety + offsety
				if (newHeightOfVerticalBar < default_Gridy*2)
					newHeightOfVerticalBar := default_Gridy*2

				; write the new height
				_setElementProperty(FlowID, clickedElement, "HeightOfVerticalBar", newHeightOfVerticalBar)
				
				; redraw
				API_Draw_Draw(FlowID)
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
		selectedElements := _getFlowProperty(FlowID, "selectedElements")

		; save the old positions of all elements
		oldElementsPos := object()
		for forIndex, forElementID in selectedElements  ;Preparing to move
		{
			oldElementsPos[forElementID] := Object()
			oldElementsPos[forElementID].x := _getElementProperty(FlowID, forElementID, "x")
			oldElementsPos[forElementID].y := _getElementProperty(FlowID, forElementID, "y")
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
					newposx := ui_FitGridX(_getElementProperty(FlowID, forElementID, "x"))
					newposy := ui_FitGridX(_getElementProperty(FlowID, forElementID, "y"))
					_setElementProperty(FlowID, forElementID, "x", newposx)
					_setElementProperty(FlowID, forElementID, "y", newposy)
					
					; check whether the position has changed after all
					if (oldElementsPos[forElementID].x != newposx or oldElementsPos[forElementID].y != newposy)
						moved := true
				}
				
				; redraw the picture
				API_Draw_Draw(FlowID)
				
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
				zoomfactor := _getFlowProperty(FlowID, "flowSettings.zoomfactor")
				offsetx := _getFlowProperty(FlowID, "flowSettings.offsetx")
				offsety := _getFlowProperty(FlowID, "flowSettings.offsety")
				;loop through all selected elements to move them all
				for forIndex, forElementID in selectedElements
				{
					; calculate the new position of the element
					newposx := (oldElementsPos[forElementID].x + (newmx - firstmx) / zoomfactor) - firstoffsetx + offsetx
					newposy := (oldElementsPos[forElementID].y + (newmy - firstmy) / zoomfactor) - firstoffsety + offsety
					
					; write the new position of the element
					_setElementProperty(FlowID, forElementID, "x", newposx)
					_setElementProperty(FlowID, forElementID, "y", newposy)
				}

				; redraw
				API_Draw_Draw(FlowID)
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
	zoomfactor := _getFlowProperty(FlowID, "flowSettings.zoomfactor")
	firstOffsetx := _getFlowProperty(FlowID, "flowSettings.offsetx")
	firstOffsety := _getFlowProperty(FlowID, "flowSettings.offsety")
	
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
			API_Draw_Draw(FlowID)
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
			_setFlowProperty(FlowID, "flowSettings.Offsetx", newOffsetx)
			_setFlowProperty(FlowID, "flowSettings.Offsety", newOffsety)
			
			; redraw and update status bar
			ui_UpdateStatusbartext("pos")
			API_Draw_Draw(FlowID)

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
		_setConnectionProperty(FlowID, connection1, "to", "MOUSE")
		; Start the connection from element1 (needed if this is a new connection)
		_setConnectionProperty(FlowID, connection1, "from", element1)
	}
	
	; if connection 2 is defined
	if (connection2)
	{
		;The start of the connection should follow the mouse
		_setConnectionProperty(FlowID, connection2, "from", "MOUSE")
		; End the connection to element2 (needed if this is a new connection or if a connection was split)
		_setConnectionProperty(FlowID, connection2, "to", element2)
	}
	
	; If both connections defined, a connection was split
	if (connection1 and connection2)
	{
		; since connection1 is the old connection, connection2 has now to end, where connection1 has ended before.
		connection1toPart := _getElementProperty(FlowID, connection1, "toPart")
		_setConnectionProperty(FlowID, connection2, "toPart", connection1toPart)
		; delete the part information from connection 1
		_deleteConnectionProperty(FlowID, connection1, "toPart")
	}
	
	; we want to draw a plus icon under the mouse to hide the lose ends of the connections
	_setFlowProperty(FlowID, "draw.DrawMoveButtonUnderMouse", true)
	
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
			API_Draw_Draw(FlowID)
		}
		else ;If mouse is not currently moving
		{
			sleep,10 ;Save processor load
		}
	}

	
	; we can stop to draw the move button now
	_setFlowProperty(FlowID, "draw.DrawMoveButtonUnderMouse", false)
	
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
		clickedElement := Element_New(FlowID)
		newElementCreated := true
		
		; set user choose element type
		ret := selectContainerType(clickedElement, "wait")
		if (ret = "aborted")
		{
			; user cancelled
			return "aborted"
		}

		; calculate and set the position of the new element
		zoomfactor := _getFlowProperty(FlowID, "flowSettings.zoomfactor")
		offsetx := _getFlowProperty(FlowID, "flowSettings.offsetx")
		offsety := _getFlowProperty(FlowID, "flowSettings.offsety")

		tempx := (mx) / zoomfactor + Offsetx - default_ElementWidth / 2
		tempy := (my) / zoomfactor + offsety  - default_ElementHeight / 2
		tempx := ui_FitGridX(tempx)
		tempy := ui_FitGridX(tempy)
		_setElementProperty(FlowID, clickedElement, "x", tempx)
		_setElementProperty(FlowID, clickedElement, "y", tempy)
		
		if (connection1)
		{
			; the first connection (if any) will end at the new element
			connection1To := clickedElement
			_setConnectionProperty(FlowID, connection1, "to", clickedElement)
		}
		
		if (connection2)
		{
			; the second connection (if any) will start at the new element
			connection2From := clickedElement
			_setConnectionProperty(FlowID, connection2, "from", clickedElement)
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
		ret := selectSubType(clickedElement, "Wait")
		if (ret = "aborted") ;If user aborted
		{
			; user cancelled
			return "aborted"
		}
		
		;open settings of element
		ret := ElementSettings.open(clickedElement, "Wait")
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
			_setConnectionProperty(FlowID, connection1, "to", clickedElement)
		}
		
		if (connection2 != "")
		{
			; the second connection (if any) will start at the clicked element
			connection2From := clickedElement
			_setConnectionProperty(FlowID, connection2, "from", clickedElement)
		}

		;Check whether Connection is possible
		elementType := _getElementProperty(FlowID, clickedElement, "Type")
		if (elementType = "Trigger" && connection1)
		{
			; user dragged the end of connection1 to a trigger
			Msgbox,% lang("You_cannot_connect_to_trigger!")
			return "aborted"
		}
		if (clickedElement = Element1 OR clickedElement = Element2)
		{
			; user created a loop with only one element within it
			Msgbox,% lang("The_Connection_cannot_start_and_end_on_the_same_element!")
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
	API_Draw_Draw(FlowID)
	return
	
	; let user define other propierties of the connections, if needed
	ui_MoveConnectionCheckAndCorrect:
	
		
	; Check whether connection 1 ends at a loop or connection 2 starts at a loop
	elementType := _getElementProperty(FlowID, clickedElement, "Type")
	if (elementType = "Loop") ;If user pulled to a loop, assign parts
	{
		if newElementCreated
		{
			 ;If a new connection was created, define default parts
			_setConnectionProperty(FlowID, connection1, "toPart", "HEAD")
			_setConnectionProperty(FlowID, connection2, "fromPart", "TAIL")
		}
		else ;If user has pulled to an existing loop, decide depending on which part he dropped it
		{
			if (Connection1!="" and Connection2!="")
			{
				;both connections is defined. assign default parts
				_setConnectionProperty(FlowID, connection1, "toPart", "HEAD")
				_setConnectionProperty(FlowID, connection2, "fromPart", "TAIL")
			}
			else
			{
				; only one connection is defined
				if (clickedElementPart=1 or clickedElementPart=2) ; head or side part of the loop
				{
					; set the start or end of the connection to head
					_setConnectionProperty(FlowID, connection1, "toPart", "HEAD")
					_setConnectionProperty(FlowID, connection2, "fromPart", "HEAD")
				}
				else if (clickedElementPart=3) ; tail of the loop
				{
					; set the start or end of the connection to tail
					_setConnectionProperty(FlowID, connection1, "toPart", "TAIL")
					_setConnectionProperty(FlowID, connection2, "fromPart", "TAIL")
				}
				else if (clickedElementPart=4) ; the break field in the tail of the loop
				{
					; set the end of the connection1 (if any) to break
					; since connection2 (if any) can't start from break, assign it to tail
					_setConnectionProperty(FlowID, connection1, "toPart", "BREAK" )
					_setConnectionProperty(FlowID, connection2, "fromPart", "TAIL")
				}
			}
		}
	}
	else ;if user did not pull to the loop, delete part informations
	{
		_deleteConnectionProperty(FlowID, Connection1, "toPart")
		_deleteConnectionProperty(FlowID, Connection2, "fromPart")
	}

	if (Connection1 != "") ;If connection 1 exists
	{
		; get some information
		connection1From := _getConnectionProperty(FlowID, Connection1, "from")
		elementType := _getElementProperty(FlowID, connection1From, "Type")
		connectionType := _getConnectionProperty(FlowID, connection1, "connectiontype")

		if (elementType = "Condition" )
		{
			;if pulled to condition, check whether the connection type is suitable
			if (connectionType != "exception" 
				and connectionType != "no" 
				and connectionType != "yes") 
			{
				; the connection type is not suitable. let user select a new one
				ret := selectConnectionType(Connection1, "wait")
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
				_setConnectionProperty(FlowID, connection1, "connectiontype", "normal")
			}
		}
	}
	
	if (Connection2 != "") ;If connection 2 exists
	{
		; get some information
		elementType := _getElementProperty(FlowID, connection2From, "Type")
		connectionType := _getConnectionProperty(FlowID, connection2, "connectiontype")

		if (elementType = "Condition")
		{
			;if pulled to condition, check whether the connection type is suitable
			if (connectionType != "exception" 
				and connectionType != "no" 
				and connectionType != "yes")
			{
				; the connection type is not suitable. let user select a new one
				ret:=selectConnectionType(Connection2, "wait")
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
				_setConnectionProperty(FlowID, connection2, "connectiontype", "normal")
			}
		}
	}

	;Check whether user created an already existing connection
	; gather informations
	Connection1Type := _getConnectionProperty(FlowID, Connection1, "ConnectionType")
	Connection2Type := _getConnectionProperty(FlowID, Connection2, "ConnectionType")
	Connection1From := _getConnectionProperty(FlowID, Connection1, "from")
	Connection2From := _getConnectionProperty(FlowID, Connection2, "from")
	Connection1To := _getConnectionProperty(FlowID, Connection1, "to")
	Connection2To := _getConnectionProperty(FlowID, Connection2, "to")
	Connection1FromPart := _getConnectionProperty(FlowID, Connection1, "fromPart")
	Connection2FromPart := _getConnectionProperty(FlowID, Connection2, "fromPart")
	Connection1ToPart := _getConnectionProperty(FlowID, Connection1, "toPart")
	Connection2ToPart := _getConnectionProperty(FlowID, Connection2, "toPart")

	for forIndex, forConnectionID in _getAllConnectionIds(FlowID)
	{
		forConnectionFrom := _getConnectionProperty(FlowID, forConnectionID, "from")
		forConnectionTo := _getConnectionProperty(FlowID, forConnectionID, "to")

		if (forConnectionID != Connection1)
		{
			if (Connection1From = forConnectionFrom and Connection1To = forConnectionTo)
			{
				forConnectionType := _getConnectionProperty(FlowID, forConnectionID, "ConnectionType")

				if (Connection1Type = forConnectionType)
				{
					forConnectionFromPart := _getConnectionProperty(FlowID, forConnectionID, "fromPart")
					forConnectionToPart := _getConnectionProperty(FlowID, forConnectionID, "toPart")
					if (Connection1FromPart = forConnectionFromPart and Connection1ToPart = forConnectionToPart)
					{
						msgbox,% lang("This_Connection_Already_Exists!")
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
				forConnectionType := _getConnectionProperty(FlowID, forConnectionID, "ConnectionType")

				if (Connection2Type = forConnectionType)
				{
					forConnectionFromPart := _getConnectionProperty(FlowID, forConnectionID, "fromPart")
					forConnectionToPart := _getConnectionProperty(FlowID, forConnectionID, "toPart")
					if (Connection1FromPart = forConnectionFromPart and Connection1ToPart = forConnectionToPart)
					{
						msgbox,% lang("This_Connection_Already_Exists!")
						MovementAborted:=true
						return ; back to the gosub call
					}
				}
			}
		}
	}
		
	return ; back to the gosub call
}

; TODO: activate Hotkeys only for the window hwnd.
#IfWinActive ·AutoHotFlow· Editor ;Hotkeys

esc:
return

del: ;delete marked element
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}

 ;remove all marked elements
for markindex, markelement in _getFlowProperty(FlowID, "selectedElements") 
{
	Element_Remove(FlowID, markelement)
}
UpdateSelectedItemsList()
;e_CorrectElementErrors("Code: 354546841.")
State_New(FlowID)
ui_UpdateStatusbartext()
API_Draw_Draw(FlowID)
return



;Zoom
ctrl_wheeldown:
IfWinNotActive,% "ahk_id " _EditorGuiHwnd
	return
;Get the mouse position
MouseGetPos,mx5,my5 


tempZoomZoomFactor := _getFlowProperty(FlowID, "flowSettings.zoomfactor")
tempZoomOffsetX := _getFlowProperty(FlowID, "flowSettings.offsetx")
tempZoomOffsetY := _getFlowProperty(FlowID, "flowSettings.offsety")

;Get coordinates where the mouse points to
mx5old := mx5 / tempZoomZoomFactor
my5old := my5 / tempZoomZoomFactor


;Change zoom factor
zoomFactorOld := tempZoomZoomFactor

tempZoomZoomFactor := tempZoomZoomFactor / 1.1
if (tempZoomZoomFactor < default_zoomFactorMin)
{
	tempZoomZoomFactor := default_zoomFactorMin
}

;Get new position where the mouse points to
mx5new := mx5 / tempZoomZoomFactor
my5new := my5 / tempZoomZoomFactor

;Move everything, so the mouse will still point at the same position
tempZoomOffsetX :=  tempZoomOffsetX + mx5old - mx5new 
tempZoomOffsetY := tempZoomOffsetY + my5old  - my5new

_setFlowProperty(FlowID, "flowSettings.zoomfactor", tempZoomZoomFactor)
_setFlowProperty(FlowID, "flowSettings.offsetx", tempZoomOffsetX)
_setFlowProperty(FlowID, "flowSettings.offsety", tempZoomOffsetY)

ui_UpdateStatusbartext("pos")
API_Draw_Draw(FlowID)

return

ctrl_wheelup:
IfWinNotActive,% "ahk_id " _EditorGuiHwnd
	return

MouseGetPos,mx5,my5 ;Get the mouse position

tempZoomZoomFactor := _getFlowProperty(FlowID, "flowSettings.zoomfactor")
tempZoomOffsetX := _getFlowProperty(FlowID, "flowSettings.offsetx")
tempZoomOffsetY := _getFlowProperty(FlowID, "flowSettings.offsety")

;Get coordinates where the mouse points to
mx5old := mx5 / tempZoomZoomFactor
my5old := my5 / tempZoomZoomFactor

;Change zoom factor
zoomFactorOld:=tempZoomZoomFactor

tempZoomZoomFactor := tempZoomZoomFactor * 1.1
if (tempZoomZoomFactor > default_zoomFactorMax)
{
	tempZoomZoomFactor := default_zoomFactorMax
}

;Get new position where the mouse points to
mx5new := mx5 / tempZoomZoomFactor
my5new := my5 / tempZoomZoomFactor


;Move everything, so the mouse will still point at the same position

tempZoomOffsetX := tempZoomOffsetX + mx5old - mx5new 
tempZoomOffsetY := tempZoomOffsetY + my5old - my5new

_setFlowProperty(FlowID, "flowSettings.zoomfactor", tempZoomZoomFactor)
_setFlowProperty(FlowID, "flowSettings.offsetx", tempZoomOffsetX)
_setFlowProperty(FlowID, "flowSettings.offsety", tempZoomOffsetY)

ui_UpdateStatusbartext("pos")

API_Draw_Draw(FlowID)

return


ctrl_x:
ret := SaveToClipboard()
if (ret = 0)
{ 	
	;Delete all marked elements
	selectedElementscopy := _getFlowProperty(FlowID, "selectedElements") 

	for markID, markelement in _getFlowProperty(FlowID, "selectedElements") 
	{
		;remove all marked elements
		Element_Remove(FlowID, markelement)
	}
	selectedElementscopy:=""
	
	State_New(FlowID)
	ui_UpdateStatusbartext()
	API_Draw_Draw(FlowID)
}
return

ctrl_c:
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
SaveToClipboard()
return

ctrl_v:
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
loadFromClipboard()
return

ctrl_s:
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
saveFlow(FlowID)
return

ctrl_z:
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
State_Undo(FlowID)
UpdateSelectedItemsList()
API_Draw_Draw(FlowID)
return
ctrl_y:
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
State_Redo(FlowID)
API_Draw_Draw(FlowID)
return

ctrl_a:
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
UnSelectEverything()
SelectEverything()
API_Draw_Draw(FlowID)
return



jumpoverclickstuff:
temp=