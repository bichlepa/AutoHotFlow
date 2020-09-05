﻿
goto,jumpoverclickstuff

ui_leftmousebuttonclick:
ui_rightmousebuttonclick:
IfWinnotActive,% "ahk_id " _share.hwnds["editGUI" FlowID]
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
if (FlowObj.markedElement != "") ;if a single element is marked
{
	
	if instr(FlowObj.markedElement, "connection")
	{
		ret:=selectConnectionType(FlowObj.markedElement,"wait") ;Change connection type
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
		ret:=ElementSettings.open(FlowObj.markedElement,"wait") ;open settings of the marked element
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

markedElement:=FlowObj.markedElement

clickedElement:=ui_findElementUnderMouse()
;~ d(clickedElement)
if ( clickedElement="") ;If nothing was selected (click on nowhere). -> Scroll
{
	
	;~ MsgBox %clickMoved% %CurrentlyMainGuiIsDisabled%
	if (ui_detectMovement()=false) ;If the background wasn't moved, unmark elements.
	{
		if (CurrentlyMainGuiIsDisabled=false)
		{
			if (FlowObj.markedElements.count()) ;if at least one element is marked
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
	;~ MsgBox % d(FlowObj.allElements[tempNew],clickedElement )
	
	;function ui_moveSelectedElements() needs the following four lines of code
	clickedElement:=tempNew
	FlowObj.allElements[clickedElement].x := (mx)/FlowObj.flowSettings.zoomfactor + FlowObj.flowSettings.offsetx - default_ElementWidth/2
	FlowObj.allElements[clickedElement].y := (my)/FlowObj.flowSettings.zoomfactor + FlowObj.flowSettings.offsety - default_ElementHeight/2
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
		
		ret:=ui_MoveConnection(markedElement,tempConnection2,allConnections[markedElement].from, allConnections[markedElement].to)
		if ret=aborted
			UserCancelledAction:=true
		else 
			UserDidMajorChange:=true
	}
	else ;The selected element is either action, condition or trigger or loop
	{
		tempConnection1:=Connection_New(FlowID) ;Create new connection
		
		;~ d(FlowObj.allConnections[tempConnection1], tempConnection2)
		
		if (FlowObj.allElements[markedElement].type = "loop")
		{
			if (clickedElement="PlusButton")
			{
				FlowObj.allConnections[tempConnection1].frompart := "HEAD"
			}
			else if (clickedElement="PlusButton2")
			{
				FlowObj.allConnections[tempConnection1].frompart := "TAIL"
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
	
	ret:=ui_MoveConnection(,markedElement ,,allConnections[markedElement].to )
	if ret=aborted
		UserCancelledAction:=true
	else 
		UserDidMajorChange:=true
	
	

	
	;e_CorrectElementErrors("Code: 3186165186456.")
	;~ API_Draw_Draw()

}
else if (clickedElement="MoveButton2") ;if a connection is selected and user moved the lower Part of it
{
	
	ret:=ui_MoveConnection(markedElement ,,allConnections[markedElement].from )
	if ret=aborted
		UserCancelledAction:=true
	else
		UserDidMajorChange:=true
	
	
	
	
	;e_CorrectElementErrors("Code: 1365415616.")
	;~ API_Draw_Draw()
	
	

}
else if (clickedElement="TrashButton") ;if something is selected and user clicks on the trash button
{
	
	if markedElement contains connection
	{

		MsgBox, 4, % lang("Delete Object") , % lang("Do you really want to delete the %1% %2%?",lang (FlowObj.allConnections[FlowObj.markedElement].type), "`n" FlowObj.allConnections[FlowObj.markedElement].name "`n")
	}
	else
	{
		
		MsgBox, 4, % lang("Delete Object") , % lang("Do you really want to delete the %1% %2%?",lang (FlowObj.allElements[FlowObj.markedElement].type), "`n" FlowObj.allElements[FlowObj.markedElement].name "`n")
	}
	
	IfMsgBox yes
	{
		Element_Remove(FlowID, FlowObj.markedElement)
		UserDidMajorChange:=true
	}
	CreateMarkedList()
	;~ API_Draw_Draw()
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
	
	disableOneTrigger(flowObj.id, markedElement)
	

}
else if (clickedElement="SwitchOffButton")  ;if something is selected and user clicks on the button
{
	enableOneTrigger(flowObj.id, markedElement)

}
else if (clickedElement="StarEmptyButton")  ;if something is selected and user clicks on the button
{
	Element_setDefaultTrigger(flowObj.id, markedElement)
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

API_Draw_Draw() 
workingOnClick:=false

return


ui_findElementUnderMouse(par_mode="default")
{
	global
	local tempList
	local drawResults
	
	EnterCriticalSection(_cs_shared)
	
	clickedElement:=""
	elementHighestPriority:=""
	MarkedElementWithLowestPriority:=""
	MarkedElementLowestPriority:=""

	if (par_mode="default")
	{
		
		;look whether user wants to create a new element (click on a field on top left corner)
		if ((0 < mx) and (0 < my) and ((FlowObj.DrawResult.NewElementIconWidth * 1.2)  > mx) and ((FlowObj.DrawResult.NewElementIconHeight * 1.2) > my))
			clickedElement = MenuCreateNewAction
		if (((FlowObj.DrawResult.NewElementIconWidth * 1.2) < mx) and (0 < my) and ((FlowObj.DrawResult.NewElementIconWidth * 1.2 * 2)  > mx) and ((FlowObj.DrawResult.NewElementIconHeight * 1.2) > my))
			clickedElement = MenuCreateNewCondition
		if (((FlowObj.DrawResult.NewElementIconWidth * 1.2 * 2) < mx) and (0 < my) and ((FlowObj.DrawResult.NewElementIconWidth * 1.2 * 3)  > mx) and ((FlowObj.DrawResult.NewElementIconHeight * 1.2) > my))
			clickedElement = MenuCreateNewLoop
		if (((FlowObj.DrawResult.NewElementIconWidth * 1.2 * 3) < mx) and (0 < my) and ((FlowObj.DrawResult.NewElementIconWidth * 1.2 * 4)  > mx) and ((FlowObj.DrawResult.NewElementIconHeight * 1.2) > my))
			clickedElement = MenuCreateNewTrigger
	

		;~ ToolTip % share.PlusButtonExist " -" FlowObj.DrawResult.middlePointOfPlusButtonX
		;~ ToolTip( "gsdd" Sqrt((middlePointOfPlusButtonX - mx)*(middlePointOfPlusButtonX - mx) + (middlePointOfPlusButtonY - my)*(middlePointOfPlusButtonY - my)) "`n middlePointOfPlusButtonX " middlePointOfPlusButtonX "`n middlePointOfPlusButtonY " middlePointOfPlusButtonY)
		;Look whether user clicked a button
		if (FlowObj.DrawResult.PlusButtonExist=true and Sqrt((FlowObj.DrawResult.middlePointOfPlusButtonX - mx) * (FlowObj.DrawResult.middlePointOfPlusButtonX - mx) + (FlowObj.DrawResult.middlePointOfPlusButtonY - my) * (FlowObj.DrawResult.middlePointOfPlusButtonY - my)) < default_SizeOfButtons/2)
			clickedElement = PlusButton
		else if (FlowObj.DrawResult.PlusButton2Exist=true and Sqrt((FlowObj.DrawResult.middlePointOfPlusButton2X - mx) * (FlowObj.DrawResult.middlePointOfPlusButton2X - mx) + (FlowObj.DrawResult.middlePointOfPlusButton2Y - my) * (FlowObj.DrawResult.middlePointOfPlusButton2Y - my)) < default_SizeOfButtons/2)
			clickedElement = PlusButton2
		else if (FlowObj.DrawResult.EditButtonExist=true and Sqrt((FlowObj.DrawResult.middlePointOfEditButtonX  - mx) * (FlowObj.DrawResult.middlePointOfEditButtonX - mx) + (FlowObj.DrawResult.middlePointOfEditButtonY  - my) * (FlowObj.DrawResult.middlePointOfEditButtonY  - my)) < default_SizeOfButtons/2)
			clickedElement = EditButton
		else if (FlowObj.DrawResult.TrashButtonExist=true and Sqrt((FlowObj.DrawResult.middlePointOfTrashButtonX - mx) * (FlowObj.DrawResult.middlePointOfTrashButtonX - mx) + (FlowObj.DrawResult.middlePointOfTrashButtonY - my) * (FlowObj.DrawResult.middlePointOfTrashButtonY - my)) < default_SizeOfButtons/2)
			clickedElement = TrashButton
		else if (FlowObj.DrawResult.MoveButton2Exist=true and Sqrt((FlowObj.DrawResult.middlePointOfMoveButton2X - mx) * (FlowObj.DrawResult.middlePointOfMoveButton2X - mx) + (FlowObj.DrawResult.middlePointOfMoveButton2Y - my) * (FlowObj.DrawResult.middlePointOfMoveButton2Y - my)) < default_SizeOfButtons/2)
			clickedElement = MoveButton2
		else if (FlowObj.DrawResult.MoveButton1Exist=true and Sqrt((FlowObj.DrawResult.middlePointOfMoveButton1X - mx) * (FlowObj.DrawResult.middlePointOfMoveButton1X - mx) + (FlowObj.DrawResult.middlePointOfMoveButton1Y - my) * (FlowObj.DrawResult.middlePointOfMoveButton1Y - my)) < default_SizeOfButtons/2)
			clickedElement = MoveButton1		
		else if (FlowObj.DrawResult.SwitchOnButtonExist=true and (FlowObj.DrawResult.PosOfSwitchOnButtonX1 < mx) and (FlowObj.DrawResult.PosOfSwitchOnButtonX2 > mx) and (FlowObj.DrawResult.PosOfSwitchOnButtonY1 < my) and (FlowObj.DrawResult.PosOfSwitchOnButtonY2 > my) )
			clickedElement = SwitchOnButton	
		else if (FlowObj.DrawResult.SwitchOffButtonExist=true and (FlowObj.DrawResult.PosOfSwitchOffButtonX1 < mx) and (FlowObj.DrawResult.PosOfSwitchOffButtonX2 > mx) and (FlowObj.DrawResult.PosOfSwitchOffButtonY1 < my) and (FlowObj.DrawResult.PosOfSwitchOffButtonY2 > my) )
			clickedElement = SwitchOffButton		
		else if (FlowObj.DrawResult.StarFilledButtonExist=true and (FlowObj.DrawResult.PosOfStarFilledButtonX1 < mx) and (FlowObj.DrawResult.PosOfStarFilledButtonX2 > mx) and (FlowObj.DrawResult.PosOfStarFilledButtonY1 < my) and (FlowObj.DrawResult.PosOfStarFilledButtonY2 > my) )
			clickedElement = StarFilledButton	
		else if (FlowObj.DrawResult.StarEmptyButtonExist=true and (FlowObj.DrawResult.PosOfStarEmptyButtonX1 < mx) and (FlowObj.DrawResult.PosOfStarEmptyButtonX2 > mx) and (FlowObj.DrawResult.PosOfStarEmptyButtonY1 < my) and (FlowObj.DrawResult.PosOfStarEmptyButtonY2 > my) )
			clickedElement = StarEmptyButton
	}
	;~ ToolTip %par_mode% -- %clickedElement%
	;~ d(FlowObj.DrawResult, mx "  -  " my " - " Sqrt((FlowObj.DrawResult.middlePointOfPlusButtonX - mx) * (FlowObj.DrawResult.middlePointOfPlusButtonX - mx) + (FlowObj.DrawResult.middlePointOfPlusButtonY - my) * (FlowObj.DrawResult.middlePointOfPlusButtonY - my)))
	;search for an element
	if (clickedElement="")
	{
		elementHighestPriority=0 ;The highest priority decides which element will be selected. The priority reduces a little bit when the element was selected, and increases every time the user clicks on it but something else is selected. This way it is possible to click through the elements which overlap each other.
		MarkedElementLowestPriority=100000
		for forID, forElement in FlowObj.allElements
		{
			drawResults:=FlowObj.DrawResult.elements[forID]
			Loop % drawResults.CountOfParts ;Some elements consist of multiple parts
			{
				;~ ToolTip(strobj(forElement),10000)
				;~ MsgBox %mx% %my%
				if (drawResults["part" a_index "x1"] < mx and drawResults["part" a_index "y1"] < my and drawResults["part" a_index "x2"] > mx and drawResults["part" a_index "y2"] > my)
				{
					if (elementHighestPriority < forElement.ClickPriority) ;Find the element with highest priority
					{
						;~ SoundBeep , % forElement.ClickPriority
						elementHighestPriority:=forElement.ClickPriority
						partOfclickedElement:=A_Index
						clickedElement:=forID
					}
					if (forElement.marked = true and MarkedElementLowestPriority > forElement.ClickPriority) ;Find a marked element with lowest priority
					{
						MarkedElementLowestPriority:=forElement.ClickPriority
						partOfmarkedElementWithLowestPriority:=A_Index
						MarkedElementWithLowestPriority:=forID
					}
					
				}
			}
			if (par_mode="default")
			{
				if (forElement.ClickPriority<500 and forElement.ClickPriority >=490) ;Increase priority if element has low priority. 
					forElement.ClickPriority++
			}
		}
		
		
		if (par_mode="default" and clickedElement != "")
		{
			if (FlowObj.allElements[clickedElement].ClickPriority<=500 and FlowObj.allElements[clickedElement].ClickPriority >=490) ;reduce the priority of selected element
				FlowObj.allElements[clickedElement].ClickPriority:=490
		}
		;msgbox,clickedElement. : clickHighestPriority
	}
	
	
	;search for a connection
	if (par_mode="default" and clickedElement="")
	{
		elementHighestPriority=0 ;The highest priority decides which element will be selected. The priority reduces a little bit when the element was selected, and increases every time the user clicks on it but something else is selected. This way it is possible to click through the elements whith are beneath each other.
		for forID, forElement in FlowObj.allconnections
		{
			drawResults:=FlowObj.DrawResult.elements[forID]
			;~ MsgBox % forID " - " forElement.CountOfParts 
			Loop % drawResults.CountOfParts ;Connections consist of multiple parts
			{
				if (drawResults["part" a_index "x1"] < mx and drawResults["part" a_index "y1"] < my and drawResults["part" a_index "x2"] > mx and drawResults["part" a_index "y2"] > my)
				{
					if (elementHighestPriority < forElement.ClickPriority) ;find the element with highest priority
					{
						elementHighestPriority:=forElement.ClickPriority
						partOfclickedElement:=A_Index
						clickedElement:=forID
					}
					
				}
			}
			;~ ToolTip, % forElement.ClickPriority 
			if (forElement.ClickPriority<200 and forElement.ClickPriority >=190) ;Increase priority if element has low priority. 
				forElement.ClickPriority++
		}
		
		;~ if (FlowObj.allConnections[clickedElement].ClickPriority<=200 and FlowObj.allConnections[clickedElement].ClickPriority >=190)
		;~ {
			FlowObj.allConnections[clickedElement].ClickPriority:=190
		;~ }
	}
	
	LeaveCriticalSection(_cs_shared)
	
	return clickedElement
}


ui_moveSelectedElements(option="")
{
	global
	local oldHeightOfVerticalBar, k, clickMoved, howMuchMoved, newmx1, newmy1, newmx, newmy, newposy, newposx
	
	local toMoveEelement
	if (markedElementWithLowestPriority!="")
		toMoveEelement:=markedElementWithLowestPriority
	else
		toMoveEelement:=clickedElement
	;~ ToolTip move %toMoveEelement%
	local MovementAborted:=false
	local oldposx:=FlowObj.allElements[toMoveEelement].x ;Store the old position of the element
	local firstposx:=FlowObj.allElements[toMoveEelement].x
	local firstoffsetx:=FlowObj.flowSettings.offsetx
	local firstmx:=mx
	local oldposy:=FlowObj.allElements[toMoveEelement].y
	local firstposy:=FlowObj.allElements[toMoveEelement].y
	local firstoffsety:=FlowObj.flowSettings.offsety
	local firstmy:=my
	;~ ToolTip move %clickedElement%
	clickMoved:=false
	howMuchMoved:=0
	MovementAborted:=false
	
	UserClickedRbutton:=false
	
	UserCurrentlyMovesAnElement:=true ;Prevents that, if user scroll simultanously, the scroll function will call API_Draw_Draw().
	if (markedElement!= "" && FlowObj.allElements[toMoveEelement].type = "loop" && partOfclickedElement>=3) ;If a loop is selected and user moves its tail
	{
		oldHeightOfVerticalBar:=FlowObj.allElements[toMoveEelement].HeightOfVerticalBar
		
		UserClickedRbutton:=false
		Loop ;Move element(s)
		{
			
			GetKeyState,k,lbutton,p ;When mouse releases, the element(s) will be fittet to the Grid
			if (option!= "InvertLbutton" and k!="d" or option= "InvertLbutton" and k="d")
			{
				if howMuchMoved>0
				{
					;Fit to grid
					
					FlowObj.allElements[toMoveEelement].HeightOfVerticalBar:=ui_FitGridx(FlowObj.allElements[toMoveEelement].HeightOfVerticalBar)
					
					if (FlowObj.allElements[toMoveEelement].HeightOfVerticalBar!=oldHeightOfVerticalBar)
						clickMoved:=true
					
					API_Draw_Draw()
				}
				
				
				break
				
			}
			if (UserClickedRbutton or getkeystate("esc","P")) ;If user cancels movement, move back
			{
				
				FlowObj.allElements[toMoveEelement].HeightOfVerticalBar:=oldHeightOfVerticalBar
				MovementAborted:=true
				API_Draw_Draw()
				break
			}
			
			MouseGetPos,newmx,newmy ;get mouse position and calculate the new position of the element
			if (newmx!=oldposx OR newmy!=oldposy) ;If mouse is currently moving
			{
				oldposx:=newmx
				oldposy:=newmy
				newposy:=(firstposy+(newmy-firstmy)/FlowObj.flowSettings.zoomfactor)-firstoffsety+FlowObj.flowSettings.offsety
				
				FlowObj.allElements[toMoveEelement].HeightOfVerticalBar:=(oldHeightOfVerticalBar+(newmy-my)/FlowObj.flowSettings.zoomfactor)-firstoffsety+FlowObj.flowSettings.offsety
				if (FlowObj.allElements[toMoveEelement].HeightOfVerticalBar< Gridy*2)
					FlowObj.allElements[toMoveEelement].HeightOfVerticalBar:= Gridy*2
				howMuchMoved++
				
				API_Draw_Draw()
			}
			else ;If mouse is not currently moving
			{
				sleep,10 ;Save processor load
			}
			
			
			
		}
		
		
	}
	else
	{
		for index, forElement in FlowObj.markedElements  ;Preparing to move
		{
			FlowObj.allElements[forElement].oldx:=FlowObj.allElements[forElement].x
			FlowObj.allElements[forElement].oldy:=FlowObj.allElements[forElement].y
			;~ d(FlowObj.markedElements,ihn)
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
					for index, forElement in FlowObj.markedElements
					{
						
						FlowObj.allElements[forElement].x:=ui_FitGridX(FlowObj.allElements[forElement].x)
						FlowObj.allElements[forElement].y:=ui_FitGridY(FlowObj.allElements[forElement].y)
						
						if ((FlowObj.allElements[forElement].oldx)!=(FlowObj.allElements[forElement].x) or (FlowObj.allElements[forElement].oldy)!=(FlowObj.allElements[forElement].y))
							clickMoved:=true
					}
					
					API_Draw_Draw()
				}
				
				
				break
				
			}
			if (UserClickedRbutton or getkeystate("esc","P")) ;If user cancels movement, move back
			{
				for index, forElement in FlowObj.markedElements
				{
					FlowObj.allElements[forElement].x := FlowObj.allElements[forElement].oldx
					FlowObj.allElements[forElement].y := FlowObj.allElements[forElement].oldy
					
				}
				MovementAborted:=true
				;~ SoundBeep
				API_Draw_Draw()
				break
			}
			
			MouseGetPos,newmx,newmy ;get mouse position and calculate the new position of the element
			
			if (newmx!=oldposx OR newmy!=oldposy) ;If mouse is currently moving
			{
				oldposx:=newmx
				oldposy:=newmy
				for index, forElement in FlowObj.markedElements
				{
					newposx:=(FlowObj.allElements[forElement].oldx+(newmx-firstmx)/FlowObj.flowSettings.zoomfactor) -firstoffsetx + FlowObj.flowSettings.offsetx
					newposy:=(FlowObj.allElements[forElement].oldy+(newmy-firstmy)/FlowObj.flowSettings.zoomfactor) -firstoffsety + FlowObj.flowSettings.offsety
					;~ ToolTip(firstposx " - " newmx " - " mx " - " FlowObj.flowSettings.zoomfactor " - " firstoffsetx " - " FlowObj.flowSettings.offsetx)
					FlowObj.allElements[forElement].x:=(newposx)
					FlowObj.allElements[forElement].y:=(newposy)
					
				}
				
				howMuchMoved++
				API_Draw_Draw()
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
	
	local firstposx:=FlowObj.flowSettings.offsetx ;Store the first offset position
	local firstposy:=FlowObj.flowSettings.offsety
	local mx
	local my
	
	MouseGetPos,mx,my ;Get the mouse position
	
	ScrollFirstPosx:=FlowObj.flowSettings.offsetx
	ScrollFirstPosy:=FlowObj.flowSettings.offsety
	
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
			API_Draw_Draw()
		SetTimer,ScrollWithMouseTimer,off
		return
	}
	
	MouseGetPos,newmx,newmy ;Get mouse position and calculate
	newposx:=(ScrollFirstPosx-(newmx-ScrollFirstmx)/FlowObj.flowSettings.zoomfactor)
	newposy:=(ScrollFirstPosy-(newmy-ScrollFirstmy)/FlowObj.flowSettings.zoomfactor)
	;~ ToolTip % newposx " - " ScrollFirstPosx " - " newmx " - " ScrollFirstmx " - " FlowObj.flowSettings.zoomfactor
	
	if (newposx!=ScrollOldPosx OR newposy!=ScrollOldPosy) ;If mouse is moving currently
	{
		;~ SoundBeep 1000
		ScrollOldPosx:=newposx
		ScrollOldPosy:=newposy
		FlowObj.flowSettings.Offsetx:=newposx
		FlowObj.flowSettings.Offsety:=newposy
		
		ui_UpdateStatusbartext("pos")
		if (UserCurrentlyMovesAnElement!=true) ;it is true if user currently pulls something else and scrolls simultanously. Calling API_Draw_Draw() while an other instance of it is interrupted can cause problems
			API_Draw_Draw()
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
	local newElement, abortAddingElement, ret, untilRelease, tempElement
	local mx2, my2, newElementCreated, NewElementPart
	
	;move elements to mouse
	UnmarkEverything()
	if (connection1!="")
		markOne(connection1)
	
	if (connection2!="")
		markOne(connection2,true)
	
	if (connection2!="")
	{
		FlowObj.allConnections[connection2].from:="MOUSE"
		FlowObj.allConnections[connection2].to:=FlowObj.allElements[element2].id
		if (connection1!="")
			FlowObj.allConnections[connection2].ToPart:=FlowObj.allConnections[connection1].ToPart
	}
	
	if (connection1!="")
	{
		FlowObj.allConnections[connection1].from:=FlowObj.allElements[element1].id
		FlowObj.allConnections[connection1].to:="MOUSE"
	}
	
	;~ ToolTip(strobj(connection1) "`n`n" strobj(connection2),10000)
	
	FlowObj.draw.DrawMoveButtonUnderMouse:=true
	
	if (ui_detectMovement()) ;If user moves the mouse
		untilRelease:=true ;move until user releases mouse
	else
		untilRelease:=false ;move untli user clicks
	
	;Wait until user releases the mouse and add an element there
	;The connections follow the mouse
	UserClickedRbutton:=false
	UserCurrentlyMovesAnElement:=true
	Loop
	{
		;~ SoundBeep
		if (ui_detectMovementWithoutBlocking()) ;check, whether user has moved mouse
			API_Draw_Draw()
		if (untilRelease and !getkeystate("lbutton","P") or !untilRelease and getkeystate("lbutton","P")) ;if user finishes moving
		{
			break
		}
		if ( UserClickedRbutton or getkeystate("esc","P")) ;if user aborts moving
		{
			abortAddingElement:=true
			break
		}
		sleep 10 ;save CPU load
		
	}
	UserCurrentlyMovesAnElement:=false
	
	FlowObj.draw.DrawMoveButtonUnderMouse:=false
	
	if (abortAddingElement)
		return "aborted"
	
	MouseGetPos,mx,my ;Get the mouse position
	
	
	ui_findElementUnderMouse("OnlyElements") ;Search an element beneath the mouse.
	
	
	if (clickedElement="") ;If user pulled the end of the connection to empty space. Create new element
	{
		newElement:=Element_New(FlowID)
		newElementCreated:=true
		
		ret:=selectContainerType(newElement,"wait")
		if (ret="aborted") ;If user did not select the container type
		{
			return "aborted"
		}
		FlowObj.allElements[newElement].x:=(mx)/FlowObj.flowSettings.zoomfactor+FlowObj.flowSettings.offsetx - default_ElementWidth/2
		FlowObj.allElements[newElement].y:=(my)/FlowObj.flowSettings.zoomfactor+FlowObj.flowSettings.offsety  - default_ElementHeight/2
		FlowObj.allElements[newElement].x:=ui_FitGridX(FlowObj.allElements[newElement].x)
		FlowObj.allElements[newElement].y:=ui_FitGridY(FlowObj.allElements[newElement].y)
		
		
		if (connection1!="")
			FlowObj.allConnections[connection1].to:=FlowObj.allElements[newElement].id
		
		if (connection2!="")
			FlowObj.allConnections[connection2].from:=FlowObj.allElements[newElement].id
		
		gosub,ui_MoveConnectionCheckAndCorrect
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
		NewElement:=clickedElement
		NewElementPart:=partOfclickedElement
		newElementCreated:=false
		
		if (connection2!="")
			FlowObj.allConnections[connection2].from:=FlowObj.allElements[newElement].id
		if (connection1!="")
			FlowObj.allConnections[connection1].to:=FlowObj.allElements[newElement].id

		;Check whether Connection is possible
		if (FlowObj.allElements[newElement].Type="Trigger" && connection1)
		{
			Msgbox,% lang("You_cannot_connect_to_trigger!")
			return "aborted"
		}
		if (NewElement=Element1 OR NewElement=Element2)
		{
			Msgbox,% lang("The_Connection_cannot_start_and_end_on_the_same_element!")
			return "aborted"
		}
		
		gosub,ui_MoveConnectionCheckAndCorrect
		if abortAddingElement
			return "aborted"
		
		if (Connection1!="" and Connection2!="") ;if user has split a connection and connected an other element inbetween
			markOne(NewElement)
		;else keep the new or modified connection marked
		
	}
	API_Draw_Draw()
	return
	
	ui_MoveConnectionCheckAndCorrect:
	
	if (Connection1!="") ;If connection 1 exists
	{
		if (FlowObj.allElements[FlowObj.allConnections[connection1].from].Type="Condition" )
		{
			if (FlowObj.allConnections[connection1].connectiontype!="exception" 
				and FlowObj.allConnections[connection1].connectiontype!="no" 
				and FlowObj.allConnections[connection1].connectiontype!="yes") ;if pulled to connection and its type is not exception
			{
				ret:=selectConnectionType(Connection1,"wait")
				if (ret="aborted")
					abortAddingElement := True
			}
		}
		else ;if pulled to anything else, check whether it is normal or exception
		{
			if (FlowObj.allConnections[connection1].connectiontype!="normal" and FlowObj.allConnections[connection1].connectiontype!="exception")
				FlowObj.allConnections[connection1].connectiontype:="normal"
		}
	}
	
	if (Connection2!="") ;If connection 2 exists
	{
		if (FlowObj.allElements[FlowObj.allConnections[connection2].from].Type="Condition")
		{
			if (FlowObj.allConnections[connection2].connectiontype!="exception" 
				and FlowObj.allConnections[connection2].connectiontype!="no" 
				and FlowObj.allConnections[connection2].connectiontype!="yes") ;if pulled to connection and its type is not exception
			{
				ret:=selectConnectionType(Connection2,"wait")
				if (ret="aborted")
					abortAddingElement := True
			}
		}
		else ;if pulled to anything else, check whether it is normal or exception
		{
			if (FlowObj.allConnections[connection2].connectiontype!="normal" and FlowObj.allConnections[connection2].connectiontype!="exception")
				FlowObj.allConnections[connection2].connectiontype:="normal"
		}
	}
	
	
	if (FlowObj.allElements[Element2].Type="Loop") ;If the second element is a loop. The information about the connected part is not yet in the second connection.
	{
		if (not FlowObj.allConnections[connection2].toPart) ;If no part assigned to connection
		{
			if (Connection1!="") ;If a second connection exist. Thus it was previously connected to the loop
				FlowObj.allConnections[connection2].toPart:=FlowObj.allConnections[connection1].toPart
			else
				FlowObj.allConnections[connection2].toPart:="HEAD" ;connect to head
		}
	}
	else
		FlowObj.allConnections[connection2].delete("topart") ;Delete part information if set
	
	if (FlowObj.allElements[newElement].Type="Loop") ;If user pulled to a loop, assign parts
	{
		if newElementCreated ;If a new one was created, define default parts
		{
			FlowObj.allConnections[connection1].toPart:="HEAD" 
			FlowObj.allConnections[connection2].fromPart:="TAIL"
		}
		else ;If user has pulled to an existing loop, decide depending on which part he dropped it
		{
			if (Connection1!="" and Connection2!="") ;assign default if both connections exist
			{
				FlowObj.allConnections[connection1].toPart:="HEAD" 
				FlowObj.allConnections[connection2].fromPart:="TAIL"
			}
			else
			{
				if (NewElementPart=1 or NewElementPart=2) 
				{
					FlowObj.allConnections[connection1].toPart:="HEAD" 
					FlowObj.allConnections[connection2].fromPart:="HEAD"
				}
				else if (NewElementPart=3) 
				{
					FlowObj.allConnections[connection1].toPart:="TAIL" 
					FlowObj.allConnections[connection2].fromPart:="TAIL"
				}
				else if (NewElementPart=4) 
				{
					FlowObj.allConnections[connection1].toPart:="BREAK" 
					FlowObj.allConnections[connection2].fromPart:="TAIL"
				}
			}
		}
	}
	else ;if not, delete part informations, if any
	{
		FlowObj.allConnections[Connection1].delete("topart")
		FlowObj.allConnections[Connection2].delete("fromPart")
	}
	if (FlowObj.allElements[Element1].Type="Loop") ;If the first element is a loop
	{
		if (not FlowObj.allConnections[connection1].fromPart) ;If no part assigned to connection
		{
			d(FlowObj.allConnections[connection1], Element1)
			FlowObj.allConnections[connection1].fromPart:="TAIL" ;connect to tail
		}
	}
	else
		Connection2.delete("topart") ;Delete part information if set
	
	;Check whether a connection already exists
	Loop 2
	{
		if (a_index=1)
			tempElement:=Connection1
		else
			tempElement:=Connection2
		
		EnterCriticalSection(_cs_shared)
		for forID, forElement in FlowObj.allConnections
		{
			;~ d(strobj(tempElement) "`n`n" strobj(forElement), "wait")
			if (forID!=tempElement)
			{
				if (forElement.from=FlowObj.allConnections[tempElement].from and forElement.to=FlowObj.allConnections[tempElement].to )
				{
					if (forElement.ConnectionType = FlowObj.allConnections[tempElement].ConnectionType)
					{
						msgbox,% lang("This_Connection_Already_Exists!")
						abortAddingElement:=true
					}
				}
			}
		}
		
		LeaveCriticalSection(_cs_shared)
		
	}
	
	return

}

#IfWinActive ·AutoHotFlow· Editor ;Hotkeys

esc:
return

del: ;delete marked element
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}

markedElementscopy:=FlowObj.markedElements.clone()
 ;remove all marked elements
for markindex, markelement in markedElementscopy
{
	
	Element_Remove(FlowID, markelement)
	

}
CreateMarkedList()
markedElementscopy:=""
tempList:=""
;e_CorrectElementErrors("Code: 354546841.")
State_New(FlowID)
ui_UpdateStatusbartext()
API_Draw_Draw()
return



;Zoom
ctrl_wheeldown:
IfWinNotActive,% "ahk_id " _share.hwnds["editGUI" FlowID]
	return
;Get the mouse position
MouseGetPos,mx5,my5 


;Get coordinates where the mouse points to
mx5old:=mx5/FlowObj.flowSettings.zoomfactor
my5old:=my5/FlowObj.flowSettings.zoomfactor


;Change zoom factor
zoomFactorOld:=FlowObj.flowSettings.zoomfactor

FlowObj.flowSettings.zoomfactor:=FlowObj.flowSettings.zoomfactor/1.1
if (FlowObj.flowSettings.zoomfactor<default_zoomFactorMin)
{
	FlowObj.flowSettings.zoomfactor:=default_zoomFactorMin
}
;Get new position where the mouse points to
mx5new:=mx5 /FlowObj.flowSettings.zoomfactor
my5new:=my5 /FlowObj.flowSettings.zoomfactor

;Move everything, so the mouse will still point at the same position
FlowObj.flowSettings.offsetx:=  FlowObj.flowSettings.offsetx + mx5old - mx5new 
FlowObj.flowSettings.offsety:= FlowObj.flowSettings.offsety + my5old  - my5new

ui_UpdateStatusbartext("pos")
API_Draw_Draw()

return

ctrl_wheelup:
IfWinNotActive,% "ahk_id " _share.hwnds["editGUI" FlowID]
	return

MouseGetPos,mx5,my5 ;Get the mouse position

;Get coordinates where the mouse points to
mx5old:=mx5/FlowObj.flowSettings.zoomfactor
my5old:=my5/FlowObj.flowSettings.zoomfactor



;Change zoom factor
zoomFactorOld:=FlowObj.flowSettings.zoomfactor

FlowObj.flowSettings.zoomfactor:=FlowObj.flowSettings.zoomfactor*1.1
if (FlowObj.flowSettings.zoomfactor>default_zoomFactorMax)
{
	FlowObj.flowSettings.zoomfactor:=default_zoomFactorMax
}

;Get new position where the mouse points to
mx5new:=mx5/FlowObj.flowSettings.zoomfactor
my5new:=my5/FlowObj.flowSettings.zoomfactor


;Move everything, so the mouse will still point at the same position
;~ ToolTip,% " offsetx " FlowObj.flowSettings.offsetx "% `n mx5old " mx5old " `n mx5new " mx5new

FlowObj.flowSettings.offsetx:=  FlowObj.flowSettings.offsetx + mx5old - mx5new 
FlowObj.flowSettings.offsety:= FlowObj.flowSettings.offsety + my5old  - my5new
ui_UpdateStatusbartext("pos")

API_Draw_Draw()

return


ctrl_x:
ret := SaveToClipboard()
if ret=0
{ ;Delete all marked elements
	markedElementscopy:=FlowObj.markedElements.clone()

	for markID, markelement in markedElementscopy
	{
		if (markelement.type="trigger" or markelement.type="connection")
		{
			continue
		}
		else ;remove all marked elements
		{
			Element_Remove(FlowID, markelement)
		}
	}
	markedElementscopy:=""
	
	State_New(FlowID)
	ui_UpdateStatusbartext()
	API_Draw_Draw()
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
API_Draw_Draw()
return
ctrl_y:
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
State_Redo(FlowID)
API_Draw_Draw()
return

ctrl_a:
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
UnmarkEverything()
MarkEverything()
API_Draw_Draw()
return



jumpoverclickstuff:
temp=