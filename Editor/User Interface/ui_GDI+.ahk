;Formula for x-position: 0+n*35  	;Width: 35*4=140
;Formula for y-position: 17,5+n*35	;Height: 35*3=105

;Initialize values at the beginning
GridX=35
Gridy=35
GridyOffset=17.5
ElementWidth=140
ElementHeight=105
NewElementIconWidth=100
NewElementIconHeight=75
SizeOfButtons=35
textSize=15
Offsetx=0
Offsety=0
zoomFactor=0.7
zoomFactorMin=0.09
zoomFactorMax=3
widthofguipic=500
heightofguipic=300
OnTopLabel=



; Thanks to tic (Tariq Porter) for his GDI+ Library
; http://www.autohotkey.com/forum/viewtopic.php?t=32238
; Start gdi+
If !pToken := Gdip_Startup()
{
	MsgBox, 48, gdiplus error!, Gdiplus failed to start. Please ensure you have gdiplus on your system
	ExitApp
}



Font:="Arial"

; Create some brushes
pPenBlack := Gdip_CreatePen("0xff000000",2)
pPenMarkLin := Gdip_CreatePen("0xff00aa00",2)
pPenRunningLin := Gdip_CreatePen("0xaaff0000",2)
pPenRed := Gdip_CreatePen("0xffaa0000",2)
pPenGrey := Gdip_CreatePen("0xffaaaaff",2)
pBrushBlack := Gdip_BrushCreateSolid("0xff000000")
pBrushUnmark := Gdip_BrushCreateSolid("0xfffafafa")
pBrushMark := Gdip_BrushCreateSolid("0x5000ff00")
pBrushRunning := Gdip_BrushCreateSolid("0x50ff0000")
pBrushLastRunning := Gdip_BrushCreateSolid("0x10ff0000")


ui_Draw()
{
	global
	gui 1:default
	
	DetectHiddenWindows off
	;Only draw if the window is visible
	IfWinExist,·AutoHotFlow· Editor - %FlowName%
	{
		DetectHiddenWindows on
		
		;Check whether the zoomfactor is inside the allowed bounds
		if (zoomFactor<zoomFactorMin)
			zoomFactor:=zoomFactorMin
		if (zoomFactor>zoomFactorMax)
			zoomFactor:=zoomFactorMax
		
		;Prevent that the function ui_DrawEverything() is called twice at same time. Under sircumstances this would cause a crash.
		if (DrawingRightNow=true)
		{
			
			DrawAgain:=true
			
			
			;MsgBox DrawingRightNow %DrawingRightNow%
			
			return
		}
		else
			ui_drawEverything(PicFlow,widthofguipic,heightofguipic)
	}

	DetectHiddenWindows on
	
	
}

ui_DrawEverything(ByRef Variable,bildw,bildh)
{
	global

	
	
	; We first want the hwnd (handle to the picture control) so that we know where to put the bitmap we create
	; We also want to width and height (posw and Posh)
	;GuiControlGet, Pos, Pos, Variable
	 
	
	DrawingRightNow:=true
	thread, Priority, 0 ;Set normal priority
	GuiControlGet, hwnd, hwnd, Variable
	
	Posw=%bildw%
	Posh=%bildh%
	
	
	
	local TextOptions:=" s" (textSize*zoomFactor) " Center cff000000  Bold"
	local TextOptionsmarked:=" s" (textSize*zoomFactor) " Center cff00aa00  Bold"
	local TextOptionsRunning:=" s" (textSize*zoomFactor) " Center cffaa0000  Bold"

	local TextOptionsLeft:=" s" (textSize*zoomFactor) " Left cff000000  Bold"
	local TextOptionsLeftmarked:=" s" (textSize*zoomFactor) " Left cff00aa00  Bold"
	local TextOptionsLeftRunning:=" s" (textSize*zoomFactor) " Left cffaa0000  Bold"

	local TextOptionsRight:=" s" (textSize*zoomFactor) " Right cff000000  Bold"
	local TextOptionsRightmarked:=" s" (textSize*zoomFactor) " Right  cff00aa00  Bold"
	local TextOptionsRightRunning:=" s" (textSize*zoomFactor) " Right  cffaa0000  Bold"

	local TextOptionsTopLabel:=" s20"  "  cff330000  Bold"
	
	
	; Create a gdi+ bitmap the width and height that we found the picture control to be
	; We will then get a reference to the graphics of this bitmap
	; We will also set the smoothing mode of the graphics to 4 (Antialias) to make the shapes we use smooth
	 pBitmap := Gdip_CreateBitmap(Posw, Posh)
	 G := Gdip_GraphicsFromImage(pBitmap)
	Gdip_SetSmoothingMode(G, 4)
	
	
	if (zoomFactor>0.65)
	{
		;Draw Grid
		tempy:=round(Offsety/(Gridy)) * Gridy - 17.5
		tempx1:=round(Offsetx/(Gridx)) * Gridx
		tempxanzahl:=round(widthofguipic/(Gridx*zoomFactor))+1
		tempyanzahl:=round(heightofguipic/(Gridy*zoomFactor))+1
		
		Loop %tempyanzahl%
		{
			tempx:=tempx1
			Loop %tempxanzahl%
			{
				Gdip_FillRectangle(G, pBrushBlack, round((tempx-Offsetx)*zoomFactor)-1, round((tempy-Offsety)*zoomFactor)-1, 2, 2)
				
				
				tempx:=tempx+Gridx
			}
			
			tempy:=tempy+Gridy
		}
	}
	
	for index, element in allElements
	{
		
		if %element%Type=Trigger
		{
			Gdip_FillRoundedRectangle(G, pBrushUnmark, ((%element%x-Offsetx)*zoomFactor), ((%element%y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor),(30*zoomFactor))
			Gdip_DrawroundedRectangle(G, pPenGrey, ((%element%x-Offsetx)*zoomFactor), ((%element%y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor),(30*zoomFactor))
			Gdip_TextToGraphics(G, %element%name, "x" ((%element%x-Offsetx)*zoomFactor +4) " y" ((%element%y-Offsety)*zoomFactor+4) " vCenter " TextOptions , Font, ((ElementWidth)*zoomFactor-8), ((ElementHeight)*zoomFactor-8))
			
			if %element%marked=true
				Gdip_FillroundedRectangle(G, pBrushMark, ((%element%x-Offsetx)*zoomFactor), ((%element%y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor),(30*zoomFactor))
			if (%element%running>0) ;If element is running
			{
				Gdip_FillroundedRectangle(G, pBrushRunning, ((%element%x-Offsetx)*zoomFactor), ((%element%y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor),(30*zoomFactor))
			}
			if (%element%running<0) ;If element has recently run
			{
				Gdip_FillroundedRectangle(G, pBrushLastRunning, ((%element%x-Offsetx)*zoomFactor), ((%element%y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor),(30*zoomFactor))
			}
			
			;MsgBox,% "x" (%element%x*zoomFactor +4) "y" (%element%y*zoomFactor+4) TextOptions Font (180*zoomFactor-8) (135*zoomFactor-8)
			;Define area of parts
			%element%part1x1:=((%element%x-Offsetx)*zoomFactor)
			%element%part1y1:=((%element%y-Offsety)*zoomFactor)
			%element%part1x2:=((%element%x-Offsetx)*zoomFactor)+(ElementWidth*zoomFactor)
			%element%part1y2:=((%element%y-Offsety)*zoomFactor)+(ElementHeight*zoomFactor)
			;MsgBox,% "x1 " %element%part1x1 " y1 " %element%part1y1 " x2 " %element%part1x2 "y2" %element%part1y2
			%element%CountOfParts=1
			%element%ClickPriority=500
		}
		if %element%Type=Action
		{
			
			Gdip_FillRectangle(G, pBrushUnmark, ((%element%x-Offsetx)*zoomFactor), ((%element%y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor))
			Gdip_DrawRectangle(G, pPenGrey, ((%element%x-Offsetx)*zoomFactor), ((%element%y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor))
			;Gdip_TextToGraphics(G, %element%name, "x" ((%element%x-Offsetx)*zoomFactor +4) "y" ((%element%y-Offsety)*zoomFactor+4) TextOptions , Font, ((ElementWidth)*zoomFactor-8), ((ElementHeight)*zoomFactor-8))
			Gdip_TextToGraphics(G, %element%name, "x" ((%element%x-Offsetx)*zoomFactor +4) " y" ((%element%y-Offsety)*zoomFactor+4) " vCenter " TextOptions , Font, ((ElementWidth)*zoomFactor-8), (ElementHeight*zoomFactor-8))
			if %element%marked=true
				Gdip_FillRectangle(G, pBrushMark, ((%element%x-Offsetx)*zoomFactor), ((%element%y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor))
			if (%element%running>0) ;If element is running
			{
				Gdip_FillRectangle(G, pBrushRunning, ((%element%x-Offsetx)*zoomFactor), ((%element%y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor))
			}
			if (%element%running<0) ;If element has recently run
			{
				Gdip_FillRectangle(G, pBrushLastRunning, ((%element%x-Offsetx)*zoomFactor), ((%element%y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor))
			}
			;MsgBox, % element "`n" %element%marked
			
			;Define area of parts
			%element%part1x1:=((%element%x-Offsetx)*zoomFactor)
			%element%part1y1:=((%element%y-Offsety)*zoomFactor)
			%element%part1x2:=((%element%x-Offsetx)*zoomFactor)+(ElementWidth*zoomFactor)
			%element%part1y2:=((%element%y-Offsety)*zoomFactor)+(ElementHeight*zoomFactor)
			%element%CountOfParts=1
			%element%ClickPriority=500
		}
		if %element%Type=Condition
		{
			Gdip_FillRoundedRectangle(G, pBrushUnmark, ((%element%x-Offsetx)*zoomFactor), ((%element%y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor),(30*zoomFactor))
			;Gdip_FillPolygon(G, pBrushUnmark,((%element%x+ElementWidth/2)*zoomFactor) "," ((%element%y+0)*zoomFactor) "|" ((%element%x+ElementWidth)*zoomFactor) "," ((%element%y+ElementHeight/2)*zoomFactor) "|" ((%element%x+ElementWidth/2)*zoomFactor) "," ((%element%y+ElementHeight)*zoomFactor) "|" ((%element%x+0)*zoomFactor) "," ((%element%y+ElementHeight/2)*zoomFactor) "|" ((%element%x+ElementWidth/2)*zoomFactor) "," ((%element%y+0)*zoomFactor))
			Gdip_DrawLines(G, pPenGrey,((%element%x+ElementWidth/2-Offsetx)*zoomFactor) "," ((%element%y+0-Offsety)*zoomFactor) "|" ((%element%x+ElementWidth-Offsetx)*zoomFactor) "," ((%element%y+ElementHeight/2-Offsety)*zoomFactor) "|" ((%element%x+ElementWidth/2-Offsetx)*zoomFactor) "," ((%element%y+ElementHeight-Offsety)*zoomFactor) "|" ((%element%x+0-Offsetx)*zoomFactor) "," ((%element%y+ElementHeight/2-Offsety)*zoomFactor) "|" ((%element%x+ElementWidth/2-Offsetx)*zoomFactor) "," ((%element%y+0-Offsety)*zoomFactor))
			
			Gdip_TextToGraphics(G, %element%name, "x" ((%element%x-Offsetx)*zoomFactor +4) " y" ((%element%y-Offsety)*zoomFactor+4) " vCenter " TextOptions , Font, (ElementWidth*zoomFactor-8), (ElementHeight*zoomFactor-8))
			if %element%marked=true
				Gdip_FillroundedRectangle(G, pBrushMark, ((%element%x-Offsetx)*zoomFactor), ((%element%y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor),(30*zoomFactor))
			
			if (%element%running>0) ;If element is running
			{
				Gdip_FillroundedRectangle(G, pBrushRunning, ((%element%x-Offsetx)*zoomFactor), ((%element%y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor),(30*zoomFactor))
			}
			if (%element%running<0) ;If element has recently run
			{
				Gdip_FillroundedRectangle(G, pBrushLastRunning, ((%element%x-Offsetx)*zoomFactor), ((%element%y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor),(30*zoomFactor))
			}
			;Define area of parts
			%element%part1x1:=((%element%x-Offsetx)*zoomFactor)
			%element%part1y1:=((%element%y-Offsety)*zoomFactor)
			%element%part1x2:=((%element%x-Offsetx)*zoomFactor)+(ElementWidth*zoomFactor)
			%element%part1y2:=((%element%y-Offsety)*zoomFactor)+(ElementHeight*zoomFactor)
			%element%CountOfParts=1
			%element%ClickPriority=500
		}
		
		
		if %element%Type=Connection
		{
			;msgbox,% %Element%from "Pic"
			;msgbox,% %Element%to "Pic"
			tempFromEl:=%Element%from
			tempToEl:=%Element%to
			;msgbox,% tempFromEl "`n" %tempFromEl%x
			
			
			
			if tempFromEl=MOUSE
			{
				MouseGetPos,mx2,my2 ;Get the mouse position
				mx3:=mx2-guipicx ;calculate the mouse position relative to the picture
				my3:=my2-guipicy
				StartPosx:=(mx3)/zoomfactor+offsetx
				StartPosy:=(my3)/zoomfactor+offsety
				
			}
			else
			{
				StartPosx:=%tempFromEl%x+(ElementWidth/2)
				StartPosy:=%tempFromEl%y+ElementHeight
			}
			
			if tempToEl=MOUSE
			{
				MouseGetPos,mx2,my2 ;Get the mouse position
				mx3:=mx2-guipicx ;calculate the mouse position relative to the picture
				my3:=my2-guipicy
				aimPosx:=(mx3)/zoomfactor+offsetx
				aimPosy:=(my3)/zoomfactor+offsety
				
			}
			else
			{
				aimPosx:=%tempToEl%x+(ElementWidth/2)
				aimPosy:=%tempToEl%y
			}
			
			;MsgBox
			lin1x:=startposx
			lin1y:=startposy
			lin1w:=0
			if ((aimPosy-startposy)<20)
			{
				lin1h:=10
			}
			else
			{
				lin1h:=(aimPosy-StartPosy)/2
			}
			
			
			
			lin2y:=lin1y+lin1h
			lin2h:=0
			if (aimPosx>StartPosx)
			{
				lin2x:=lin1x
				lin2w:=(aimPosx-StartPosx)/2
				if (lin2w<ElementWidth/2 +5 and StartPosy>aimPosy)
					lin2w:=ElementWidth/2+5
				if (aimPosx-ElementWidth/2-5<lin2x+lin2w and StartPosy>aimPosy)
				{
					lin2w:=aimPosx+ElementWidth/2+5-lin2x
					
				}
				
				
			}
			else
			{
				
				lin2w:=(StartPosx- aimPosx)/2
				
				if (lin2w<ElementWidth/2 +5 and StartPosy>aimPosy)
					lin2w:=ElementWidth/2+5
				lin2x:=lin1x-lin2w
				if (aimPosx+ElementWidth/2+5>lin2x and StartPosy>aimPosy)
				{
					lin2x:=aimPosx-ElementWidth/2-5
					lin2w:=lin1x-lin2x
					
				}
					
				
			}
			
			
			lin3w:=0
			if (aimPosx>StartPosx)
			{
				
				
				lin3x:=lin2x+lin2w
			}
			else
			{
				
				lin3x:=lin2x
			}
			
			
			
			
			if (StartPosy>aimPosy-20)
			{
				
				lin3y:=aimPosy-10
				lin3h:=lin2y-lin3y
			}
			else
			{
				lin3h:=0
				lin3y:=lin2y
				
			}
			
			
			lin4y:=lin3y
			lin4h:=0
			if (aimPosx>lin3x)
			{
				lin4x:=lin3x
				lin4w:=(aimPosx-lin4x)
				
			}
			else
			{
				
				lin4x:=aimPosx
				lin4w:=(lin3x-lin4x)
				
			}
			
			
			lin5x:=aimPosx
			
			lin5w:=0
			if ((aimPosy-startposy)<20)
			{
				lin5h:=10
				lin5y:=aimPosy-lin5h
			}
			else
			{
				lin5h:=(aimPosy-StartPosy)/2
				lin5y:=aimPosy-lin5h
			}
			
			if (not ((%element%ConnectionType="normal") or (%element%ConnectionType="exception")))
			{
				if (%element%ConnectionType="yes")
				{
					schrx:=aimPosx-ElementWidth/2
					schrw:=ElementWidth/2-3
					TextOptionsmarkedThis:=TextOptionsRightmarked
					TextOptionsRunningThis:=TextOptionsRightRunning
					TextOptionsThis:=TextOptionsRight
				}
				else 
				{
					schrx:=aimPosx+5
					schrw:=ElementWidth/2
					TextOptionsmarkedThis:=TextOptionsLeftmarked
					TextOptionsRunningThis:=TextOptionsLeftRunning
					TextOptionsThis:=TextOptionsLeft
				}
				
				Aufschrift:=aimPosx
				
				schrh:=17
				
				schry:=aimPosy-schrh
				
				
				
				if %element%marked=true
					Gdip_TextToGraphics(G, %element%ConnectionType, "x" ((schrx-Offsetx)*zoomFactor) " y" ((schry-Offsety)*zoomFactor) TextOptionsmarkedThis , Font, (schrw*zoomFactor), (schrh*zoomFactor))
				else if (%element%running<0) ;If element has recently run
					Gdip_TextToGraphics(G, %element%ConnectionType, "x" ((schrx-Offsetx)*zoomFactor) " y" ((schry-Offsety)*zoomFactor) TextOptionsRunningThis , Font, (schrw*zoomFactor), (schrh*zoomFactor))
				else
					Gdip_TextToGraphics(G, %element%ConnectionType, "x" ((schrx-Offsetx)*zoomFactor) " y" ((schry-Offsety)*zoomFactor) TextOptionsThis , Font, (schrw*zoomFactor), (schrh*zoomFactor))
				
				
			}
			
			
			
			;MsgBox,% marked
			;msgbox,x%lin3x% y%lin3y% w%lin3w% h%lin3h%`nx%lin4x% y%lin4y% w%lin4w% h%lin4h%
			;msgbox,x%lin1x% y%lin1y% w%lin1w% h%lin1h%
			
			
			
			%element%CountOfParts=0
			
			loop 5
			{
				if (%element%ConnectionType="exception")
				{
					if %element%marked=true
						Gdip_DrawLine(G, pPenMarkLin, ((lin%a_index%x-Offsetx)*zoomFactor), ((lin%a_index%y-Offsety)*zoomFactor), ((lin%a_index%x+lin%a_index%w-Offsetx)*zoomFactor) , ((lin%a_index%y+lin%a_index%h-Offsety)*zoomFactor))
					else
						Gdip_DrawLine(G, pPenRed , ((lin%a_index%x-Offsetx)*zoomFactor), ((lin%a_index%y-Offsety)*zoomFactor), ((lin%a_index%x+lin%a_index%w-Offsetx)*zoomFactor) , ((lin%a_index%y+lin%a_index%h-Offsety)*zoomFactor))
					if (%element%running<0)
						Gdip_DrawLine(G, pPenRunningLin , ((lin%a_index%x-Offsetx)*zoomFactor), ((lin%a_index%y-Offsety)*zoomFactor), ((lin%a_index%x+lin%a_index%w-Offsetx)*zoomFactor) , ((lin%a_index%y+lin%a_index%h-Offsety)*zoomFactor))
				}
				else
				{
					if %element%marked=true
						Gdip_DrawLine(G, pPenMarkLin, ((lin%a_index%x-Offsetx)*zoomFactor), ((lin%a_index%y-Offsety)*zoomFactor), ((lin%a_index%x+lin%a_index%w-Offsetx)*zoomFactor) , ((lin%a_index%y+lin%a_index%h-Offsety)*zoomFactor))
					else
						Gdip_DrawLine(G, pPenBlack, ((lin%a_index%x-Offsetx)*zoomFactor), ((lin%a_index%y-Offsety)*zoomFactor), ((lin%a_index%x+lin%a_index%w-Offsetx)*zoomFactor) , ((lin%a_index%y+lin%a_index%h-Offsety)*zoomFactor))
					if (%element%running<0)
						Gdip_DrawLine(G, pPenRunningLin, ((lin%a_index%x-Offsetx)*zoomFactor), ((lin%a_index%y-Offsety)*zoomFactor), ((lin%a_index%x+lin%a_index%w-Offsetx)*zoomFactor) , ((lin%a_index%y+lin%a_index%h-Offsety)*zoomFactor))
				}
				
				;Define area of parts
				%element%part%a_index%x1:=((lin%a_index%x-20-Offsetx)*zoomFactor)
				%element%part%a_index%y1:=((lin%a_index%y-20-Offsety)*zoomFactor)
				%element%part%a_index%x2:=((lin%a_index%x+lin%a_index%w+20-Offsetx)*zoomFactor)
				%element%part%a_index%y2:=((lin%a_index%y+lin%a_index%h+20-Offsety)*zoomFactor)
				%element%CountOfParts++
				%element%ClickPriority=200
			}
			
		}
	}
	
	
	
	
	;Draw some icons near to the selected element, if only one is selected
	PlusButtonExist:=false
	TrashButtonExist:=false
	EditButtonExist:=false
	MoveButton1Exist:=false
	MoveButton2Exist:=false
	if (countMarkedElements=1 )
	{
		pBitmapEdit := Gdip_CreateBitmapFromFile("Icons\edit.ico")
		pBitmapPlus := Gdip_CreateBitmapFromFile("Icons\plus.ico")
		pBitmapMove := Gdip_CreateBitmapFromFile("Icons\move.ico")
		pBitmapTrash := Gdip_CreateBitmapFromFile("Icons\trash.ico")
		
		;Move Button
		if (%TheOnlyOneMarkedElement%type = "connection")
		{
			tempFromEl:=%TheOnlyOneMarkedElement%from
			tempToEl:=%TheOnlyOneMarkedElement%to
			middlePointOfMoveButton1X:=%tempFromEl%x + ElementWidth *0.5 - Offsetx
			middlePointOfMoveButton1Y:=%tempFromEl%y +ElementHeight  - Offsety
			Gdip_DrawImage(G, pBitmapMove, (middlePointOfMoveButton1X - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfMoveButton1Y - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
			MoveButton1Exist:=true
			middlePointOfMoveButton2X:=%tempToEl%x + ElementWidth *0.5 - Offsetx
			middlePointOfMoveButton2Y:=%tempToEl%y  - Offsety
			Gdip_DrawImage(G, pBitmapMove, (middlePointOfMoveButton2X - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfMoveButton2Y - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
			MoveButton2Exist:=True
		}
		
		
		;Edit Button
		if ((%TheOnlyOneMarkedElement%type = "action" or  %TheOnlyOneMarkedElement%type = "condition" or %TheOnlyOneMarkedElement%type = "trigger"))
		{
			middlePointOfEditButtonX:=%TheOnlyOneMarkedElement%x - ElementWidth *0.125 - SizeOfButtons*0.2 - Offsetx
			middlePointOfEditButtonY:=%TheOnlyOneMarkedElement%y +ElementWidth *0.375 - Offsety
			
		}
		else if (%TheOnlyOneMarkedElement%type = "connection")
		{
			middlePointOfEditButtonX:=((%TheOnlyOneMarkedElement%part3x1 +  %TheOnlyOneMarkedElement%part3x2)/2  ) / zoomFactor - SizeOfButtons*1.3
			middlePointOfEditButtonY:=(%TheOnlyOneMarkedElement%part3y1   ) / zoomFactor + SizeOfButtons*0.5 
		}
		Gdip_DrawImage(G, pBitmapEdit, (middlePointOfEditButtonX - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfEditButtonY - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
		EditButtonExist:=true
		
		;Trash Button
		if (%TheOnlyOneMarkedElement%type="action" or  %TheOnlyOneMarkedElement%type = "condition" or %TheOnlyOneMarkedElement%type = "connection")
		{
			if (%TheOnlyOneMarkedElement%type = "connection")
			{
				middlePointOfTrashButtonX:=((%TheOnlyOneMarkedElement%part3x1 +  %TheOnlyOneMarkedElement%part3x2)/2  ) / zoomFactor + SizeOfButtons*1.3
				middlePointOfTrashButtonY:=(%TheOnlyOneMarkedElement%part3y1  ) / zoomFactor + SizeOfButtons*0.5 
			}
			else
			{
				middlePointOfTrashButtonX:=%TheOnlyOneMarkedElement%x + ElementWidth *9/8 + SizeOfButtons*0.2 - Offsetx
				middlePointOfTrashButtonY:=%TheOnlyOneMarkedElement%y +ElementWidth *0.375 - Offsety
			}
			Gdip_DrawImage(G, pBitmapTrash, (middlePointOfTrashButtonX - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfTrashButtonY - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
			TrashButtonExist:=true
		}
		
		;Plus Button
		if (%TheOnlyOneMarkedElement%type = "connection")
		{
			middlePointOfPlusButtonX:=((%TheOnlyOneMarkedElement%part3x1 +  %TheOnlyOneMarkedElement%part3x2)/2  ) / zoomFactor 
			middlePointOfPlusButtonY:=(%TheOnlyOneMarkedElement%part3y1  ) / zoomFactor + SizeOfButtons*0.5 
			Gdip_DrawImage(G, pBitmapPlus, (middlePointOfPlusButtonX - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfPlusButtonY - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
			PlusButtonExist:=true
		}
		else if ((%TheOnlyOneMarkedElement%type = "action" or  %TheOnlyOneMarkedElement%type = "condition" or %TheOnlyOneMarkedElement%type = "trigger"))
		{
			middlePointOfPlusButtonX:=%TheOnlyOneMarkedElement%x + ElementWidth *0.5 - Offsetx
			middlePointOfPlusButtonY:=%TheOnlyOneMarkedElement%y +ElementWidth *7/8 + SizeOfButtons*0.2 - Offsety
			Gdip_DrawImage(G, pBitmapPlus, (middlePointOfPlusButtonX - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfPlusButtonY - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
			PlusButtonExist:=true
		}
		
		
	}
	
	;At the end draw the menu bar
	Gdip_FillRectangle(G, pBrushUnmark, ((0)*zoomFactor), ((0)*zoomFactor), ((NewElementIconWidth *1.2)*zoomFactor *2), ((NewElementIconHeight * 1.2)*zoomFactor)) ;Draw a white area
	
	;Draw an action
	;Gdip_FillRectangle(G, pBrushUnmark, ((ElementWidth *0.1)*zoomFactor), ((ElementHeight * 0.1)*zoomFactor), ((ElementWidth )*zoomFactor), ((ElementHeight )*zoomFactor))
	Gdip_DrawRectangle(G, pPenGrey, (((NewElementIconWidth *0.1))*zoomFactor), (((NewElementIconHeight * 0.1))*zoomFactor), ((NewElementIconWidth)*zoomFactor), ((NewElementIconHeight)*zoomFactor))
	Gdip_TextToGraphics(G, lang("Create new action"), "x" ((NewElementIconWidth *0.1)*zoomFactor+4) " y" ((NewElementIconHeight * 0.1)*zoomFactor+4) " vCenter " TextOptions , Font, ((NewElementIconWidth)*zoomFactor-8), ((NewElementIconHeight)*zoomFactor-8))
	
	;Draw a condition
	Gdip_DrawLines(G, pPenGrey,(((NewElementIconWidth *1.3)+NewElementIconWidth/2)*zoomFactor) "," (((NewElementIconHeight * 0.1)+0)*zoomFactor) "|" (((NewElementIconWidth *1.3)+NewElementIconWidth)*zoomFactor) "," (((NewElementIconHeight * 0.1)+NewElementIconHeight/2)*zoomFactor) "|" (((NewElementIconWidth *1.3)+NewElementIconWidth/2)*zoomFactor) "," (((NewElementIconHeight * 0.1)+NewElementIconHeight)*zoomFactor) "|" (((NewElementIconWidth *1.3)+0)*zoomFactor) "," (((NewElementIconHeight * 0.1)+NewElementIconHeight/2)*zoomFactor) "|" (((NewElementIconWidth *1.3)+NewElementIconWidth/2)*zoomFactor) "," (((NewElementIconHeight * 0.1)+0)*zoomFactor))
	Gdip_TextToGraphics(G, lang("Create new condition"), "x" ((NewElementIconWidth *1.3)*zoomFactor+4) " y" ((NewElementIconHeight * 0.1)*zoomFactor+4) " vCenter " TextOptions , Font, ((NewElementIconWidth)*zoomFactor-8), ((NewElementIconHeight)*zoomFactor-8))
	


	
	Gdip_TextToGraphics(G, OnTopLabel, "x10 y0 " TextOptionsTopLabel, Font, widthofguipic, heightofguipic)
	
	
	
	
	; We then get a gdi bitmap from the gdi+ one we've been working with...
	hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap)
	; ... and set it to the hwnd we found for the picture control
	
	
	SetImage(hwnd, hBitmap)
	
	;delete bitmaps
	Gdip_DeleteGraphics(G), Gdip_DisposeImage(pBitmap), DeleteObject(hBitmap)
	
	DrawingRightNow:=false
	if (DrawAgain=true)
	{
		DrawAgain:=false
		ToolTip("Draw Again")
		;ui_drawEverything(PicFlow,widthofguipic,heightofguipic)
		SetTimer,ui_Draw,-10
	}
	
	
	
	Return

}


;Fit the position of an element to the grid
ui_FitgridX(pos){
	global
	;MsgBox % round((pos/gridX))*gridX "  --  " pos
	return round((pos/gridX))*gridX
}
ui_FitgridY(pos){
	global
	return round(((pos-gridyOffset)/gridY))*gridY + gridyOffset
}



/**
This function calculates a new position for a new element.
It has to be optimized
Output:
	goodNewPositionX
	goodNewPositionY
*/
ui_SeekForNewElementPosition()
{
	global
	tempmiddleX:=Offsetx+widthofguipic/2/zoomFactor-ElementWidth/2
	tempmiddleY:=Offsety+heightofguipic/2/zoomFactor-ElementHeight/2
	goodNewPositionX:=ui_FitGridX(tempmiddleX)
	goodNewPositionY:=ui_FitGridY(tempmiddleY)
	
	/*for index, element in allElements ;Check whether any other elements is there
	{
		if 20<(goodNewPositionX-
		
	}
	goodNewPositionX:=FitGridX(tempmiddleX)
	goodNewPositionY:=FitGridY(tempmiddleY)
	;MsgBox %goodNewPositionX%
	*/
}

ui_DrawShapeOnScreen(WindowPosx,WindowPosy,WindowWidth,WindowHeight,ControlPosx,ControlPosy,ControlWidth,ControlHeight)
{
	; Set the width and height we want as our drawing area, to draw everything in. This will be the dimensions of our bitmap
	
	;MsgBox WindowPosx %WindowPosx% WindowPosy %WindowPosy% WindowWidth %WindowWidth% WindowHeight %WindowHeight% %ControlPosx% %ControlPosy% %ControlWidth% %ControlHeight%
	
	Gui, 6: Destroy
	; Create a layered window (+E0x80000 : must be used for UpdateLayeredWindow to work!) that is always on top (+AlwaysOnTop), has no taskbar entry or caption
	Gui, 6: -Caption +E0x80000 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs

	; Show the window
	Gui, 6: Show,  NA

	; Get a handle to this window we have created in order to update it later
	hwnd1 := WinExist()

	; Create a gdi bitmap with width and height of what we are going to draw into it. This is the entire drawing area for everything
	hbm := CreateDIBSection(WindowWidth,WindowHeight)

	; Get a device context compatible with the screen
	hdc := CreateCompatibleDC()

	; Select the bitmap into the device context
	obm := SelectObject(hdc, hbm)

	; Get a pointer to the graphics of the bitmap, for use with drawing functions
	G := Gdip_GraphicsFromHDC(hdc)

	; Set the smoothing mode to antialias = 4 to make shapes appear smother (only used for vector drawing and filling)
	Gdip_SetSmoothingMode(G, 4)

	; Create a fully opaque red pen (ARGB = Transparency, red, green, blue) of width 3 (the thickness the pen will draw at) to draw a circle
	pPen := Gdip_CreatePen(0xffff0000, 3)

	; Draw a rectangle onto the graphics of the bitmap using the pen just created
	; Draws the rectangle from coordinates (250,80) a rectangle of 300x200 and outline width of 10 (specified when creating the pen)
	Gdip_DrawRectangle(G, pPen, ControlPosx, ControlPosy,  ControlWidth,ControlHeight)

	; Delete the brush as it is no longer needed and wastes memory
	Gdip_DeletePen(pPen)

	; Update the specified window we have created (hwnd1) with a handle to our bitmap (hdc), specifying the x,y,w,h we want it positioned on our screen
	; So this will position our gui at (0,0) with the Width and Height specified earlier
	UpdateLayeredWindow(hwnd1, hdc, WindowPosx, WindowPosy, WindowWidth, WindowHeight)


	; Select the object back into the hdc
	SelectObject(hdc, obm)

	; Now the bitmap may be deleted
	DeleteObject(hbm)

	; Also the device context related to the bitmap may be deleted
	DeleteDC(hdc)

	; The graphics may now be deleted
	Gdip_DeleteGraphics(G)
	
}

ui_DeleteShapeOnScreen()
{
	Gui, 6: Destroy
}


goto,jumpoverUIDRaw
ui_Draw:
ui_Draw()
return
jumpoverUIDRaw:
temp= ;Do nothing