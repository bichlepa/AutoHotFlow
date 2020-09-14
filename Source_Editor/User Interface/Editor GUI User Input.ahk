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
			ret:=ui_MoveConnection(selectedElement,tempConnection2, tempFrom, tempTo)
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
			
			; check whether the connection is a loop
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
			ret:=ui_MoveConnection(tempConnection1, ,selectedElement )
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
		ret := ui_MoveConnection(, selectedElement, , tempTo )
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
		ret:=ui_MoveConnection(selectedElement ,,tempFrom )
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
			lbuttonDown := getkeystate("lbutton","P")
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
			if (getkeystate("esc","P"))
			{
				; set the return value, which should trigger an undo later
				moved := false
				MovementAborted := true
				break
			}
			; check whether user holds the right button to either cancel the movement or to scroll
			if (getkeystate("rbutton", "P")) ;If user cancels movement, move back
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
			lbuttonDown := getkeystate("lbutton","P")
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
			if (getkeystate("esc","P"))
			{
				; set the return value, which should trigger an undo later
				moved := false
				MovementAborted := true
				break
			}
			; check whether user holds the right button to either cancel the movement or to scroll
			if (getkeystate("rbutton","P")) ;If user cancels movement, move back
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

ui_detectMovement(threshold=2,button="lbutton")
{
	
	MouseGetPos,xold,yold ;get mouse position and calculate the new position of the element
	Loop ;Wait until it moves or the mouse button is released
	{
		
		GetKeyState,k,%button%,p ;When mouse releases, return false
		if (k!="d")
		{
			return false
			
		}
		MouseGetPos,xnew,ynew ;get mouse position and calculate the new position of the element
		
		if (xnew!=xold OR yold!=ynew) ;If mouse is currently moving
		{
			yold:=ynew
			xold:=xnew
			
			howMuchMoved++
			if (howMuchMoved>threshold)
			{
				
				return true
			}
		}
		
		
		sleep,10 ;Save processor load
	}
	return false
	
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


;Moves one or multiple connections to an other element or create a new element
;Return value: "aborted" or ""
ui_MoveConnection(connection1="", connection2="", element1="", element2="")
{
	global
	local abortAddingElement, ret, untilRelease, tempElement
	local mx2, my2, newElementCreated, NewElementPart
	local tempx, tempy, zoomfactor, offsetx, offsety
	
	;move elements to mouse
	UnSelectEverything()
	if (connection1!="")
		SelectOneItem(connection1)
	
	if (connection2!="")
		SelectOneItem(connection2,true)
	
	connection1From := _getConnectionProperty(FlowID, connection1, "from")
	connection1To := _getConnectionProperty(FlowID, connection1, "to")
	connection1FromPart := _getConnectionProperty(FlowID, connection1, "fromPart")
	connection1ToPart := _getConnectionProperty(FlowID, connection1, "toPart")

	connection2From := _getConnectionProperty(FlowID, connection2, "from")
	connection2To := _getConnectionProperty(FlowID, connection2, "to")
	connection2FromPart := _getConnectionProperty(FlowID, connection2, "fromPart")
	connection2ToPart := _getConnectionProperty(FlowID, connection2, "toPart")

	if (connection2)
	{

		connection2From := "MOUSE" ;The start position should follow the mouse
		connection2To := element2  ; End the connection to element2 (needet if this is a new connection or if a connection was split)

		; If a connection was split, set the part of the element, where the conneciton ends
		if (connection1)
		{
			connection2ToPart := connection1ToPart
			connection1ToPart := ""
		}
	}
	
	if (connection1)
	{
		connection1From := element1 ; Start the connection from element1 (needet if this is a new connection)
		connection1To := "MOUSE"  ;The end position should follow the mouse
	}
	
	_setFlowProperty(FlowID, "draw.DrawMoveButtonUnderMouse", true)
	
	if (ui_detectMovement()) ;If user moves the mouse
		untilRelease:=true ;move until user releases mouse
	else
		untilRelease:=false ;move untli user clicks
	
	;Wait until user releases the mouse and add an element there
	;The connections follow the mouse
	UserClickedRbutton:=false

	; Wait until user defines the designated position
	Loop
	{
		;~ SoundBeep
		if (ui_detectMovementWithoutBlocking()) ;check, whether user has moved mouse
			API_Draw_Draw(FlowID)

		if (untilRelease and !getkeystate("lbutton","P") or !untilRelease and getkeystate("lbutton","P")) ;if user finishes moving
		{
			break
		}
		if ( UserClickedRbutton or getkeystate("esc","P")) ;if user aborts moving
		{
			abortAddingElement:=true
			break
		}
		sleep 10 ;reduce CPU load
		
	}
	
	_setFlowProperty(FlowID, "draw.DrawMoveButtonUnderMouse", false)
	
	if (abortAddingElement)
		return "aborted"
	
	MouseGetPos,mx,my ;Get the mouse position
	
	
	clickedItem := ui_findElementUnderMouse(mx, my, "OnlyElements", "lowest") ;Search an element beneath the mouse.
	clickedElement := clickedElement.element
	partOfclickedElement := clickedElement.part
	
	
	if (clickedElement="") ;If user pulled the end of the connection to empty space. Create new element
	{
		local newElement := Element_New(FlowID)
		local newElementCreated := true
		
		ret := selectContainerType(newElement,"wait")
		if (ret="aborted") ;If user did not select the container type
		{
			return "aborted"
		}

		zoomfactor := _getFlowProperty(FlowID, "flowSettings.zoomfactor")
		offsetx := _getFlowProperty(FlowID, "flowSettings.offsetx")
		offsety := _getFlowProperty(FlowID, "flowSettings.offsety")

		tempx := (mx) / zoomfactor + offsety - default_ElementWidth / 2
		tempy := (my) / zoomfactor + offsety  - default_ElementHeight / 2
		tempx := ui_FitGridX(tempx)
		tempy := ui_FitGridX(tempy)
		_setElementProperty(FlowID, newElement, "x", tempx)
		_setElementProperty(FlowID, newElement, "y", tempy)
		
		if (connection1!="")
		{
			connection1To := newElement
			_setConnectionProperty(FlowID, connection1, "to", newElement)
		}
		
		if (connection2!="")
		{
			connection2From := newElement
			_setConnectionProperty(FlowID, connection2, "from", newElement)
		}
		
		gosub, ui_MoveConnectionCheckAndCorrect
		if abortAddingElement
			return "aborted"
		
		SelectOneItem(newElement)
		clickedElement:=newElement
		
		ret:=selectSubType(newElement,"Wait")
		if (ret="aborted") ;If user aborted
		{
			return "aborted"
		}
			
		ret:=ElementSettings.open(newElement,"Wait") ;open settings of element
		if (ret="aborted") ;If user aborted
		{
			return "aborted"
		}
		
	}
	else ;If user pulled the end of the connection to an existing element
	{
		;~ SoundBeep 600
		local NewElement := clickedElement
		local NewElementPart := partOfclickedElement
		local newElementCreated := false
		
		if (connection1!="")
		{
			connection1To := newElement
			_setConnectionProperty(FlowID, connection1, "to", newElement)
		}
		
		if (connection2!="")
		{
			connection2From := newElement
			_setConnectionProperty(FlowID, connection2, "from", newElement)
		}

		elementType := _getElementProperty(FlowID, NewElement, "Type")

		;Check whether Connection is possible
		if (elementType = "Trigger" && connection1)
		{
			Msgbox,% lang("You_cannot_connect_to_trigger!")
			return "aborted"
		}
		if (NewElement = Element1 OR NewElement = Element2)
		{
			Msgbox,% lang("The_Connection_cannot_start_and_end_on_the_same_element!")
			return "aborted"
		}
		
		gosub, ui_MoveConnectionCheckAndCorrect
		if abortAddingElement
			return "aborted"
		
		if (Connection1!="" and Connection2!="") ;if user has split a connection and connected an other element inbetween
			SelectOneItem(NewElement)
		;else keep the new or modified connection marked
		
	}
	API_Draw_Draw(FlowID)
	return
	
	ui_MoveConnectionCheckAndCorrect:
	
	if (Connection1 != "") ;If connection 1 exists
	{
		local elementType := _getElementProperty(FlowID, connection1From, "Type")
		local connectionType := _getConnectionProperty(FlowID, connection1, "connectiontype")

		if (elementType = "Condition" )
		{
			;if pulled to condition, check whether the connection type is suitable
			if (connectionType != "exception" 
				and connectionType != "no" 
				and connectionType != "yes") 
			{
				ret := selectConnectionType(Connection1, "wait")
				if (ret = "aborted")
					abortAddingElement := True
			}
		}
		else ;if pulled to anything else, check whether it is normal or exception
		{
			if (connectionType != "normal" and connectionType != "exception")
			{
				_setConnectionProperty(FlowID, connection1, "connectiontype", "normal")
			}
		}
	}
	
	if (Connection2 != "") ;If connection 2 exists
	{
		local elementType := _getElementProperty(FlowID, connection2From, "Type")
		local connectionType := _getConnectionProperty(FlowID, connection2, "connectiontype")

		if (elementType = "Condition")
		{
			;if pulled to condition, check whether the connection type is suitable
			if (connectionType != "exception" 
				and connectionType != "no" 
				and connectionType != "yes")
			{
				ret:=selectConnectionType(Connection2,"wait")
				if (ret="aborted")
					abortAddingElement := True
			}
		}
		else ;if pulled to anything else, check whether it is normal or exception
		{
			if (connectionType != "normal" and connectionType != "exception")
			{
				_setConnectionProperty(FlowID, connection2, "connectiontype", "normal")
			}
		}
	}
	
	
	local element2Type := _getElementProperty(FlowID, Element2, "Type")
	local connection2toPart := _getElementProperty(FlowID, connection2, "toPart")
	local connection1toPart := _getElementProperty(FlowID, connection1, "toPart")
	; TODO: Is this really needed? Or is this ancient uneeded code?
	if (element2Type = "Loop") ;If the second element is a loop. The information about the connected part is not yet in the second connection.
	{
		if (not connection2toPart) ;If no part assigned to connection
		{
			if (Connection1 != "") ;If a second connection exist. Thus it was previously connected to the loop
				_setConnectionProperty(FlowID, connection2, "toPart", connection1toPart)
			else
				_setConnectionProperty(FlowID, connection2, "toPart", "HEAD")  ;connect to head
		}
	}
	else
		_deleteConnectionProperty(FlowID, connection2, "toPart")  ; Delete part information if set
	

	local elementType := _getElementProperty(FlowID, newElement, "Type")
	local connection2fromPart := _getElementProperty(FlowID, connection2, "fromPart")
	local connection1toPart := _getElementProperty(FlowID, connection1, "toPart")

	if (elementType = "Loop") ;If user pulled to a loop, assign parts
	{
		if newElementCreated ;If a new one was created, define default parts
		{
			_setConnectionProperty(FlowID, connection1, "toPart", "HEAD")
			_setConnectionProperty(FlowID, connection2, "fromPart", "TAIL")
		}
		else ;If user has pulled to an existing loop, decide depending on which part he dropped it
		{
			if (Connection1!="" and Connection2!="") ;assign default if both connections exist
			{
				_setConnectionProperty(FlowID, connection1, "toPart", "HEAD")
				_setConnectionProperty(FlowID, connection2, "fromPart", "TAIL")
			}
			else
			{
				if (NewElementPart=1 or NewElementPart=2) 
				{
					_setConnectionProperty(FlowID, connection1, "toPart", "HEAD")
					_setConnectionProperty(FlowID, connection2, "fromPart", "HEAD")
				}
				else if (NewElementPart=3) 
				{
					_setConnectionProperty(FlowID, connection1, "toPart", "TAIL")
					_setConnectionProperty(FlowID, connection2, "fromPart", "TAIL")
				}
				else if (NewElementPart=4) 
				{
					_setConnectionProperty(FlowID, connection1, "toPart", "BREAK" )
					_setConnectionProperty(FlowID, connection2, "fromPart", "TAIL")
				}
			}
		}
	}
	else ;if not, delete part informations, if any
	{
		_deleteConnectionProperty(FlowID, Connection1, "toPart")
		_deleteConnectionProperty(FlowID, Connection2, "fromPart")
	}

	
	local element1Type := _getElementProperty(FlowID, Element1, "Type")
	local connection1fromPart := _getElementProperty(FlowID, connection1, "fromPart")
	if (element1Type = "Loop") ;If the first element is a loop
	{
		if (not connection1fromPart) ;If no part assigned to connection
		{
			_setConnectionProperty(FlowID, connection1, "fromPart", "TAIL") ;connect to tail
		}
	}
	else
		_deleteConnectionProperty(FlowID, Connection2, "topart") ;Delete part information if set
	
	;Check whether a connection already exists
	Loop 2
	{
		if (a_index=1)
			tempElement:=Connection1
		else
			tempElement:=Connection2

		local Conneection1Type := _getConnectionProperty(FlowID, Connection1, "ConnectionType")
		local Conneection2Type := _getConnectionProperty(FlowID, Connection2, "ConnectionType")
		local Conneection1From := _getConnectionProperty(FlowID, Connection1, "from")
		local Conneection2From := _getConnectionProperty(FlowID, Connection2, "from")
		local Conneection1To := _getConnectionProperty(FlowID, Connection1, "to")
		local Conneection2To := _getConnectionProperty(FlowID, Connection2, "to")

		local forIndex, forConnectionID
		for forIndex, forConnectionID in _getAllConnectionIds(FlowID)
		{
			if (forConnectionID != tempElement)
			{
				local forConnectionFrom := _getConnectionProperty(FlowID, tempElement, "from")
				local forConnectionTo := _getConnectionProperty(FlowID, tempElement, "from")

				if (Conneection1From = forConnectionFrom and Conneection1To = forConnectionTo )
				{
					local forConnectionType := _getConnectionProperty(FlowID, tempElement, "ConnectionType")

					if (Conneection1Type = forConnectionType)
					{
						msgbox,% lang("This_Connection_Already_Exists!")
						abortAddingElement:=true
					}
				}

				if (Conneection2From = forConnectionFrom and Conneection2To = forConnectionTo )
				{
					local forConnectionType := _getConnectionProperty(FlowID, tempElement, "ConnectionType")

					if (Conneection2Type = forConnectionType)
					{
						msgbox,% lang("This_Connection_Already_Exists!")
						abortAddingElement:=true
					}
				}
			}
		}
		
	}
	
	return

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