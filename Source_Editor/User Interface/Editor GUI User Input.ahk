
goto,jumpoverclickstuff

ui_leftmousebuttonclick:
ui_rightmousebuttonclick:
IfWinnotActive,% "ahk_id " _MainGuihwnd
{
	return
}

CoordMode,mouse,client
MouseGetPos,mx,my,temphwnd

if a_thislabel =ui_rightmousebuttonclick
{
	if workingOnClick
		if (ui_detectMovement(,"rbutton"))
			ui_scrollwithMouse("rbutton")
		else
			UserClickedRbutton:=true
	else
		ui_scrollwithMouse("rbutton")
}
else
{
	SetTimer,clickonpicture,-1 ;Go to label clickonpicture in order to react on user click.
}

return

ui_leftmousebuttondoubleclick:

UserDidMajorChange:=false
UserDidMinorChange:=false
UserCancelledAction:=false

if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
tempMarkedElement := _getFlowProperty(FlowID, "markedElement")
if (tempMarkedElement != "") ;if a single element is marked
{
	
	if instr(tempMarkedElement, "connection")
	{
		ret:=selectConnectionType(tempMarkedElement,"wait") ;Change connection type
		if ret=aborted
			UserCancelledAction:=true
		else
			UserDidMajorChange:=true
		if (ret!="aborted")
		{
			State_New(FlowID) ;make a new state. If user presses Ctrl+Z, the change will be undone
		}
		
	}
	else
	{
		ret:=ElementSettings.open(tempMarkedElement,"wait") ;open settings of the marked element
		if ret=aborted
			UserCancelledAction:=true
		else
			UserDidMajorChange:=true
		if (ret!="aborted" and ret!="0 changes" )
		{
			State_New(FlowID) ;make a new state. If user presses Ctrl+Z, the change will be undone
		}
	}
	
}
tempList:=""
goto,endworkingOnClick
return

clickOnPicture: ;react on clicks of the user



if (workingOnClick=true) ;Ignore if a click of user is already processed
	return
workingOnClick:=true


MouseGetPos,mx,my ;Get the mouse position
GetKeyState,ControlKeyState,control

UserDidMajorChange:=false
UserDidMinorChange:=false
UserCancelledAction:=false

markedElement := _getFlowProperty(FlowID, "markedElement")
markedElements := _getFlowProperty(FlowID, "markedElements")

clickedElement:=ui_findElementUnderMouse()
;~ d(clickedElement)
if ( clickedElement="") ;If nothing was selected (click on nowhere). -> Scroll
{
	
	;~ MsgBox %clickMoved% %CurrentlyMainGuiIsDisabled%
	if (ui_detectMovement()=false) ;If the background wasn't moved, unmark elements.
	{
		if (CurrentlyMainGuiIsDisabled=false)
		{
			if (markedElements.count()) ;if at least one element is marked
			{
				if (ControlKeyState!="d")
				{
					UnmarkEverything()
					ui_UpdateStatusbartext()
				}
			}
		}
		else  ;Ignore if GUI is disable
		{
			ui_ActionWhenMainGUIDisabled()
		}
	}
	else
	{
		ui_scrollwithMouse()
	}
	
}
else if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	
}
else if (clickedElement="MenuCreateNewAction" or clickedElement="MenuCreateNewCondition" or clickedElement="MenuCreateNewLoop" or clickedElement="MenuCreateNewTrigger") ;User click either on "Create new action" or ".. condtion" in the drawn menu
{
	;~ ToolTip %clickedElement%
	if (clickedElement="MenuCreateNewAction")
		tempNew:=Element_New(FlowID, "action")
	else if (clickedElement="MenuCreateNewCondition")
		tempNew:=Element_New(FlowID, "Condition")
	else if (clickedElement="MenuCreateNewLoop")
		tempNew:=Element_New(FlowID, "Loop")
	else if (clickedElement="MenuCreateNewTrigger")
		tempNew:=Element_New(FlowID, "Trigger")
	else
	{
		MsgBox unexpected internal ERROR! A new element should be created. But I don't known which one!
		return 
	}
	
	;function ui_moveSelectedElements() needs the following four lines of code
	clickedElement:=tempNew
	
	tempZoomFactor := _getFlowProperty(FlowID, "flowSettings.zoomfactor")
	tempOffsetX := _getFlowProperty(FlowID, "flowSettings.offsetx")
	tempOffsetY := _getFlowProperty(FlowID, "flowSettings.offsety")
	_setElementProperty(FlowID, clickedElement, "x", (mx)/tempZoomFactor + tempOffsetX - default_ElementWidth/2)
	_setElementProperty(FlowID, clickedElement, "x", (my)/tempZoomFactor + tempOffsetY - default_ElementHeight/2)

	MarkOne(clickedElement)
	if (ui_detectMovement()) ;If user moves the mouse
	{
		ret:=ui_moveSelectedElements() ;move the element. Stop moving when user releases the mouse button
	}
	else
	{
		ret:=ui_moveSelectedElements("InvertLbutton") ;move the element. Stop moving when user clicks
	}
	if (ret.Aborted) ;if user cancelled movement
	{
		UserCancelledAction:=true
	}
	else
	{
		ret:=selectSubType(clickedElement,"wait")
		if ret=aborted
		{
			UserCancelledAction:=true
		}
		else
		{
			ret:=ElementSettings.open(clickedElement,"wait") ;open settings of element
			;~ MsgBox % strobj(tempnew)
			if ret=aborted
			{
				UserCancelledAction:=true
			}
			else
				UserDidMajorChange:=true
		}
	}
	
	
	;e_CorrectElementErrors("Code: 3053165186.")
}
else if (clickedElement="PlusButton" or clickedElement="PlusButton2") ;user click on plus button
{
	IfInString,markedElement,Connection ;The selected element is connection
	{
		tempConnection2:=Connection_New(FlowID) ;Create new connection
		
		tempFrom := _getConnectionProperty(FlowID, markedElement, "from")
		tempTo := _getConnectionProperty(FlowID, markedElement, "to")
		ret:=ui_MoveConnection(markedElement,tempConnection2, tempFrom, tempTo)
		if ret=aborted
			UserCancelledAction:=true
		else 
			UserDidMajorChange:=true
	}
	else ;The selected element is either action, condition or trigger or loop
	{
		tempConnection1:=Connection_New(FlowID) ;Create new connection
		
		tempType := _getElementProperty(FlowID, markedElement, "type")
		if (tempType = "loop")
		{
			if (clickedElement="PlusButton")
			{
				_setConnectionProperty(FlowID, tempConnection1, "frompart", "HEAD")
			}
			else if (clickedElement="PlusButton2")
			{
				_setConnectionProperty(FlowID, tempConnection1, "frompart", "TAIL")
			}
		}
		
		ret:=ui_MoveConnection(tempConnection1, ,markedElement )
		if ret=aborted
			UserCancelledAction:=true
		else 
			UserDidMajorChange:=true
		
	}
	
	
	;e_CorrectElementErrors("Code: 2389423789.")
	;ElementSettings.new(clickedElement) ;open settings of element
	
}
else if (clickedElement="MoveButton1") ;if a connection is selected and user moved the upper Part of it
{
	
	tempTo := _getConnectionProperty(FlowID, markedElement, "to")

	ret:=ui_MoveConnection(,markedElement ,,tempTo )
	if ret=aborted
		UserCancelledAction:=true
	else 
		UserDidMajorChange:=true
	
	

	
	;e_CorrectElementErrors("Code: 3186165186456.")
	;~ API_Draw_Draw(FlowID)

}
else if (clickedElement="MoveButton2") ;if a connection is selected and user moved the lower Part of it
{
	
	tempFrom := _getConnectionProperty(FlowID, markedElement, "from")
	ret:=ui_MoveConnection(markedElement ,,tempFrom )
	if ret=aborted
		UserCancelledAction:=true
	else
		UserDidMajorChange:=true
	
	
	
	
	;e_CorrectElementErrors("Code: 1365415616.")
	;~ API_Draw_Draw(FlowID)
	
	

}
else if (clickedElement="TrashButton") ;if something is selected and user clicks on the trash button
{
	
	if markedElement contains connection
	{
		tempType := _getConnectionProperty(FlowID, markedElement, "type")

		MsgBox, 4, % lang("Delete Object") , % lang("Do you really want to delete the %1%?", tempType, "`n")
	}
	else
	{
		tempType := _getElementProperty(FlowID, markedElement, "type")
		tempName := _getElementProperty(FlowID, markedElement, "name")
		
		MsgBox, 4, % lang("Delete Object") , % lang("Do you really want to delete the %1% %2%?",lang(tempType), "`n" tempName "`n")
	}
	
	IfMsgBox yes
	{
		Element_Remove(FlowID, markedElement)
		UserDidMajorChange:=true
	}
	CreateMarkedList()
	;~ API_Draw_Draw(FlowID)
	;e_CorrectElementErrors("Code: 231684866.")
}
else if (clickedElement="EditButton")  ;if something is selected and user clicks on the edit button
{
	if markedElement contains connection
	{
		ret:=selectConnectionType(markedElement,"wait")
		if ret=aborted
			UserCancelledAction:=true
		else
			UserDidMajorChange:=true
		
	}
	else
	{
		ret:=ElementSettings.open(markedElement,"wait") ;open settings of the marked element
		
		if (ret="aborted" )
			UserCancelledAction:=true
		else if (ret!="0 changes" )
			UserDidMajorChange:=true
	}
	

}
else if (clickedElement="SwitchOnButton")  ;if something is selected and user clicks on the button
{
	
	disableOneTrigger(FlowID, markedElement)
	

}
else if (clickedElement="SwitchOffButton")  ;if something is selected and user clicks on the button
{
	enableOneTrigger(FlowID, markedElement)

}
else if (clickedElement="StarEmptyButton")  ;if something is selected and user clicks on the button
{
	Element_setDefaultTrigger(FlowID, markedElement)
	UserDidMinorChange:=true
}
else if (clickedElement="StarFilledButton")  ;if something is selected and user clicks on the button
{
	;Nothing to do

}
else if (clickedElement!="") ;if user clicked on an element
{
	if markedElement contains connection
	{
		if (ControlKeyState="d")
		{
			MarkOne(clickedElement,true)  ;mark multiple elements
			
		}
		else
			MarkOne(clickedElement) ;mark one element and unmark others
		
	}
	else
	{
		if (!ui_detectMovement()) ;If user did not move the mouse
		{	
			if (ControlKeyState="d") ;if user presses Control key
			{
				MarkOne(clickedElement,true) ;mark multiple elements
			}
			else
				MarkOne(clickedElement) ;mark one element and unmark others
		}
		else ;If user moves the mouse
		{
			if (markedElementWithLowestPriority!="") ;If the element under the mouse is already marked
				ret:=ui_moveSelectedElements() ;move the elements
			else if ((ControlKeyState!="d")) ;if no elements are marked and user does not press the control key
			{
				MarkOne(clickedElement) ;select the element (and unselect others)
				ret:=ui_moveSelectedElements() ;Move it
			}
			else
			{
				MarkOne(clickedElement,true) ;select the element (additionally to others)
				ret:=ui_moveSelectedElements() ;Move it
			}
			
			if (ret.moved=true) ;if user actually moved the elements
			{
				UserDidMinorChange:=true
			}
			
			
			
		}
	}
	
	
	
	ui_UpdateStatusbartext()


}

goto, endworkingOnClick
endworkingOnClick:

;Delete temporary vars
tempElement1:=""
tempElement2:=""
tempElement3:=""
tempConnection1:=""
tempConnection2:=""
clickedElement:=""
elementHighestPriority:=""
markedelementWithLowestPriority:=""
markedelementLowestPriority:=""
tempNew:=""
tempOldConnection1from:=""
tempOldConnection1to:=""
tempList:=""

if (UserCancelledAction=true)
{
	State_RestoreCurrent(FlowID)
	CreateMarkedList()
}
else if (UserDidMajorChange or UserDidMinorChange)
{
	State_New(FlowID) ;make a new state. If user presses Ctrl+Z, the change will be undone
}
else if (UserDidMinorChange)
	State_New(FlowID) ;make a new state. If user presses Ctrl+Z, the change will be undone

API_Draw_Draw(FlowID) 
workingOnClick:=false

return


ui_findElementUnderMouse(par_mode="default")
{
	global
	local tempList
	local drawResultFlow, drawResultElement
	local clickPriority, marked
	
	EnterCriticalSection(_cs_shared)
	
	clickedElement:=""
	elementHighestPriority:=""
	MarkedElementWithLowestPriority:=""
	MarkedElementLowestPriority:=""

	drawResultFlow := _getFlowProperty(FlowID, "DrawResult")

	if (par_mode="default")
	{
		
		;look whether user wants to create a new element (click on a field on top left corner)
		if ((0 < mx) and (0 < my) and ((drawResultFlow.NewElementIconWidth * 1.2)  > mx) and ((drawResultFlow.NewElementIconHeight * 1.2) > my))
			clickedElement = MenuCreateNewAction
		if (((drawResultFlow.NewElementIconWidth * 1.2) < mx) and (0 < my) and ((drawResultFlow.NewElementIconWidth * 1.2 * 2)  > mx) and ((drawResultFlow.NewElementIconHeight * 1.2) > my))
			clickedElement = MenuCreateNewCondition
		if (((drawResultFlow.NewElementIconWidth * 1.2 * 2) < mx) and (0 < my) and ((drawResultFlow.NewElementIconWidth * 1.2 * 3)  > mx) and ((drawResultFlow.NewElementIconHeight * 1.2) > my))
			clickedElement = MenuCreateNewLoop
		if (((drawResultFlow.NewElementIconWidth * 1.2 * 3) < mx) and (0 < my) and ((drawResultFlow.NewElementIconWidth * 1.2 * 4)  > mx) and ((drawResultFlow.NewElementIconHeight * 1.2) > my))
			clickedElement = MenuCreateNewTrigger
	

		;~ ToolTip % share.PlusButtonExist " -" drawResultFlow.middlePointOfPlusButtonX
		;~ ToolTip( "gsdd" Sqrt((middlePointOfPlusButtonX - mx)*(middlePointOfPlusButtonX - mx) + (middlePointOfPlusButtonY - my)*(middlePointOfPlusButtonY - my)) "`n middlePointOfPlusButtonX " middlePointOfPlusButtonX "`n middlePointOfPlusButtonY " middlePointOfPlusButtonY)
		;Look whether user clicked a button
		if (drawResultFlow.PlusButtonExist=true and Sqrt((drawResultFlow.middlePointOfPlusButtonX - mx) * (drawResultFlow.middlePointOfPlusButtonX - mx) + (drawResultFlow.middlePointOfPlusButtonY - my) * (drawResultFlow.middlePointOfPlusButtonY - my)) < default_SizeOfButtons/2)
			clickedElement = PlusButton
		else if (drawResultFlow.PlusButton2Exist=true and Sqrt((drawResultFlow.middlePointOfPlusButton2X - mx) * (drawResultFlow.middlePointOfPlusButton2X - mx) + (drawResultFlow.middlePointOfPlusButton2Y - my) * (drawResultFlow.middlePointOfPlusButton2Y - my)) < default_SizeOfButtons/2)
			clickedElement = PlusButton2
		else if (drawResultFlow.EditButtonExist=true and Sqrt((drawResultFlow.middlePointOfEditButtonX  - mx) * (drawResultFlow.middlePointOfEditButtonX - mx) + (drawResultFlow.middlePointOfEditButtonY  - my) * (drawResultFlow.middlePointOfEditButtonY  - my)) < default_SizeOfButtons/2)
			clickedElement = EditButton
		else if (drawResultFlow.TrashButtonExist=true and Sqrt((drawResultFlow.middlePointOfTrashButtonX - mx) * (drawResultFlow.middlePointOfTrashButtonX - mx) + (drawResultFlow.middlePointOfTrashButtonY - my) * (drawResultFlow.middlePointOfTrashButtonY - my)) < default_SizeOfButtons/2)
			clickedElement = TrashButton
		else if (drawResultFlow.MoveButton2Exist=true and Sqrt((drawResultFlow.middlePointOfMoveButton2X - mx) * (drawResultFlow.middlePointOfMoveButton2X - mx) + (drawResultFlow.middlePointOfMoveButton2Y - my) * (drawResultFlow.middlePointOfMoveButton2Y - my)) < default_SizeOfButtons/2)
			clickedElement = MoveButton2
		else if (drawResultFlow.MoveButton1Exist=true and Sqrt((drawResultFlow.middlePointOfMoveButton1X - mx) * (drawResultFlow.middlePointOfMoveButton1X - mx) + (drawResultFlow.middlePointOfMoveButton1Y - my) * (drawResultFlow.middlePointOfMoveButton1Y - my)) < default_SizeOfButtons/2)
			clickedElement = MoveButton1		
		else if (drawResultFlow.SwitchOnButtonExist=true and (drawResultFlow.PosOfSwitchOnButtonX1 < mx) and (drawResultFlow.PosOfSwitchOnButtonX2 > mx) and (drawResultFlow.PosOfSwitchOnButtonY1 < my) and (drawResultFlow.PosOfSwitchOnButtonY2 > my) )
			clickedElement = SwitchOnButton	
		else if (drawResultFlow.SwitchOffButtonExist=true and (drawResultFlow.PosOfSwitchOffButtonX1 < mx) and (drawResultFlow.PosOfSwitchOffButtonX2 > mx) and (drawResultFlow.PosOfSwitchOffButtonY1 < my) and (drawResultFlow.PosOfSwitchOffButtonY2 > my) )
			clickedElement = SwitchOffButton		
		else if (drawResultFlow.StarFilledButtonExist=true and (drawResultFlow.PosOfStarFilledButtonX1 < mx) and (drawResultFlow.PosOfStarFilledButtonX2 > mx) and (drawResultFlow.PosOfStarFilledButtonY1 < my) and (drawResultFlow.PosOfStarFilledButtonY2 > my) )
			clickedElement = StarFilledButton	
		else if (drawResultFlow.StarEmptyButtonExist=true and (drawResultFlow.PosOfStarEmptyButtonX1 < mx) and (drawResultFlow.PosOfStarEmptyButtonX2 > mx) and (drawResultFlow.PosOfStarEmptyButtonY1 < my) and (drawResultFlow.PosOfStarEmptyButtonY2 > my) )
			clickedElement = StarEmptyButton
	}
	;~ ToolTip %par_mode% -- %clickedElement%
	;~ d(drawResultFlow, mx "  -  " my " - " Sqrt((drawResultFlow.middlePointOfPlusButtonX - mx) * (drawResultFlow.middlePointOfPlusButtonX - mx) + (drawResultFlow.middlePointOfPlusButtonY - my) * (drawResultFlow.middlePointOfPlusButtonY - my)))
	;search for an element
	if (clickedElement="")
	{
		elementHighestPriority=0 ;The highest priority decides which element will be selected. The priority reduces a little bit when the element was selected, and increases every time the user clicks on it but something else is selected. This way it is possible to click through the elements which overlap each other.
		MarkedElementLowestPriority=100000
		for forElementIndex, forElementID in _getAllElementIds(FlowID)
		{
			drawResultElement:=drawResultFlow.elements[forElementID]
			clickPriority := _getElementProperty(FlowId, forElementID, "ClickPriority")
			marked := _getElementProperty(FlowId, forElementID, "marked")

			Loop % drawResultElement.CountOfParts ;Some elements consist of multiple parts
			{
				;~ ToolTip(strobj(forElement),10000)
				;~ MsgBox %mx% %my%
				if (drawResultElement["part" a_index "x1"] < mx and drawResultElement["part" a_index "y1"] < my and drawResultElement["part" a_index "x2"] > mx and drawResultElement["part" a_index "y2"] > my)
				{
					if (elementHighestPriority < clickPriority) ;Find the element with highest priority
					{
						;~ SoundBeep , % forElement.ClickPriority
						elementHighestPriority:=clickPriority
						partOfclickedElement:=A_Index
						clickedElement:=forElementID
					}
					if (marked = true and MarkedElementLowestPriority > clickPriority) ;Find a marked element with lowest priority
					{
						MarkedElementLowestPriority:=clickPriority
						partOfmarkedElementWithLowestPriority:=A_Index
						MarkedElementWithLowestPriority:=forElementID
					}
					
				}
			}
			if (par_mode="default")
			{
				if (clickPriority < 500 and clickPriority >= 490) ;Increase priority if element has low priority.
				{
					_getAndIncrementElementProperty(FlowID, forElementID, "ClickPriority")
				}
			}
		}
		
		
		if (par_mode="default" and clickedElement != "")
		{
			clickPriority := _getElementProperty(FlowId, clickedElement, "ClickPriority")
			if (clickPriority<=500 and clickPriority >=490) ;reduce the priority of selected element
			{
				_setElementProperty(FlowID, clickedElement, "ClickPriority", 490)
			}
		}
		;msgbox,clickedElement. : clickHighestPriority
	}
	
	
	;search for a connection
	if (par_mode="default" and clickedElement="")
	{
		elementHighestPriority := 0 ;The highest priority decides which element will be selected. The priority reduces a little bit when the element was selected, and increases every time the user clicks on it but something else is selected. This way it is possible to click through the elements whith are beneath each other.
		
		for forElementIndex, forElementID in _getAllConnectionIds(FlowID)
		{
			drawResultElement:=drawResultFlow.elements[forElementID]

			clickPriority := _getElementProperty(FlowId, forElementID, "ClickPriority")

			;~ MsgBox % forID " - " forElement.CountOfParts 
			Loop % drawResultElement.CountOfParts ;Connections consist of multiple parts
			{
				if (drawResultElement["part" a_index "x1"] < mx and drawResultElement["part" a_index "y1"] < my and drawResultElement["part" a_index "x2"] > mx and drawResultElement["part" a_index "y2"] > my)
				{
					if (elementHighestPriority < clickPriority) ;find the element with highest priority
					{
						elementHighestPriority:=clickPriority
						partOfclickedElement:=A_Index
						clickedElement:=forElementID
					}
					
				}
			}
			;~ ToolTip, % forElement.ClickPriority 
			if (clickPriority < 200 and clickPriority >= 190) ;Increase priority if element has low priority. 
			{
				_getAndIncrementConnectionProperty(FlowID, forElementID, "ClickPriority")
			}
		}
		
		_setConnectionProperty(FlowID, clickedElement, "ClickPriority", 190)
		
	}
	
	LeaveCriticalSection(_cs_shared)
	
	return clickedElement
}


ui_moveSelectedElements(option="")
{
	global
	local oldHeightOfVerticalBar, k, clickMoved, howMuchMoved, newmx1, newmy1, newmx, newmy, newposy, newposx
	local forElement, forIndex
	
	local toMoveEelement
	if (markedElementWithLowestPriority != "")
		toMoveEelement := markedElementWithLowestPriority
	else
		toMoveEelement := clickedElement

	;~ ToolTip move %toMoveEelement%
	local MovementAborted := false
	local oldposx := _getElementProperty(FlowID, toMoveEelement, "x") ;Store the old position of the element
	local firstposx := oldposx
	local firstoffsetx := _getFlowProperty(FlowID, "flowSettings.offsetx")
	local firstmx := mx
	local oldposy := _getElementProperty(FlowID, toMoveEelement, "y") ;Store the old position of the element
	local firstposy := oldposy
	local firstoffsety := _getFlowProperty(FlowID, "flowSettings.offsety")
	local firstmy := my
	local elementType := _getElementProperty(FlowID, toMoveEelement, "type") 
	;~ ToolTip move %clickedElement%
	clickMoved:=false
	howMuchMoved:=0
	MovementAborted:=false
	
	UserClickedRbutton:=false
	
	UserCurrentlyMovesAnElement:=true ;Prevents that, if user scroll simultanously, the scroll function will call API_Draw_Draw().
	if (markedElement!= "" && elementType = "loop" && partOfclickedElement>=3) ;If a loop is selected and user moves its tail
	{
		local oldHeightOfVerticalBar := _getElementProperty(FlowID, toMoveEelement, "HeightOfVerticalBar")
		local newHeightOfVerticalBar
		
		UserClickedRbutton:=false
		Loop ;Move element(s)
		{
			
			GetKeyState,k,lbutton,p ;When mouse releases, the element(s) will be fittet to the Grid
			if (option!= "InvertLbutton" and k!="d" or option= "InvertLbutton" and k="d")
			{
				if howMuchMoved>0
				{
					;Fit to grid
					newHeightOfVerticalBar := _getElementProperty(FlowID, toMoveEelement, "HeightOfVerticalBar")
					newHeightOfVerticalBar := ui_FitGridx(newHeightOfVerticalBar)
					_setElementProperty(FlowID, toMoveEelement, "HeightOfVerticalBar", newHeightOfVerticalBar)
					
					if (newHeightOfVerticalBar != oldHeightOfVerticalBar)
						clickMoved:=true
					
					API_Draw_Draw(FlowID)
				}
				
				
				break
				
			}
			if (UserClickedRbutton or getkeystate("esc","P")) ;If user cancels movement, move back
			{
				_setElementProperty(FlowID, toMoveEelement, "HeightOfVerticalBar", oldHeightOfVerticalBar)
				MovementAborted:=true
				API_Draw_Draw(FlowID)
				break
			}
			
			MouseGetPos,newmx,newmy ;get mouse position and calculate the new position of the element
			if (newmx!=oldposx OR newmy!=oldposy) ;If mouse is currently moving
			{
				oldposx:=newmx
				oldposy:=newmy
				local zoomfactor := _getFlowProperty(FlowID, "flowSettings.zoomfactor")
				local offsety := _getFlowProperty(FlowID, "flowSettings.offsety")
				
				newHeightOfVerticalBar := (oldHeightOfVerticalBar + (newmy - my) / zoomfactor) - firstoffsety + offsety
				if (newHeightOfVerticalBar < Gridy*2)
					newHeightOfVerticalBar := Gridy*2
				_setElementProperty(FlowID, toMoveEelement, "HeightOfVerticalBar", newHeightOfVerticalBar)

				howMuchMoved++
				
				API_Draw_Draw(FlowID)
			}
			else ;If mouse is not currently moving
			{
				sleep,10 ;Save processor load
			}
			
		}
		
	}
	else
	{
		local markedElements := _getFlowProperty(FlowID, "markedElements")
		local oldElementsPos := object()

		for forIndex, forElementID in markedElements  ;Preparing to move
		{
			oldElementsPos[forElementID] := Object()
			oldElementsPos[forElementID].x := _getElementProperty(FlowID, forElementID, "x")
			oldElementsPos[forElementID].y := _getElementProperty(FlowID, forElementID, "y")
		}

		UserClickedRbutton:=false
		Loop ;Move element(s)
		{
			
			GetKeyState,k,lbutton,p ;When mouse releases, the element(s) will be fittet to the Grid
			if (option!= "InvertLbutton" and k!="d" or option= "InvertLbutton" and k="d")
			{
				if howMuchMoved>0
				{
					;Fit to grid
					for forIndex, forElementID in markedElements
					{
						newposx := ui_FitGridX(newposx)
						newposy := ui_FitGridX(newposy)
						_setElementProperty(FlowID, forElementID, "x", newposx)
						_setElementProperty(FlowID, forElementID, "y", newposy)
						
						if (oldElementsPos[forElementID].x != newposx or oldElementsPos[forElementID].y != newposy)
							clickMoved:=true
					}
					
					API_Draw_Draw(FlowID)
				}
				
				
				break
				
			}
			if (UserClickedRbutton or getkeystate("esc","P")) ;If user cancels movement, move back
			{
				for forIndex, forElementID in markedElements
				{
					_setElementProperty(FlowID, forElementID, "x", oldElementsPos[forElementID].x)
					_setElementProperty(FlowID, forElementID, "y", oldElementsPos[forElementID].y)
				}
				MovementAborted:=true
				;~ SoundBeep
				API_Draw_Draw(FlowID)
				break
			}
			
			MouseGetPos,newmx,newmy ;get mouse position and calculate the new position of the element
			
			if (newmx!=oldposx OR newmy!=oldposy) ;If mouse is currently moving
			{
				local zoomfactor := _getFlowProperty(FlowID, "flowSettings.zoomfactor")
				local offsetx := _getFlowProperty(FlowID, "flowSettings.offsetx")
				local offsety := _getFlowProperty(FlowID, "flowSettings.offsety")

				oldposx:=newmx
				oldposy:=newmy
				for forIndex, forElementID in markedElements
				{
					newposx:=(oldElementsPos[forElementID].x + (newmx - firstmx) / zoomfactor) - firstoffsetx + offsetx
					newposy:=(oldElementsPos[forElementID].y + (newmy - firstmy) / zoomfactor) - firstoffsety + offsety
					_setElementProperty(FlowID, forElementID, "x", newposx)
					_setElementProperty(FlowID, forElementID, "y", newposy)
					
				}
				
				howMuchMoved++
				API_Draw_Draw(FlowID)
			}
			else ;If mouse is not currently moving
			{
				sleep,10 ;Save processor load
			}
			
			
		}
		
		;~ ToolTip end move
	}
	UserCurrentlyMovesAnElement:=false
	return {moved:clickMoved, HowMuchMoved:howMuchMoved, Aborted: MovementAborted}
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
	return clickMoved
	
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


ui_scrollwithMouse(button="lbutton")
{
	global
	local newmy
	local newmy
	local newposx
	local newposy
	local oldposx
	local oldposy
	local howMuchMoved

	 ;Store the first offset position
	ScrollZoomfactor := _getFlowProperty(FlowID, "flowSettings.zoomfactor")
	ScrollFirstPosx := _getFlowProperty(FlowID, "flowSettings.offsetx")
	ScrollFirstPosy := _getFlowProperty(FlowID, "flowSettings.offsety")

	local mx
	local my
	
	MouseGetPos,mx,my ;Get the mouse position
	
	ScrollFirstmx:=mx
	ScrollFirstmy:=my
	
	ScrollButton:=button
	
	SetTimer,ScrollWithMouseTimer,30
	
	return
	
	ScrollWithMouseTimer:
	;~ SoundBeep 500
	;~ GetKeyState,LbuttonKeyState,%ScrollButton%,p
	if (not getkeystate(ScrollButton))
	{
		ui_UpdateStatusbartext("pos")
		if (UserCurrentlyMovesAnElement!=true)
			API_Draw_Draw(FlowID)
		SetTimer,ScrollWithMouseTimer,off
		return
	}
	
	MouseGetPos,newmx,newmy ;Get mouse position and calculate
	newposx:=(ScrollFirstPosx-(newmx-ScrollFirstmx)/ScrollZoomfactor)
	newposy:=(ScrollFirstPosy-(newmy-ScrollFirstmy)/ScrollZoomfactor)
	
	if (newposx!=ScrollOldPosx OR newposy!=ScrollOldPosy) ;If mouse is moving currently
	{
		;~ SoundBeep 1000
		ScrollOldPosx:=newposx
		ScrollOldPosy:=newposy
		_setFlowProperty(FlowID, "flowSettings.Offsetx", newposx)
		_setFlowProperty(FlowID, "flowSettings.Offsety", newposy)
		
		ui_UpdateStatusbartext("pos")
		if (UserCurrentlyMovesAnElement!=true) ;it is true if user currently pulls something else and scrolls simultanously. Calling API_Draw_Draw() while an other instance of it is interrupted can cause problems
			API_Draw_Draw(FlowID)
		Scrollhasscrolled:=true
		;~ ToolTip scroll
	}
	;~ else
		;~ ToolTip noscroll
	
	
	return
	
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
	UnmarkEverything()
	if (connection1!="")
		markOne(connection1)
	
	if (connection2!="")
		markOne(connection2,true)
	
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
	
	;~ ToolTip(strobj(connection1) "`n`n" strobj(connection2),10000)
	_setFlowProperty(FlowID, "draw.DrawMoveButtonUnderMouse", true)
	
	if (ui_detectMovement()) ;If user moves the mouse
		untilRelease:=true ;move until user releases mouse
	else
		untilRelease:=false ;move untli user clicks
	
	;Wait until user releases the mouse and add an element there
	;The connections follow the mouse
	UserClickedRbutton:=false
	UserCurrentlyMovesAnElement:=true

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
	UserCurrentlyMovesAnElement:=false
	
	_setFlowProperty(FlowID, "draw.DrawMoveButtonUnderMouse", false)
	
	if (abortAddingElement)
		return "aborted"
	
	MouseGetPos,mx,my ;Get the mouse position
	
	
	ui_findElementUnderMouse("OnlyElements") ;Search an element beneath the mouse.
	
	
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
		
		MarkOne(newElement)
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
			markOne(NewElement)
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
for markindex, markelement in _getFlowProperty(FlowID, "markedElements") 
{
	Element_Remove(FlowID, markelement)
}
CreateMarkedList()
;e_CorrectElementErrors("Code: 354546841.")
State_New(FlowID)
ui_UpdateStatusbartext()
API_Draw_Draw(FlowID)
return



;Zoom
ctrl_wheeldown:
IfWinNotActive,% "ahk_id " _MainGuihwnd
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
IfWinNotActive,% "ahk_id " _MainGuihwnd
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
	markedElementscopy := _getFlowProperty(FlowID, "markedElements") 

	for markID, markelement in _getFlowProperty(FlowID, "markedElements") 
	{
		;remove all marked elements
		Element_Remove(FlowID, markelement)
	}
	markedElementscopy:=""
	
	State_New(FlowID)
	ui_UpdateStatusbartext()
	API_Draw_Draw(FlowID)
}
;ToolTip("Control + X pressed")
return

ctrl_c:
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
;ToolTip("Control + C pressed")
SaveToClipboard()
return

ctrl_v:
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
;ToolTip("Control + V pressed")
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
CreateMarkedList()
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
UnmarkEverything()
MarkEverything()
API_Draw_Draw(FlowID)
return



jumpoverclickstuff:
temp=