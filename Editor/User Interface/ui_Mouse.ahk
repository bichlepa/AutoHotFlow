
goto,jumpoverclickstuff

leftmousebuttonclick:
rightmousebuttonclick:

IfWinnotActive,% "ahk_id " maingui.hwnd
{
	return
}

thread, Priority, -50 ;TODO

CoordMode,mouse,client
MouseGetPos,mx,my,temphwnd

if a_thislabel =rightmousebuttonclick
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

leftmousebuttondoubleclick:
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
if (theOnlyOneMarkedElement) ;if a single element is marked
{
	if (theOnlyOneMarkedElement.type="connection")
	{
		ret:=selectConnectionType(theOnlyOneMarkedElement,"wait") ;Change connection type
		if (ret!="aborted")
		{
			new state() ;make a new state. If user presses Ctrl+Z, the change will be undone
		}
		
	}
	else
	{
		ret:=ElementSettings.open(theOnlyOneMarkedElement,"wait") ;open settings of the marked element
		if (ret!="aborted" and ret!="0 changes" )
		{
			new state() ;make a new state. If user presses Ctrl+Z, the change will be undone
		}
	}
	
}
return

clickOnPicture: ;react on clicks of the user



if (workingOnClick=true) ;Ignore if a click of user is already processed
	return
workingOnClick:=true

thread, Priority, -50 ;TODO

MouseGetPos,mx,my ;Get the mouse position
GetKeyState,ControlKeyState,control

UserDidMajorChange:=false
UserDidMinorChange:=false
UserCancelledAction:=false

elementWithHighestPriority:=ui_findElementUnderMouse()



if ( elementWithHighestPriority="") ;If nothing was selected (click on nowhere). -> Scroll
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
					element.unmarkAll()
					ui_draw()
				}
			}
		}
		else  ;Ignore if GUI is disable
			ui_ActionWhenMainGUIDisabled()
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
else if (elementWithHighestPriority="MenuCreateNewAction" or elementWithHighestPriority="MenuCreateNewCondition" or elementWithHighestPriority="MenuCreateNewLoop") ;User click either on "Create new action" or ".. condtion" in the drawn menu
{

	if (elementWithHighestPriority="MenuCreateNewAction")
		tempNew:=New element("action")
	else if (elementWithHighestPriority="MenuCreateNewCondition")
		tempNew:=New element("Condition")
	else
		tempNew:=New element("Loop")
	;~ MsgBox % strobj(tempnew)
	
	;function ui_moveSelectedElements() needs the following four lines of code
	elementWithHighestPriority:=tempNew
	tempNew.x:=(mx)/zoomfactor+offsetx - ElementWidth/2
	tempNew.y:=(my)/zoomfactor+offsety  - ElementHeight/2
	tempNew.mark()
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
		ret:=selectSubType(tempNew,"wait")
		if ret=aborted
		{
			UserCancelledAction:=true
		}
		else
		{
			ret:=ElementSettings.open(tempNew,"wait") ;open settings of element
			;~ MsgBox % strobj(tempnew)
			if ret=aborted
			{
				UserCancelledAction:=true
			}
			else
				UserDidMajorChange:=true
		}
	}
	
	if (UserCancelledAction=true)
		currentState.restore()
	else
		UserDidMajorChange:=true
	
	ui_draw()
	;e_CorrectElementErrors("Code: 3053165186.")
}
else if (elementWithHighestPriority="PlusButton" or elementWithHighestPriority="PlusButton2") ;user click on plus button
{
	
	if (TheOnlyOneMarkedElement.type="Connection") ;The selected element is connection
	{
		tempConnection2:=New Connection() ;Create new connection
		
		ret:=ui_MoveConnection(TheOnlyOneMarkedElement,tempConnection2,allelements[TheOnlyOneMarkedElement.from], allelements[TheOnlyOneMarkedElement.to])
		if ret=aborted
			UserCancelledAction:=true
	}
	else ;The selected element is either action, condition or trigger or loop
	{
		tempConnection1:=New Connection()
		ret:=ui_MoveConnection(tempConnection1, ,TheOnlyOneMarkedElement )
		if ret=aborted
			UserCancelledAction:=true
		
	}
	
	
	
	if (UserCancelledAction=true)
	{
		;~ d(currentstate,1)
		currentState.restore()
		ui_draw()
	}
	else
		UserDidMajorChange:=true
	
	
	;e_CorrectElementErrors("Code: 2389423789.")
	;ElementSettings.new(elementWithHighestPriority) ;open settings of element
	
}
else if (elementWithHighestPriority="MoveButton1") ;if a connection is selected and user moved the upper Part of it
{
	
	ret:=ui_MoveConnection(,TheOnlyOneMarkedElement ,,allelements[TheOnlyOneMarkedElement.to] )
	if ret=aborted
		UserCancelledAction:=true
	
	
	if (UserCancelledAction=true)
	{
		;~ d(currentstate,1)
		currentState.restore()
		ui_draw()
	}
	else
		UserDidMajorChange:=true
	

	
	;e_CorrectElementErrors("Code: 3186165186456.")
	;~ ui_draw()

}
else if (elementWithHighestPriority="MoveButton2") ;if a connection is selected and user moved the lower Part of it
{
	abortAddingElement:=false
	
	ret:=ui_MoveConnection(TheOnlyOneMarkedElement ,,allelements[TheOnlyOneMarkedElement.from] )
	if ret=aborted
		UserCancelledAction:=true
	
	
	if (UserCancelledAction=true)
	{
		;~ d(currentstate,1)
		currentState.restore()
		ui_draw()
	}
	else
		UserDidMajorChange:=true
	
	
	
	
	
	;e_CorrectElementErrors("Code: 1365415616.")
	;~ ui_draw()
	
	

}
else if (elementWithHighestPriority="TrashButton") ;if something is selected and user clicks on the trash button
{
	MsgBox, 4, % lang("Delete Object") , % lang("Do you really want to delete the %1% %2%?",lang (TheOnlyOneMarkedElement.type), TheOnlyOneMarkedElement.name)
	IfMsgBox yes
	{
		TheOnlyOneMarkedElement.remove()
		UserDidMajorChange:=true
	}
	
	;~ ui_draw()
	;e_CorrectElementErrors("Code: 231684866.")
}
else if (elementWithHighestPriority="EditButton")  ;if something is selected and user clicks on the edit button
{
	
	if (theOnlyOneMarkedElement.type="connection")
	{
		ret:=selectConnectionType(theOnlyOneMarkedElement,"wait")
		if (ret!="aborted")
			UserDidMajorChange:=true
		
	}
	else
	{
		ret:=ElementSettings.open(theOnlyOneMarkedElement,"wait") ;open settings of the marked element
		if (ret!="aborted" and ret!="0 changes" )
			UserDidMajorChange:=true
	}
	

}
else if (IsObject(elementWithHighestPriority)) ;if user clicked on an element
{
	

	if (elementWithHighestPriority.type="connection")
	{
		if (ControlKeyState="d")
		{
			elementWithHighestPriority.mark(true) ;mark multiple elements
			
		}
		else
			elementWithHighestPriority.mark() ;mark one element and unmark others
		ui_draw() 
		
	}
	else
	{
		
		
		if (!ui_detectMovement()) ;If user did not move the mouse
		{	
			
			if (ControlKeyState="d") ;if user presses Control key
			{
				
				elementWithHighestPriority.mark(true) ;mark multiple elements
				
			}
			else
				elementWithHighestPriority.mark() ;mark one element and unmark others
			ui_draw() 
		}
		else ;If user moves the mouse
		{
			if (markedElementWithLowestPriority!="") ;If the element under the mouse is already marked
				ret:=ui_moveSelectedElements() ;move the elements
			else if ((ControlKeyState!="d")) ;if no elements are marked and user does not press the control key
			{
				elementWithHighestPriority.mark() ;select the element (and unselect others)
				ret:=ui_moveSelectedElements() ;Move it
			}
			else
			{
				elementWithHighestPriority.mark(true) ;select the element (additionally to others)
				ret:=ui_moveSelectedElements() ;Move it
			}
			
			if (ret.moved=true) ;if user actually moved the elements
			{
				UserDidMinorChange:=true
			}
			
			
			ui_draw() 
		}
	}
	
	
	
	
	
	
	
	
	ui_UpdateStatusbartext()


}

;Delete temporary vars
tempElement1:=""
tempElement2:=""
tempElement3:=""
tempConnection1:=""
tempConnection2:=""
elementWithHighestPriority:=""
elementHighestPriority:=""
markedelementWithLowestPriority:=""
markedelementLowestPriority:=""
tempNew:=""
tempOldConnection1from:=""
tempOldConnection1to:=""

if (UserDidMajorChange or UserDidMinorChange)
{
	new state() ;make a new state. If user presses Ctrl+Z, the change will be undone
}
else if (UserDidMinorChange)
	new state() ;make a new state. If user presses Ctrl+Z, the change will be undone
	
workingOnClick:=false

return


ui_findElementUnderMouse(par_mode="default")
{
	global
	
	elementWithHighestPriority:=""
	elementHighestPriority:=""
	MarkedElementWithLowestPriority:=""
	MarkedElementLowestPriority:=""
	
	if (par_mode="default")
	{
		;look whether user wants to create a new element (click on a field on top left corner)
		if ((0 < mx) and (0 < my) and ((NewElementIconWidth*1.2*zoomFactor)  > mx) and ((NewElementIconHeight*1.2*zoomFactor) > my))
			elementWithHighestPriority=MenuCreateNewAction
		if (((NewElementIconWidth*1.2*zoomFactor) < mx) and (0 < my) and ((NewElementIconWidth*1.2 * 2*zoomFactor)  > mx) and ((NewElementIconHeight*1.2*zoomFactor) > my))
			elementWithHighestPriority=MenuCreateNewCondition
		if (((NewElementIconWidth*2.4*zoomFactor) < mx) and (0 < my) and ((NewElementIconWidth*1.2 * 3*zoomFactor)  > mx) and ((NewElementIconHeight*1.2*zoomFactor) > my))
			elementWithHighestPriority=MenuCreateNewLoop
	


		;ToolTip( "gsdd" Sqrt((middlePointOfPlusButtonX*zoomFactor - mx)*(middlePointOfPlusButtonX*zoomFactor - mx) + (middlePointOfPlusButtonY*zoomFactor - my)*(middlePointOfPlusButtonY*zoomFactor - my)) "`n middlePointOfPlusButtonX " middlePointOfPlusButtonX "`n middlePointOfPlusButtonY " middlePointOfPlusButtonY)
		;Look whether user clicked a button
		if (PlusButtonExist=true and Sqrt((middlePointOfPlusButtonX*zoomFactor - mx)*(middlePointOfPlusButtonX*zoomFactor - mx) + (middlePointOfPlusButtonY*zoomFactor - my)*(middlePointOfPlusButtonY*zoomFactor - my)) < SizeOfButtons/2*zoomFactor)
			elementWithHighestPriority=PlusButton
		else if (PlusButton2Exist=true and Sqrt((middlePointOfPlusButton2X*zoomFactor - mx)*(middlePointOfPlusButton2X*zoomFactor - mx) + (middlePointOfPlusButton2Y*zoomFactor - my)*(middlePointOfPlusButton2Y*zoomFactor - my)) < SizeOfButtons/2*zoomFactor)
			elementWithHighestPriority=PlusButton2
		else if (EditButtonExist=true and Sqrt((middlePointOfEditButtonX*zoomFactor - mx)*(middlePointOfEditButtonX*zoomFactor - mx) + (middlePointOfEditButtonY*zoomFactor - my)*(middlePointOfEditButtonY*zoomFactor - my)) < SizeOfButtons/2 *zoomFactor)
			elementWithHighestPriority=EditButton
		else if (TrashButtonExist=true and Sqrt((middlePointOfTrashButtonX*zoomFactor - mx)*(middlePointOfTrashButtonX*zoomFactor - mx) + (middlePointOfTrashButtonY*zoomFactor - my)*(middlePointOfTrashButtonY*zoomFactor - my)) < SizeOfButtons/2*zoomFactor)
			elementWithHighestPriority=TrashButton
		else if (MoveButton2Exist=true and Sqrt((middlePointOfMoveButton2X*zoomFactor - mx)*(middlePointOfMoveButton2X*zoomFactor - mx) + (middlePointOfMoveButton2Y*zoomFactor - my)*(middlePointOfMoveButton2Y*zoomFactor - my)) < SizeOfButtons/2*zoomFactor)
			elementWithHighestPriority=MoveButton2
		else if (MoveButton1Exist=true and Sqrt((middlePointOfMoveButton1X*zoomFactor - mx)*(middlePointOfMoveButton1X*zoomFactor - mx) + (middlePointOfMoveButton1Y*zoomFactor - my)*(middlePointOfMoveButton1Y*zoomFactor - my)) < SizeOfButtons/2*zoomFactor)
			elementWithHighestPriority=MoveButton1
	}

	;search for an element
	if (elementWithHighestPriority="")
	{
		elementHighestPriority=0 ;The highest priority decides which element will be selected. The priority reduces a little bit when the element was selected, and increases every time the user clicks on it but something else is selected. This way it is possible to click through the elements whith are beneath each other.
		MarkedElementLowestPriority=100000
		for index, forElement in allElements
		{
			
			Loop % forElement.CountOfParts ;Connections consist of multiple parts
			{
				;~ ToolTip(strobj(forElement),10000)
				;~ MsgBox %mx% %my%
				if (forElement["part" a_index "x1"] < mx and forElement["part" a_index "y1"] < my and forElement["part" a_index "x2"] > mx and forElement["part" a_index "y2"] > my)
				{
					if (elementHighestPriority < forElement.ClickPriority) ;Find the element with highest priority
					{
						;~ SoundBeep , % forElement.ClickPriority
						elementHighestPriority:=forElement.ClickPriority
						partOfElementWithHighestPriority:=A_Index
						elementWithHighestPriority:=forElement
					}
					if (forElement.marked = true and MarkedElementLowestPriority > forElement.ClickPriority) ;Find a marked element with lowest priority
					{
						MarkedElementLowestPriority:=forElement.ClickPriority
						partOfmarkedElementWithLowestPriority:=A_Index
						MarkedElementWithLowestPriority:=forElement
					}
					if (par_mode="default")
					{
						if (forElement.ClickPriority<500 and forElement.ClickPriority >=490) ;Increase priority if element has low priority. 
							forElement.ClickPriority++
					}
				}
			}
		}
		if (par_mode="default")
		{
			if (elementWithHighestPriority.ClickPriority<=500 and elementWithHighestPriority.ClickPriority >=490) ;reduce the priority of selected element
				elementWithHighestPriority.ClickPriority:=490
		}
		;msgbox,elementWithHighestPriority. : clickHighestPriority
	}
	
	
	;search for a connection
	if (par_mode="default" and elementWithHighestPriority="")
	{
		elementHighestPriority=0 ;The highest priority decides which element will be selected. The priority reduces a little bit when the element was selected, and increases every time the user clicks on it but something else is selected. This way it is possible to click through the elements whith are beneath each other.
		for index, forElement in allconnections
		{
			Loop % forElement.CountOfParts ;Connections consist of multiple parts
			{
				if (forElement["part" a_index "x1"] < mx and forElement["part" a_index "y1"] < my and forElement["part" a_index "x2"] > mx and forElement["part" a_index "y2"] > my)
				{
					if (elementHighestPriority < forElement.ClickPriority) ;find the element with highest priority
					{
						elementHighestPriority:=forElement.ClickPriority
						partOfElementWithHighestPriority:=A_Index
						elementWithHighestPriority:=forElement
					}
					
					if (forElement.ClickPriority<200 and forElement.ClickPriority >=190) ;Increase priority if element has low priority. 
						forElement.ClickPriority++
				}
			}
		}
		if (elementWithHighestPriority.ClickPriority<=200 and elementWithHighestPriority.ClickPriority >=190)
		{
			elementWithHighestPriority.ClickPriority:=190
		}
	}
	
	return elementWithHighestPriority
}


ui_moveSelectedElements(option="")
{
	global
	local oldHeightOfVerticalBar, k, clickMoved, howMuchMoved, newmx1, newmy1, newmx, newmy, newposy, newposx
	
	local toMoveEelement
	if IsObject(markedElementWithLowestPriority)
		toMoveEelement:=markedElementWithLowestPriority
	else
		toMoveEelement:=elementWithHighestPriority
	
	local MovementAborted:=false
	local oldposx:=toMoveEelement.x ;Store the old position of the element
	local firstposx:=toMoveEelement.x
	local firstoffsetx:=offsetx
	local firstmx:=mx
	local oldposy:=toMoveEelement.y
	local firstposy:=toMoveEelement.y
	local firstoffsety:=offsety
	local firstmy:=my
	
	
	clickMoved:=false
	howMuchMoved:=0
	MovementAborted:=false
	
	UserClickedRbutton:=false
	UserCurrentlyMovesAnElement:=true ;Prevents that, if user scroll simultanously, the scroll function will call ui_draw().
	if (TheOnlyOneMarkedElement!= "" && TheOnlyOneMarkedElement.type = "loop" && partOfElementWithHighestPriority>=3) ;If a loop is selected and user moves its tail
	{
		oldHeightOfVerticalBar:=TheOnlyOneMarkedElement.HeightOfVerticalBar
		
		UserClickedRbutton:=false
		Loop ;Move element(s)
		{
			
			GetKeyState,k,lbutton,p ;When mouse releases, the element(s) will be fittet to the Grid
			if (option!= "InvertLbutton" and k!="d" or option= "InvertLbutton" and k="d")
			{
				if howMuchMoved>0
				{
					;Fit to grid
					
					TheOnlyOneMarkedElement.HeightOfVerticalBar:=ui_FitGridx(TheOnlyOneMarkedElement.HeightOfVerticalBar)
					
					
					ui_draw()
				}
				
				
				break
				
			}
			if (UserClickedRbutton or getkeystate("esc","P")) ;If user cancels movement, move back
			{
				
				TheOnlyOneMarkedElement.HeightOfVerticalBar:=oldHeightOfVerticalBar
				MovementAborted:=true
				ui_draw()
				break
			}
			
			MouseGetPos,newmx,newmy ;get mouse position and calculate the new position of the element
			oldposx:=newmx
			oldposy:=newmy
			if (newmx!=oldposx OR newmy!=oldposy) ;If mouse is currently moving
			{
				newposy:=(firstposy+(newmy-firstmy)/zoomFactor)-firstoffsety+offsety
				
				TheOnlyOneMarkedElement.HeightOfVerticalBar:=(oldHeightOfVerticalBar+(newmy-my)/zoomFactor)-firstoffsety+offsety
				if (TheOnlyOneMarkedElement.HeightOfVerticalBar< Gridy*2)
					TheOnlyOneMarkedElement.HeightOfVerticalBar:= Gridy*2
				howMuchMoved++
				if howMuchMoved>2
					clickMoved:=true
				ui_draw()
			}
			else ;If mouse is not currently moving
			{
				sleep,50 ;Save processor load
			}
			
			
			
		}
		
		
	}
	else
	{
		for index, forElement in markedElements  ;Preparing to move
		{
			forElement.oldx:=forElement.x
			forElement.oldy:=forElement.y
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
					for index, forElement in markedElements
					{
						
						forElement.x:=ui_FitGridX(forElement.x)
						forElement.y:=ui_FitGridY(forElement.y)
						
					}
					
					ui_draw()
				}
				
				
				break
				
			}
			if (UserClickedRbutton or getkeystate("esc","P")) ;If user cancels movement, move back
			{
				for index, forElement in markedElements
				{
					forElement.x:=forElement.oldx
					forElement.y:=forElement.oldy
					
				}
				MovementAborted:=true
				;~ SoundBeep
				ui_draw()
				break
			}
			
			MouseGetPos,newmx,newmy ;get mouse position and calculate the new position of the element
			
			oldposx:=newmx
			oldposy:=newmy
			if (newposx!=oldposx OR newposy!=oldposy) ;If mouse is currently moving
			{
				
				for index, forElement in markedElements
				{
					newposx:=(forElement.oldx+(newmx-firstmx)/zoomFactor) -firstoffsetx + offsetx
					newposy:=(forElement.oldy+(newmy-firstmy)/zoomFactor) -firstoffsety + offsety
					;~ ToolTip(firstposx " - " newmx " - " mx " - " zoomFactor " - " firstoffsetx " - " offsetx)
					forElement.x:=(newposx)
					forElement.y:=(newposy)
					
				}
				
				howMuchMoved++
				if howMuchMoved>2
					clickMoved:=true
				ui_draw()
			}
			else ;If mouse is not currently moving
			{
				sleep,50 ;Save processor load
			}
			
			
			
		}
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
		
		
		sleep,50 ;Save processor load
	}
	return clickMoved
	
}

ui_detectMovementWithoutBlocking(threshold=0)
{
	static yold =0
	static xold =0


	
	
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
	
	local firstposx:=offsetx ;Store the first offset position
	local firstposy:=offsety
	local mx
	local my
	
	MouseGetPos,mx,my ;Get the mouse position
	
	ScrollFirstPosx:=offsetx
	ScrollFirstPosy:=offsety
	
	ScrollFirstmx:=mx
	ScrollFirstmy:=my
	
	ScrollButton:=button
	
	SetTimer,ScrollWithMouseTimer,30
	
	return
	
	ScrollWithMouseTimer:
	
	;~ GetKeyState,LbuttonKeyState,%ScrollButton%,p
	if (not getkeystate(ScrollButton))
	{
		ui_UpdateStatusbartext("pos")
		if (UserCurrentlyMovesAnElement!=true)
			ui_draw()
		SetTimer,ScrollWithMouseTimer,off
		return
	}
	
	MouseGetPos,newmx,newmy ;Get mouse position and calculate
	newposx:=(ScrollFirstPosx-(newmx-ScrollFirstmx)/zoomFactor)
	newposy:=(ScrollFirstPosy-(newmy-ScrollFirstmy)/zoomFactor)
	;~ ToolTip %newposx% - %firstposx% - %newmx% - %ScrollFirstmx% - %zoomFactor%
	if (newposx!=ScrollOldPosx OR newposy!=ScrollOldPosy) ;If mouse is moving currently
	{
		
		ScrollOldPosx:=newposx
		ScrollOldPosy:=newposy
		Offsetx:=newposx
		Offsety:=newposy
		
		ui_UpdateStatusbartext("pos")
		if (UserCurrentlyMovesAnElement!=true) ;it is true if user currently pulls something else and scrolls simultanously. Calling ui_draw() while an other instance of it is interrupted can cause problems
			ui_draw()
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
		element.unmarkall()
		connection1.mark()
		connection2.mark(true)
		connection2.from:="MOUSE"
		connection2.to:=element2.id
		connection2.ToPart:=connection1.ToPart
		
		connection1.from:=element1.id
		connection1.to:="MOUSE"
		
		;~ ToolTip(strobj(connection1) "`n`n" strobj(connection2),10000)
		
		GDI_DrawMoveButtonUnderMouse:=true
		
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
			if (ui_detectMovementWithoutBlocking()) ;check, whether user has moved mouse
				ui_draw()
			if (untilRelease and !getkeystate("lbutton","P") or !untilRelease and getkeystate("lbutton","P")) ;if user finishes moving
			{
				break
			}
			if ( UserClickedRbutton or getkeystate("esc","P")) ;if user aborts moving
			{
				abortAddingElement:=true
				break
			}
			sleep 50 ;save CPU load
			
		}
		UserCurrentlyMovesAnElement:=false
		
		if (abortAddingElement)
			return "aborted"
		
		MouseGetPos,mx,my ;Get the mouse position
		
		
		ui_findElementUnderMouse("OnlyElements") ;Search an element beneath the mouse.
		
		GDI_DrawMoveButtonUnderMouse:=false
		
		if (elementWithHighestPriority="") ;If user pulled the end of the connection to empty space. Create new element
		{
			newElement:=New element()
			newElementCreated:=true
			
			ret:=selectContainerType(newElement,"wait")
			if (ret="aborted") ;If user did not select the container type
			{
				return "aborted"
			}
			newElement.x:=(mx)/zoomfactor+offsetx - ElementWidth/2
			newElement.y:=(my)/zoomfactor+offsety  - ElementHeight/2
			newElement.x:=ui_FitGridX(newElement.x)
			newElement.y:=ui_FitGridY(newElement.y)
			
			
			Connection1.to:=newElement.id
			Connection2.from:=newElement.id
			
			gosub,ui_MoveConnectionCheckAndCorrect
			if abortAddingElement
				return "aborted"
			
			newElement.mark()
			elementWithHighestPriority:=newElement
			ui_draw()
			
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
			NewElement:=elementWithHighestPriority
			NewElementPart:=partOfElementWithHighestPriority
			newElementCreated:=false
			
			Connection2.from:=NewElement.id
			Connection1.to:=NewElement.id

			;Check whether Connection is possible
			if (NewElement.Type="Trigger" )
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
				NewElement.mark()
			;else keep the new or modified connection marked
			
		}
		ui_draw()
		return
		
		ui_MoveConnectionCheckAndCorrect:
		
		if (Connection2!="") ;If connection 2 exists
		{
			if (NewElement.Type="Condition" and Connection2.connectiontype!="exception" and Connection2.connectiontype!="no" and Connection2.connectiontype!="yes") ;if pulled to connection and its type is not exception
			{
				ret:=selectConnectionType(Connection2,"wait")
				if (ret="aborted")
					return "aborted"
			}
			else ;if pulled to anything else, check whether it is normal or exception
			{
				if (Connection2.connectiontype!="normal" and Connection2.connectiontype!="exception")
					Connection2.connectiontype:="normal"
			}
		}
		
		
		if (Element2.Type="Loop") ;If the second element is a loop. The information about the connected part is not yet in the second connection.
		{
			if (not Connection2.toPart) ;If no part assigned to connection
			{
				if (Connection1!="") ;If a second connection exist. Thus it was previously connected to the loop
					Connection2.toPart:=Connection1.toPart
				else
					Connection2.toPart:="HEAD" ;connect to head
			}
		}
		else
			Connection2.delete("topart") ;Delete part information if set
		
		if (NewElement.Type="Loop") ;If user pulled to a loop, assign parts
		{
			if newElementCreated ;If a new one was created, define default parts
			{
				Connection1.toPart:="HEAD" 
				Connection2.fromPart:="TAIL"
			}
			else ;If user has pulled to an existing loop, decide depending on which part he dropped it
			{
				if (Connection1!="" and Connection2!="") ;assign default if both connections exist
				{
					Connection1.toPart:="HEAD" 
					Connection2.fromPart:="TAIL"
				}
				else
				{
					if (NewElementPart=1 or NewElementPart=2) 
					{
						Connection1.toPart:="HEAD" 
						Connection2.fromPart:="HEAD"
					}
					else if (NewElementPart=3) 
					{
						Connection1.toPart:="TAIL" 
						Connection2.fromPart:="TAIL"
					}
					else if (NewElementPart=4) 
					{
						Connection1.toPart:="BREAK" 
						Connection2.fromPart:="TAIL"
					}
				}
			}
		}
		else ;if not, delete part informations, if any
		{
			Connection1.delete("topart")
			Connection2.delete("fromPart")
		}
		if (Element1.Type="Loop") ;If the first element is a loop
		{
			if (not Connection1.fromPart) ;If no part assigned to connection
				Connection1.fromPart:="TAIL" ;connect to tail
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
			
			for index, forElement in allConnections
			{
				;~ d(strobj(tempElement) "`n`n" strobj(forElement), "wait")
				if (forElement!=tempElement)
				{
					if (forElement.from=tempElement.from and forElement.to=tempElement.to )
					{
						if (forElement.ConnectionType=tempElement.ConnectionType)
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

#IfWinActive ·AutoHotFlow· Editor ;Hotkeys

esc:
return

del: ;delete marked element
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}

markedElementscopy:=markedElements.clone()

for markindex, markelement in markedElementscopy
{
	if (markelement.type="trigger")
	{
		MsgBox,% lang("Trigger_cannot be removed!")
		continue
	}
	else ;remove all marked elements
	{
		markelement.remove()
	}
	

}
markedElementscopy:=""
;e_CorrectElementErrors("Code: 354546841.")
new state()
ui_UpdateStatusbartext()
ui_draw()
return



;Zoom
ctrl_wheeldown:

MouseGetPos,mx5,my5 ;Get the mouse position

mx5old:=mx5/zoomFactor
my5old:=my5/zoomFactor



zoomFactorOld:=zoomFactor

zoomFactor:=zoomFactor/1.1
if (zoomFactor<zoomFactorMin)
{
	zoomFactor:=zoomFactorMin
}

mx5new:=mx5 /zoomFactor
my5new:=my5 /zoomFactor
offsetx:=  offsetx + mx5old - mx5new 
offsety:= offsety + my5old  - my5new
ui_UpdateStatusbartext("pos")
ui_draw()

return

ctrl_wheelup:

MouseGetPos,mx5,my5 ;Get the mouse position

mx5old:=mx5/zoomFactor
my5old:=my5/zoomFactor




zoomFactorOld:=zoomFactor

zoomFactor:=zoomFactor*1.1
if (zoomFactor>zoomFactorMax)
{
	zoomFactor:=zoomFactorMax
}

mx5new:=mx5/zoomFactor
my5new:=my5/zoomFactor



offsetx:=  offsetx + mx5old - mx5new 
offsety:= offsety + my5old  - my5new
ui_UpdateStatusbartext("pos")

ui_draw()

return


ctrl_x:
ret:=i_SaveToClipboard()
if ret=0
{ ;Delete all marked elements
	markedElementscopy:=markedElements.clone()

	for markindex, markelement in markedElementscopy
	{
		if (markelement.type="trigger" or markelement.type="connection")
		{
			continue
		}
		else ;remove all marked elements
		{
			markelement.remove()
		}
	}
	markedElementscopy:=""
	
	new state()
	ui_UpdateStatusbartext()
	ui_draw()
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
i_SaveToClipboard()
return

ctrl_v:
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
;ToolTip("Control + V pressed")
i_loadFromClipboard()
return

ctrl_s:
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
i_save()
return

ctrl_z:
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
states.undo()
ui_draw()
return
ctrl_y:
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
states.redo()
ui_draw()
return

ctrl_a:
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
element.unmarkall()
for index, forElement in allelements
{
	element.markAll()
}
ui_draw()
return



jumpoverclickstuff:
temp=