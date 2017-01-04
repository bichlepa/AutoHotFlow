
gdip_Init()
{
	global
	
	
	
	;Initialize values at the beginning
	GridX:=default_GridX
	Gridy:=default_Gridy
	GridyOffset:=default_GridyOffset
	ElementWidth:=default_ElementWidth
	ElementHeight:=default_ElementHeight
	NewElementIconWidth:=default_NewElementIconWidth
	NewElementIconHeight:=default_NewElementIconHeight
	MinimumHeightOfConnection:=default_MinimumHeightOfConnection
	SizeOfButtons:=default_SizeOfButtons
	textSize:=default_textSize
	zoomFactorMin:=default_zoomFactorMin
	zoomFactorMax:=default_zoomFactorMax
	VisibleArea:=[]
	;~ OnTopLabel=

	
	
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
	pPenBlack := Gdip_CreatePen("0xff000000",2) ;Black pen
	pPenMarkLin := Gdip_CreatePen("0xff00aa00",2) ;Green pen 
	pPenRunningLin := Gdip_CreatePen("0xaaff0000",2) ;Red pen, transparent
	pPenRed := Gdip_CreatePen("0xffaa0000",2) ;Red pen
	pPenGrey := Gdip_CreatePen("0xffaaaaff",2) ;Grey pen
	pBrushBlack := Gdip_BrushCreateSolid("0xff000000") ;Black brush
	pBrushUnmark := Gdip_BrushCreateSolid("0xfffafafa") ;White brush
	pBrushMark := Gdip_BrushCreateSolid("0x5000ff00") ;Green brush, transparent
	pBrushEnabled := Gdip_BrushCreateSolid("0x500000ff") ;Blue brush, transparent
	pBrushRunning := Gdip_BrushCreateSolid("0x50ff0000") ;Red brush, transparent
	pBrushLastRunning := Gdip_BrushCreateSolid("0x10ff0000") ;Red brush, very transparent
	pBrushBackground := Gdip_BrushCreateSolid("0xFFeaf0ea") ;Almost white brush for background


	pBitmapEdit := Gdip_CreateBitmapFromFile(my_ScriptDir "\Icons\edit.ico")
	pBitmapPlus := Gdip_CreateBitmapFromFile(my_ScriptDir "\Icons\plus.ico")
	pBitmapMove := Gdip_CreateBitmapFromFile(my_ScriptDir "\Icons\move.ico")
	pBitmapTrash := Gdip_CreateBitmapFromFile(my_ScriptDir "\Icons\trash.ico")
	pBitmapTrash := Gdip_CreateBitmapFromFile(my_ScriptDir "\Icons\trash.ico")
	
	pBitmapStarFilled := Gdip_CreateBitmapFromFile(my_ScriptDir "\Icons\e_star_filled.ico")
	pBitmapStarFilled_W := Gdip_GetImageWidth(pBitmapStarFilled)
	pBitmapStarFilled_H := Gdip_GetImageHeight(pBitmapStarFilled)
	if (pBitmapStarFilled_H > pBitmapStarFilled_W)
		pBitmapStarFilled_size := pBitmapStarFilled_H
	else
		pBitmapStarFilled_size := pBitmapStarFilled_W	
	pBitmapStarEmpty := Gdip_CreateBitmapFromFile(my_ScriptDir "\Icons\e_star_Empty.ico")
	pBitmapStarEmpty_W := Gdip_GetImageWidth(pBitmapStarEmpty)
	pBitmapStarEmpty_H := Gdip_GetImageHeight(pBitmapStarEmpty)
	if (pBitmapStarEmpty_H > pBitmapStarEmpty_W)
		pBitmapStarEmpty_size := pBitmapStarEmpty_H
	else
		pBitmapStarEmpty_size := pBitmapStarEmpty_W
	
	pBitmapSwitchOn := Gdip_CreateBitmapFromFile(my_ScriptDir "\Icons\e_switch_on.ico")
	pBitmapSwitchOn_W := Gdip_GetImageWidth(pBitmapSwitchOn)
	pBitmapSwitchOn_H := Gdip_GetImageHeight(pBitmapSwitchOn)
	if (pBitmapSwitchOn_H > pBitmapSwitchOn_W)
		pBitmapSwitchOn_size := pBitmapSwitchOn_H
	else
		pBitmapSwitchOn_size := pBitmapSwitchOn_W
	pBitmapSwitchOff := Gdip_CreateBitmapFromFile(my_ScriptDir "\Icons\e_switch_off.ico")
	pBitmapSwitchOff_W := Gdip_GetImageWidth(pBitmapSwitchOff)
	pBitmapSwitchOff_H := Gdip_GetImageHeight(pBitmapSwitchOff)
	if (pBitmapSwitchOff_H > pBitmapSwitchOff_W)
		pBitmapSwitchOff_size := pBitmapSwitchOff_H
	else
		pBitmapSwitchOff_size := pBitmapSwitchOff_W
	

	CoordMode,mouse,client

}



;Draws everything in the main GUI
gdip_DrawEverything(FlowObj)
{
	global
	local TextOptions, TextOptionsmarked, TextOptionsRunning,TextOptionsLeft,TextOptionsLeftmarked, TextOptionsLeftRunning, TextOptionsRight, TextOptionsRightmarked, TextOptionsRightRunning, TextOptionsSmall, hbm, hdc, obm, G
	local TextOptionsmarkedThis, TextOptionsRunningThis, TextOptionsThis
	local tempy, tempx, tempx1, tempxCount, tempyCount, tempmx, tempmy, tempmwin
	local tempFromEl, tempToEl, StartPosx, StartPosy, GDIStartPosxOld, GDIStartPosYOld, aimPosx, aimPosy, GDIAimPosX, GDIAimPosY
	;~ local GDImx, GDImy ;keep global
	local lin1x, lin1y, lin1w, lin1h, lin2x, lin2y, lin2w, lin2h, lin3x, lin3y, lin3w, lin3h, lin4x, lin4y, lin4w, lin4h, lin5x, lin5y, lin5w, lin5h
	local textx, textw, texth, texty
	local tempElementList, tempElementList2
	local tempElementHasRecentlyRun, AnyRecentlyRunElementFound
	;~ ToolTip redraw
	AnyRecentlyRunElementFound:=false
	;~ ToolTip %widthofguipic% %heightofguipic%
	;~ return
	;~ MsgBox % strobj(allElements)
	Critical,on
	
	DrawingRightNow:=true
	
	FlowID:=FlowObj.id
	

	;~ WinGetTitle,temp,% "ahk_id " mainguihwnd
	;~ ToolTip %temp%
	IfWinExist,% "ahk_id " _share.hwnds["editGUI" FlowID]
	{
		;~ d(FlowObj)
		Offsetx:=FlowObj.flowSettings.Offsetx
		if Offsetx is not number
			Offsetx:= default_offsetx
		Offsety:=FlowObj.flowSettings.Offsety
		if Offsety is not number
			Offsety:= default_Offsety
		zoomFactor:=FlowObj.flowSettings.zoomFactor
		;~ ToolTip draw Offsetx %Offsetx%
		widthofguipic:=FlowObj.draw.widthofguipic
		heightofguipic:=FlowObj.draw.heightofguipic
		markedElement:=FlowObj.markedElement
		;~ ToolTip % strobj(markedElement)
		;Check whether the zoomfactor is inside the allowed bounds
		if (zoomFactor<zoomFactorMin)
			zoomFactor:=zoomFactorMin
		if (zoomFactor>zoomFactorMax)
			zoomFactor:=zoomFactorMax
		;~ ToolTip %widthofguipic% - %heightofguipic%
		;~ d(FlowObj)
		
		allConnections:=FlowObj.allConnections
		allElements:=FlowObj.allElements
		allTriggers:=FlowObj.allTriggers
		markedElements:=FlowObj.markedElements
	}
	else
	{
		return
	}

	
		
	
	TextOptions:=" s" (textSize*zoomFactor) " Center cff000000  Bold"
	TextOptionsmarked:=" s" (textSize*zoomFactor) " Center cff00aa00  Bold"
	TextOptionsRunning:=" s" (textSize*zoomFactor) " Center cffaa0000  Bold"

	TextOptionsLeft:=" s" (textSize*zoomFactor) " Left cff000000  Bold"
	TextOptionsLeftmarked:=" s" (textSize*zoomFactor) " Left cff00aa00  Bold"
	TextOptionsLeftRunning:=" s" (textSize*zoomFactor) " Left cffaa0000  Bold"

	TextOptionsRight:=" s" (textSize*zoomFactor) " Right cff000000  Bold"
	TextOptionsRightmarked:=" s" (textSize*zoomFactor) " Right  cff00aa00  Bold"
	TextOptionsRightRunning:=" s" (textSize*zoomFactor) " Right  cffaa0000  Bold"

	TextOptionsSmall:=" s" (textSize*0.7*zoomFactor) " Center cff000000  Bold"
	;~ TextOptionsTopLabel:=" s20"  "  cff330000  Bold"

	
	
	
	if (FlowObj.draw.DrawMoveButtonUnderMouse = true ) ; or tempFromEl="MOUSE" or tempToEl="MOUSE")
	{
		MouseGetPos,tempmx,tempmy,tempmwin,,2 ;Get the mouse position
		if (tempmwin=_share.hwnds["editGUI" FlowID])
		{
			;~ SoundBeep 200
			GDImx:=tempmx
			GDImy:=tempmy
		}
		;~ else
			;~ SoundBeep 2000
	}
	
	
	hbm := CreateDIBSection(widthofguipic, heightofguipic)
	hdc := CreateCompatibleDC()
	obm := SelectObject(hdc, hbm)
	G := Gdip_GraphicsFromHDC(hdc)
	Gdip_SetSmoothingMode(G, 4) ;We will also set the smoothing mode of the graphics to 4 (Antialias) to make the shapes we use smooth
	
	
	
	Gdip_FillRectangle(G, pBrushBackground, 0, 0, widthofguipic,heightofguipic)

	;~ pBitmap := Gdip_CreateBitmap(widthofguipic, heightofguipic)
	;~ G := Gdip_GraphicsFromImage(pBitmap)
	;~ Gdip_SetSmoothingMode(G, 4)
	
	FlowObj.draw.VisibleArea := Object()
	FlowObj.draw.VisibleArea.X1:=Offsetx
	FlowObj.draw.VisibleArea.Y1:=Offsety
	FlowObj.draw.VisibleArea.X2:=Offsetx+widthofguipic/zoomFactor
	FlowObj.draw.VisibleArea.Y2:=Offsety+heightofguipic/zoomFactor
	FlowObj.draw.VisibleArea.W:=VisibleArea.X2-VisibleArea.X1
	FlowObj.draw.VisibleArea.H:=VisibleArea.Y2-VisibleArea.Y1
	
	if (zoomFactor>1.0) 
	{
		;Draw Grid
		tempy:=round(Offsety/(Gridy)) * Gridy - 17.5
		tempx1:=round(Offsetx/(Gridx)) * Gridx
		tempxCount:=round(widthofguipic/(Gridx*zoomFactor))+1
		tempyCount:=round(heightofguipic/(Gridy*zoomFactor))+1
		
		Loop %tempyCount%
		{
			tempx:=tempx1
			Loop %tempxCount%
			{
				Gdip_FillRectangle(G, pBrushBlack, round((tempx-Offsetx)*zoomFactor)-1, round((tempy-Offsety)*zoomFactor)-1, 2, 2)
				
				
				tempx:=tempx+Gridx
			}
			
			tempy:=tempy+Gridy
		}
	}
	
	;Draw connections. At first make a sorted copy
	tempElementList:=[]
	tempElementList2:=[]
	for drawID, tempelement in allConnections
	{
		;~ MsgBox %index%
		if (tempelement.marked)
			tempElementList2[drawID]:=allConnections[drawID].clone()
		else
			tempElementList[drawID]:=allConnections[drawID].clone()
	}
	for drawID, tempelement in tempElementList2
	{
		tempElementList[drawID]:=tempelement
	}
	for drawID, drawElement in tempElementList
	{
		tempFromEl:=allElements[drawElement.from].clone()
		if (not isobject(tempFromEl))
			tempFromEl:=drawElement.from
		tempToEl:=allElements[drawElement.to].clone()
		if (not isobject(tempToEl))
			tempToEl:=drawElement.to
		
		;Check whether element was recently running. This will paint it slightly red
		tempElementHasRecentlyRun:=false
		if (drawElement.lastRun>0) ;If element has recently run
		{
			;~ ToolTip % drawElement.lastRun
			if ((a_tickcount-drawElement.lastRun)<1000)
			{
				tempElementHasRecentlyRun:=true
				AnyRecentlyRunElementFound:=true
			}
			;~ else
				;~ drawElement.delete(lastRun)
		}
		
		
		;~ MsgBox % strobj(drawElement)
		
		if tempFromEl=MOUSE
		{
			
			StartPosx:=(GDImx)/zoomfactor+offsetx
			StartPosy:=(GDImy)/zoomfactor+offsety
			GDIStartPosxOld:=StartPosx
			GDIStartPosYOld:=StartPosy
			
			
		}
		else if (tempFromEl.type="loop")
		{
			
			
			if (drawElement.ConnectionType="Normal")
			{
				if (drawElement.fromPart="HEAD")
				{
					StartPosx:=tempFromEl.x+(ElementWidth/2)
					StartPosy:=tempFromEl.y+ElementHeight
				}
				else
				{
					StartPosx:=tempFromEl.x+(ElementWidth/2)
					StartPosy:=tempFromEl.y+tempFromEl.HeightOfVerticalBar+ElementHeight*4/3
				}
			}
			else ;If exception
			{
				StartPosx:=tempFromEl.x+(ElementWidth/2)
				StartPosy:=tempFromEl.y+tempFromEl.HeightOfVerticalBar+ElementHeight*4/3
			}
			
		}
		else
		{
			StartPosx:=tempFromEl.x+(ElementWidth/2)
			StartPosy:=tempFromEl.y+ElementHeight
		}
		
		if tempToEl=MOUSE
		{
			
			aimPosx:=(GDImx)/zoomfactor+offsetx
			aimPosy:=(GDImy)/zoomfactor+offsety
			GDIAimPosX:=aimPosx
			GDIAimPosY:=aimPosY
			
			;~ ToolTip %GDIAimPosX% - %GDIAimPosY% - %GDImx% - %zoomfactor% - %offsetx% 
		}
		else if (tempToEl.type="loop")
		{

			if (drawElement.toPart="HEAD")
			{
				aimPosx:=tempToEl.x+(ElementWidth/2 )
				aimPosy:=tempToEl.y
			}
			else if (drawElement.toPart="BREAK")
			{
				aimPosx:=tempToEl.x+(ElementWidth*7/8)
				aimPosy:=tempToEl.y+tempToEl.HeightOfVerticalBar+ElementHeight
			}
			else
			{
				aimPosx:=tempToEl.x+(ElementWidth/2)
				aimPosy:=tempToEl.y+tempToEl.HeightOfVerticalBar+ElementHeight
			}
			
		}
		else
		{
			aimPosx:=tempToEl.x+(ElementWidth/2)
			aimPosy:=tempToEl.y
		}
		
		
		if ((StartPosx<Offsetx and aimPosx<Offsetx) or (StartPosx>(Offsetx+widthofguipic/zoomFactor) and aimPosx>(Offsetx+widthofguipic/zoomFactor)) or (StartPosy<Offsety and  aimPosy<Offsety) or (StartPosy>(Offsety+heightofguipic/zoomFactor) and aimPosy>(Offsety+heightofguipic/zoomFactor)))
		{
			continue
		}
		;MsgBox
		lin1x:=startposx
		lin1y:=startposy
		lin1w:=0
		if ((aimPosy-startposy)<20)
		{
			lin1h:=MinimumHeightOfConnection
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
			
			lin3y:=aimPosy-MinimumHeightOfConnection
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
			lin5h:=MinimumHeightOfConnection
			lin5y:=aimPosy-lin5h
		}
		else
		{
			lin5h:=(aimPosy-StartPosy)/2
			lin5y:=aimPosy-lin5h
		}
		
		if (not ((drawElement.ConnectionType="normal") or (drawElement.ConnectionType="exception")))
		{
			if (drawElement.ConnectionType="yes")
			{
				textx:=aimPosx-ElementWidth/2
				textw:=ElementWidth/2-3
				TextOptionsmarkedThis:=TextOptionsRightmarked
				TextOptionsRunningThis:=TextOptionsRightRunning
				TextOptionsThis:=TextOptionsRight
			}
			else 
			{
				textx:=aimPosx+5
				textw:=ElementWidth/2
				TextOptionsmarkedThis:=TextOptionsLeftmarked
				TextOptionsRunningThis:=TextOptionsLeftRunning
				TextOptionsThis:=TextOptionsLeft
			}
			
			texth:=17
			
			texty:=aimPosy-texth
			
			
			
			if (drawElement.marked=true)
				Gdip_TextToGraphics(G, drawElement.ConnectionType, "x" ((textx-Offsetx)*zoomFactor) " y" ((texty-Offsety)*zoomFactor) TextOptionsmarkedThis , Font, (textw*zoomFactor), (texth*zoomFactor))
			if (tempElementHasRecentlyRun) ;If element has recently run
			{
				Gdip_TextToGraphics(G, drawElement.ConnectionType, "x" ((textx-Offsetx)*zoomFactor) " y" ((texty-Offsety)*zoomFactor) TextOptionsRunningThis , Font, (textw*zoomFactor), (texth*zoomFactor))
			}
			else
				Gdip_TextToGraphics(G, drawElement.ConnectionType, "x" ((textx-Offsetx)*zoomFactor) " y" ((texty-Offsety)*zoomFactor) TextOptionsThis , Font, (textw*zoomFactor), (texth*zoomFactor))
			
			
		}
		
		
		
		;MsgBox,% marked
		;msgbox,x%lin3x% y%lin3y% w%lin3w% h%lin3h%`nx%lin4x% y%lin4y% w%lin4w% h%lin4h%
		;msgbox,x%lin1x% y%lin1y% w%lin1w% h%lin1h%

		
		allConnections[drawID].CountOfParts:=0
		
		loop 5
		{
			if (drawElement.ConnectionType="exception")
			{
				if (drawElement.marked=true)
					Gdip_DrawLine(G, pPenMarkLin, ((lin%a_index%x-Offsetx)*zoomFactor), ((lin%a_index%y-Offsety)*zoomFactor), ((lin%a_index%x+lin%a_index%w-Offsetx)*zoomFactor) , ((lin%a_index%y+lin%a_index%h-Offsety)*zoomFactor))
				else
					Gdip_DrawLine(G, pPenRed , ((lin%a_index%x-Offsetx)*zoomFactor), ((lin%a_index%y-Offsety)*zoomFactor), ((lin%a_index%x+lin%a_index%w-Offsetx)*zoomFactor) , ((lin%a_index%y+lin%a_index%h-Offsety)*zoomFactor))
				if (tempElementHasRecentlyRun) ;If element has recently run
				{
					Gdip_DrawLine(G, pPenRunningLin , ((lin%a_index%x-Offsetx)*zoomFactor), ((lin%a_index%y-Offsety)*zoomFactor), ((lin%a_index%x+lin%a_index%w-Offsetx)*zoomFactor) , ((lin%a_index%y+lin%a_index%h-Offsety)*zoomFactor))
				}
			}
			else
			{
				if (drawElement.marked=true)
					Gdip_DrawLine(G, pPenMarkLin, ((lin%a_index%x-Offsetx)*zoomFactor), ((lin%a_index%y-Offsety)*zoomFactor), ((lin%a_index%x+lin%a_index%w-Offsetx)*zoomFactor) , ((lin%a_index%y+lin%a_index%h-Offsety)*zoomFactor))
				else
					Gdip_DrawLine(G, pPenBlack, ((lin%a_index%x-Offsetx)*zoomFactor), ((lin%a_index%y-Offsety)*zoomFactor), ((lin%a_index%x+lin%a_index%w-Offsetx)*zoomFactor) , ((lin%a_index%y+lin%a_index%h-Offsety)*zoomFactor))
				if (tempElementHasRecentlyRun)
					Gdip_DrawLine(G, pPenRunningLin, ((lin%a_index%x-Offsetx)*zoomFactor), ((lin%a_index%y-Offsety)*zoomFactor), ((lin%a_index%x+lin%a_index%w-Offsetx)*zoomFactor) , ((lin%a_index%y+lin%a_index%h-Offsety)*zoomFactor))
			}
			
			;~ ToolTip % drawElement.CountOfParts
			
			;Define area of parts
			allConnections[drawID]["part" a_index "x1"]:=((lin%a_index%x-20-Offsetx)*zoomFactor)
			allConnections[drawID]["part" a_index "y1"]:=((lin%a_index%y-20-Offsety)*zoomFactor)
			allConnections[drawID]["part" a_index "x2"]:=((lin%a_index%x+lin%a_index%w+20-Offsetx)*zoomFactor)
			allConnections[drawID]["part" a_index "y2"]:=((lin%a_index%y+lin%a_index%h+20-Offsety)*zoomFactor)
			
			;~ drawElement.ClickPriority:=200
		}
		allConnections[drawID].CountOfParts:=5
	}
	


	;Draw elements
	tempElementList:=[]
	tempElementList2:=[]
	for tempID, tempelement in allElements
	{
		if (tempelement.marked)
			tempElementList2[tempID]:=allElements[tempID].clone()
		else
			tempElementList[tempID]:=allElements[tempID].clone()
	}
	for tempID, tempelement in tempElementList2
	{
		tempElementList[tempID]:=tempelement
	}
	for drawID, drawElement in tempElementList
	{
		;Check whether element was recently running. This will paint it slightly red
		tempElementHasRecentlyRun:=false
		if (drawElement.lastRun>0) ;If element has recently run
		{
			if (a_tickcount-drawElement.lastRun<1000)
			{
				
				tempElementHasRecentlyRun:=true
				AnyRecentlyRunElementFound:=true
			}
			else
				allElements[drawID].delete(lastRun)
		}
		
		;~ MsgBox % strobj(drawelement)
		;~ d(drawElement)
		if (drawElement.Type="Trigger")
		{
			
			if (((drawElement.x+ElementWidth)<(Offsetx)) or ((drawElement.x)>(Offsetx+widthofguipic/zoomFactor)) or ((drawElement.y+ElementHeight)<(Offsety)) or ((drawElement.y)>(Offsety+heightofguipic/zoomFactor)))
			{
				continue
			}
			
			Gdip_FillRoundedRectangle(G, pBrushUnmark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor),(30*zoomFactor))
			Gdip_DrawroundedRectangle(G, pPenGrey, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor),(30*zoomFactor))
			
			if (drawElement.icon)
			{
				drawElementIcon(G,((drawElement.x-Offsetx)*zoomFactor),((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor), drawElement.icon) 
			}
			
			
			Gdip_TextToGraphics(G, drawElement.name, "x" ((drawElement.x-Offsetx)*zoomFactor +4) " y" ((drawElement.y-Offsety)*zoomFactor+4) " vCenter " TextOptions , Font, ((ElementWidth)*zoomFactor-8), ((ElementHeight)*zoomFactor-8))
			;~ ToolTip % drawElement.id " - " drawElement.marked
			if (drawElement.marked=true)
				Gdip_FillroundedRectangle(G, pBrushMark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor),(30*zoomFactor))
			
			if (drawElement.enabled)
			{
				tempX1:=drawElement.x + ElementWidth *0.8 - SizeOfButtons*0.5 - Offsetx
				tempX2:=tempX1 + (SizeOfButtons * pBitmapSwitchOn_W / pBitmapSwitchOn_size)
				tempY1:=drawElement.y + ElementHeight *0.25 - SizeOfButtons*0.5 - Offsety			
				tempY2:=tempY1 + (SizeOfButtons * pBitmapSwitchOn_H / pBitmapSwitchOn_size)
				Gdip_DrawImage(G, pBitmapSwitchOn, (tempX1 )*zoomFactor, (tempY1) *zoomFactor, (tempX2 - tempX1) *zoomFactor, (tempY2 - tempY1) *zoomFactor , 0, 0, pBitmapSwitchOn_w,pBitmapSwitchOn_H)
				
			}
			else
			{
				tempX1:=drawElement.x + ElementWidth *0.8 - SizeOfButtons*0.5 - Offsetx
				tempX2:=tempX1 + (SizeOfButtons * pBitmapSwitchOff_W / pBitmapSwitchOff_size)
				tempY1:=drawElement.y + ElementHeight *0.25 - SizeOfButtons*0.5 - Offsety			
				tempY2:=tempY1 + (SizeOfButtons * pBitmapSwitchOff_H / pBitmapSwitchOff_size)
				Gdip_DrawImage(G, pBitmapSwitchOff, (tempX1 )*zoomFactor, (tempY1) *zoomFactor, (tempX2 - tempX1) *zoomFactor, (tempY2 - tempY1) *zoomFactor , 0, 0, pBitmapSwitchOff_w, pBitmapSwitchOff_H)
			}
			
			if (drawElement.class = "trigger_manual" )
			{
				if (drawElement.defaultTrigger)
				{
					tempX1:=drawElement.x + ElementWidth *0.15 - SizeOfButtons*0.5 - Offsetx
					tempX2:=tempX1 + (SizeOfButtons * pBitmapStarFilled_W / pBitmapStarFilled_size)
					tempY1:=drawElement.y + ElementHeight *0.20 - SizeOfButtons*0.5 - Offsety			
					tempY2:=tempY1 + (SizeOfButtons * pBitmapStarFilled_H / pBitmapStarFilled_size)
					Gdip_DrawImage(G, pBitmapStarFilled, (tempX1 )*zoomFactor, (tempY1) *zoomFactor, (tempX2 - tempX1) *zoomFactor, (tempY2 - tempY1) *zoomFactor , 0, 0, pBitmapStarFilled_w,pBitmapStarFilled_H)
					
				}
				else
				{
					tempX1:=drawElement.x + ElementWidth *0.15 - SizeOfButtons*0.5 - Offsetx
					tempX2:=tempX1 + (SizeOfButtons * pBitmapStarEmpty_W / pBitmapStarEmpty_size)
					tempY1:=drawElement.y + ElementHeight *0.20 - SizeOfButtons*0.5 - Offsety			
					tempY2:=tempY1 + (SizeOfButtons * pBitmapStarEmpty_H / pBitmapStarEmpty_size)
					Gdip_DrawImage(G, pBitmapStarEmpty, (tempX1 )*zoomFactor, (tempY1) *zoomFactor, (tempX2 - tempX1) *zoomFactor, (tempY2 - tempY1) *zoomFactor , 0, 0, pBitmapStarEmpty_w, pBitmapStarEmpty_H)
				}
			}
			
			
			
			if (drawElement.state="Running") ;If element is running
			{
				Gdip_FillroundedRectangle(G, pBrushRunning, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor),(30*zoomFactor))
			}
			else if (tempElementHasRecentlyRun) ;If element has recently run
			{
				Gdip_FillroundedRectangle(G, pBrushLastRunning, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor),(30*zoomFactor))
			}
			
			;MsgBox,% "x" (drawElement.x*zoomFactor +4) "y" (drawElement.y*zoomFactor+4) TextOptions Font (180*zoomFactor-8) (135*zoomFactor-8)
			;Define area of parts
			allElements[drawID].part1x1:=((drawElement.x-Offsetx)*zoomFactor)
			allElements[drawID].part1y1:=((drawElement.y-Offsety)*zoomFactor)
			allElements[drawID].part1x2:=((drawElement.x+ElementWidth-Offsetx)*zoomFactor)
			allElements[drawID].part1y2:=((drawElement.y+ElementHeight-Offsety)*zoomFactor)
			;MsgBox,% "x1 " drawElement.part1x1 " y1 " drawElement.part1y1 " x2 " drawElement.part1x2 "y2" drawElement.part1y2
			allElements[drawID].CountOfParts:=1
			;~ drawElement.ClickPriority:=500
			
		}
		if (drawElement.Type="Action")
		{
			
			if (((drawElement.x+ElementWidth)<(Offsetx)) or ((drawElement.x)>(Offsetx+widthofguipic/zoomFactor)) or ((drawElement.y+ElementHeight)<(Offsety)) or ((drawElement.y)>(Offsety+heightofguipic/zoomFactor)))
			{
				continue
			}
			
			Gdip_FillRectangle(G, pBrushUnmark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor))
			Gdip_DrawRectangle(G, pPenGrey, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor))
			
			if (drawElement.icon)
			{
				drawElementIcon(G,((drawElement.x-Offsetx)*zoomFactor),((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor), drawElement.icon) 
			}
			
			;Gdip_TextToGraphics(G, drawElement.name, "x" ((drawElement.x-Offsetx)*zoomFactor +4) "y" ((drawElement.y-Offsety)*zoomFactor+4) TextOptions , Font, ((ElementWidth)*zoomFactor-8), ((ElementHeight)*zoomFactor-8))
			Gdip_TextToGraphics(G, drawElement.name, "x" ((drawElement.x-Offsetx)*zoomFactor +4) " y" ((drawElement.y-Offsety)*zoomFactor+4) " vCenter " TextOptions , Font, ((ElementWidth)*zoomFactor-8), (ElementHeight*zoomFactor-8))
			if (drawElement.marked=true)
				Gdip_FillRectangle(G, pBrushMark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor))
			if (drawElement.state="running") ;If element is running
			{
				Gdip_FillRectangle(G, pBrushRunning, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor))
			}
			else if (tempElementHasRecentlyRun) ;If element has recently run
			{
				Gdip_FillRectangle(G, pBrushLastRunning, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor))
			}
			;MsgBox, % element "`n" drawElement.marked
			
			
			
			;Define area of parts
			allElements[drawID].part1x1:=((drawElement.x-Offsetx)*zoomFactor)
			allElements[drawID].part1y1:=((drawElement.y-Offsety)*zoomFactor)
			allElements[drawID].part1x2:=((drawElement.x+ElementWidth-Offsetx)*zoomFactor)
			allElements[drawID].part1y2:=((drawElement.y+ElementHeight-Offsety)*zoomFactor)
			allElements[drawID].CountOfParts:=1
			;~ drawElement.ClickPriority:=500
			
			
		}
		if (drawElement.Type="Condition")
		{
			if (((drawElement.x+ElementWidth)<(Offsetx)) or ((drawElement.x)>(Offsetx+widthofguipic/zoomFactor)) or ((drawElement.y+ElementHeight)<(Offsety)) or ((drawElement.y)>(Offsety+heightofguipic/zoomFactor)))
			{
				continue
			}
			
			Gdip_FillRoundedRectangle(G, pBrushUnmark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor),(30*zoomFactor))
			;Gdip_FillPolygon(G, pBrushUnmark,((drawElement.x+ElementWidth/2)*zoomFactor) "," ((drawElement.y+0)*zoomFactor) "|" ((drawElement.x+ElementWidth)*zoomFactor) "," ((drawElement.y+ElementHeight/2)*zoomFactor) "|" ((drawElement.x+ElementWidth/2)*zoomFactor) "," ((drawElement.y+ElementHeight)*zoomFactor) "|" ((drawElement.x+0)*zoomFactor) "," ((drawElement.y+ElementHeight/2)*zoomFactor) "|" ((drawElement.x+ElementWidth/2)*zoomFactor) "," ((drawElement.y+0)*zoomFactor))
			Gdip_DrawLines(G, pPenGrey,((drawElement.x+ElementWidth/2-Offsetx)*zoomFactor) "," ((drawElement.y+0-Offsety)*zoomFactor) "|" ((drawElement.x+ElementWidth-Offsetx)*zoomFactor) "," ((drawElement.y+ElementHeight/2-Offsety)*zoomFactor) "|" ((drawElement.x+ElementWidth/2-Offsetx)*zoomFactor) "," ((drawElement.y+ElementHeight-Offsety)*zoomFactor) "|" ((drawElement.x+0-Offsetx)*zoomFactor) "," ((drawElement.y+ElementHeight/2-Offsety)*zoomFactor) "|" ((drawElement.x+ElementWidth/2-Offsetx)*zoomFactor) "," ((drawElement.y+0-Offsety)*zoomFactor))
			
			if (drawElement.icon)
			{
				drawElementIcon(G,((drawElement.x-Offsetx)*zoomFactor),((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor), drawElement.icon) 
			}
			
			Gdip_TextToGraphics(G, drawElement.name, "x" ((drawElement.x-Offsetx)*zoomFactor +4) " y" ((drawElement.y-Offsety)*zoomFactor+4) " vCenter " TextOptions , Font, (ElementWidth*zoomFactor-8), (ElementHeight*zoomFactor-8))
			if (drawElement.marked=true)
				Gdip_FillroundedRectangle(G, pBrushMark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor),(30*zoomFactor))
			
			if (drawElement.state="Running") ;If element is running
			{
				Gdip_FillroundedRectangle(G, pBrushRunning, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor),(30*zoomFactor))
			}
			else if (tempElementHasRecentlyRun) ;If element has recently run
			{
				Gdip_FillroundedRectangle(G, pBrushLastRunning, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor),(30*zoomFactor))
			}
			;Define area of parts
			allElements[drawID].part1x1:=((drawElement.x-Offsetx)*zoomFactor)
			allElements[drawID].part1y1:=((drawElement.y-Offsety)*zoomFactor)
			allElements[drawID].part1x2:=((drawElement.x+ElementWidth-Offsetx)*zoomFactor)
			allElements[drawID].part1y2:=((drawElement.y+ElementHeight-Offsety)*zoomFactor)
			allElements[drawID].CountOfParts:=1
			;~ drawElement.ClickPriority:=500
		}
		
		if (drawElement.Type="Loop")
		{
			if (((drawElement.x+ElementWidth)<(Offsetx)) or ((drawElement.x)>(Offsetx+widthofguipic/zoomFactor)) or ((drawElement.y+ElementHeight*4/3+drawElement.HeightOfVerticalBar)<(Offsety)) or ((drawElement.y)>(Offsety+heightofguipic/zoomFactor)))
			{
				continue
			}
			
			
			Gdip_FillRectangle(G, pBrushUnmark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor))
			Gdip_FillRectangle(G, pBrushUnmark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y+ElementHeight-Offsety)*zoomFactor), ((ElementWidth/8)*zoomFactor), ((drawElement.HeightOfVerticalBar)*zoomFactor))
			Gdip_FillRectangle(G, pBrushUnmark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y+ElementHeight+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight/3)*zoomFactor))
			Gdip_FillRectangle(G, pBrushRunning,  ((drawElement.x+(ElementWidth *3/4)-Offsetx)*zoomFactor), ((drawElement.y+ElementHeight+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor), ((ElementWidth *1/4)*zoomFactor), ((ElementHeight/3)*zoomFactor)) ;Break field
			
			Gdip_DrawLines(G, pPenGrey,((drawElement.x+0-Offsetx)*zoomFactor) "," ((drawElement.y+0-Offsety)*zoomFactor) "|" ((drawElement.x+ElementWidth-Offsetx)*zoomFactor) "," ((drawElement.y+0-Offsety)*zoomFactor) "|" ((drawElement.x+ElementWidth-Offsetx)*zoomFactor) "," ((drawElement.y+ElementHeight-Offsety)*zoomFactor) "|" ((drawElement.x+ElementWidth/8-Offsetx)*zoomFactor) "," ((drawElement.y+ElementHeight-Offsety)*zoomFactor) "|" ((drawElement.x+ElementWidth/8-Offsetx)*zoomFactor) "," ((drawElement.y+ElementHeight+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor) "|" ((drawElement.x+ElementWidth-Offsetx)*zoomFactor) "," ((drawElement.y+ElementHeight+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor) "|" ((drawElement.x+ElementWidth-Offsetx)*zoomFactor) "," ((drawElement.y+ElementHeight*4/3+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor) "|" ((drawElement.x-Offsetx)*zoomFactor) "," ((drawElement.y+ElementHeight*4/3+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor) "|" ((drawElement.x+0-Offsetx)*zoomFactor) "," ((drawElement.y+0-Offsety)*zoomFactor) )
			
			if (drawElement.icon)
			{
				drawElementIcon(G,((drawElement.x-Offsetx)*zoomFactor),((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor), drawElement.icon) 
			}
			
			Gdip_TextToGraphics(G, drawElement.name, "x" ((drawElement.x-Offsetx)*zoomFactor +4) " y" ((drawElement.y-Offsety)*zoomFactor+4) " vCenter " TextOptions , Font, (ElementWidth*zoomFactor-8), (ElementHeight*zoomFactor-8))
			Gdip_TextToGraphics(G, "break", "x" ((drawElement.x+(ElementWidth *3/4)-Offsetx)*zoomFactor ) " y" ((drawElement.y+ElementHeight+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor) " vCenter " TextOptionsSmall , Font, (ElementWidth*1/4*zoomFactor), (ElementHeight*1/3*zoomFactor)) ;Break text
			if (drawElement.marked=true)
			{
				;~ Gdip_FillRectangle(G, pBrushMark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor))
				Gdip_FillRectangle(G, pBrushMark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor))
				Gdip_FillRectangle(G, pBrushMark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y+ElementHeight-Offsety)*zoomFactor), ((ElementWidth/8)*zoomFactor), ((drawElement.HeightOfVerticalBar)*zoomFactor))
				Gdip_FillRectangle(G, pBrushMark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y+ElementHeight+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight/3)*zoomFactor))
			}
			
			if (drawElement.state="running") ;If element is running
			{
				;Gdip_FillRectangle(G, pBrushRunning, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor))
				Gdip_FillRectangle(G, pBrushRunning, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor))
				Gdip_FillRectangle(G, pBrushRunning, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y+ElementHeight-Offsety)*zoomFactor), ((ElementWidth/8)*zoomFactor), ((drawElement.HeightOfVerticalBar)*zoomFactor))
				Gdip_FillRectangle(G, pBrushRunning, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y+ElementHeight+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight/3)*zoomFactor))
			}
			else if (tempElementHasRecentlyRun) ;If element has recently run
			{
				;~ Gdip_FillRectangle(G, pBrushLastRunning, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor))
				Gdip_FillRectangle(G, pBrushLastRunning, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor))
				Gdip_FillRectangle(G, pBrushLastRunning, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y+ElementHeight-Offsety)*zoomFactor), ((ElementWidth/8)*zoomFactor), ((drawElement.HeightOfVerticalBar)*zoomFactor))
				Gdip_FillRectangle(G, pBrushLastRunning, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y+ElementHeight+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight/3)*zoomFactor))
			}
			;Define area of parts
			allElements[drawID].part1x1:=((drawElement.x-Offsetx)*zoomFactor)
			allElements[drawID].part1y1:=((drawElement.y-Offsety)*zoomFactor)
			allElements[drawID].part1x2:=((drawElement.x+ElementWidth-Offsetx)*zoomFactor)
			allElements[drawID].part1y2:=((drawElement.y+ElementHeight-Offsety)*zoomFactor)
			allElements[drawID].part2x1:=((drawElement.x-Offsetx)*zoomFactor)
			allElements[drawID].part2y1:=((drawElement.y+ElementHeight-Offsety)*zoomFactor)
			allElements[drawID].part2x2:=((drawElement.x+ElementWidth/8-Offsetx)*zoomFactor)
			allElements[drawID].part2y2:=((drawElement.y+ElementHeight+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor)
			allElements[drawID].part3x1:=((drawElement.x-Offsetx)*zoomFactor)
			allElements[drawID].part3y1:=((drawElement.y+ElementHeight+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor)
			allElements[drawID].part3x2:=((drawElement.x+ElementWidth*3/4-Offsetx)*zoomFactor)
			allElements[drawID].part3y2:=((drawElement.y+ElementHeight*4/3+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor)
			allElements[drawID].part4x1:=((drawElement.x+ElementWidth*3/4-Offsetx)*zoomFactor)
			allElements[drawID].part4y1:=((drawElement.y+ElementHeight+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor)
			allElements[drawID].part4x2:=((drawElement.x+ElementWidth-Offsetx)*zoomFactor)
			allElements[drawID].part4y2:=((drawElement.y+ElementHeight*4/3+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor)
			allElements[drawID].CountOfParts:=4
			;~ drawElement.ClickPriority:=500
		}
		
		
		
	}
	
	

	
	;Draw some icons near to the selected element, if only one is selected
	PlusButtonExist:=false
	PlusButton2Exist:=false
	TrashButtonExist:=false
	EditButtonExist:=false
	MoveButton1Exist:=false
	MoveButton2Exist:=false
	SwitchOnButtonExist:=false
	SwitchOffButtonExist:=false
	
	if (FlowObj.markedElements.count()=1)
	{
		for tempID, tempID2 in FlowObj.markedElements
		{
			markedElement:=tempID
		}
	}
	else
	{
		markedElement=
	}
	
	;~ MsgBox % share.markedelementscount
	if (markedElement!="" and FlowObj.draw.DrawMoveButtonUnderMouse!=true) ;  and FlowObj.draw.UserCurrentlyMovesAnElement!=true)
	{
		;~ SoundBeep
		IfInString,markedElement,connection
			tempElList:=allConnections
		else
			tempElList:=allElements
		
		
		
		;Move Button
		if (tempElList[markedElement].type = "connection")
		{
			middlePointOfMoveButton1X:=((tempElList[markedElement].part1x1 +  tempElList[markedElement].part1x2)/2  ) / zoomFactor 
			middlePointOfMoveButton1Y:=(tempElList[markedElement].part1y1 ) / zoomFactor +20
			
			middlePointOfMoveButton2X:=((tempElList[markedElement].part5x1 +  tempElList[markedElement].part5x2)/2  ) / zoomFactor 
			middlePointOfMoveButton2Y:=(tempElList[markedElement].part5y2 ) / zoomFactor  -20
			
			
			
			if not (abs(middlePointOfMoveButton2Y-middlePointOfMoveButton1Y)<(gridy*2) and abs(middlePointOfMoveButton2X-middlePointOfMoveButton1X) <(gridx*5)) ;Don't show if they overlap other buttons
			{
				Gdip_DrawImage(G, pBitmapMove, (middlePointOfMoveButton1X - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfMoveButton1Y - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
				
				Gdip_DrawImage(G, pBitmapMove, (middlePointOfMoveButton2X - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfMoveButton2Y - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
				
				MoveButton1Exist:=true
				MoveButton2Exist:=True
			}
		}
		
		;Edit Button
		;~ MsgBox % strobj(tempElList[markedElement])
		if ((tempElList[markedElement].type = "action" or  tempElList[markedElement].type = "condition" or tempElList[markedElement].type = "trigger" or tempElList[markedElement].type = "loop"))
		{
			middlePointOfEditButtonX:=tempElList[markedElement].x - ElementWidth *0.125 - SizeOfButtons*0.2 - Offsetx
			middlePointOfEditButtonY:=tempElList[markedElement].y +ElementWidth *0.375 - Offsety
			
		}
		else if (tempElList[markedElement].type = "connection")
		{
			
			middlePointOfEditButtonX:=((tempElList[markedElement].part3x1 +  tempElList[markedElement].part3x2)/2  ) / zoomFactor - SizeOfButtons*1.3
			middlePointOfEditButtonY:=((tempElList[markedElement].part3y1 + tempElList[markedElement].part3y2) /2   ) / zoomFactor 
		}
		Gdip_DrawImage(G, pBitmapEdit, (middlePointOfEditButtonX - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfEditButtonY - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
		EditButtonExist:=true
		
		
		;Trash Button
		if (tempElList[markedElement].type="action" or  tempElList[markedElement].type = "condition" or tempElList[markedElement].type = "trigger" or tempElList[markedElement].type = "connection" or tempElList[markedElement].type = "loop")
		{
			if (tempElList[markedElement].type = "connection")
			{
				middlePointOfTrashButtonX:=((tempElList[markedElement].part3x1 + tempElList[markedElement].part3x2)/2) / zoomFactor + SizeOfButtons*1.3
				middlePointOfTrashButtonY:=((tempElList[markedElement].part3y1 + tempElList[markedElement].part3y2)/2) / zoomFactor 
			}
			else
			{
				middlePointOfTrashButtonX:=tempElList[markedElement].x + ElementWidth *9/8 + SizeOfButtons*0.2 - Offsetx
				middlePointOfTrashButtonY:=tempElList[markedElement].y +ElementWidth *0.375 - Offsety
			}
			Gdip_DrawImage(G, pBitmapTrash, (middlePointOfTrashButtonX - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfTrashButtonY - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
			TrashButtonExist:=true
		}
		
		;Plus Button
		if (tempElList[markedElement].type = "connection")
		{
			middlePointOfPlusButtonX:=((tempElList[markedElement].part3x1 +  tempElList[markedElement].part3x2)/2  ) / zoomFactor 
			middlePointOfPlusButtonY:=((tempElList[markedElement].part3y1 + tempElList[markedElement].part3y2 )/2  ) / zoomFactor 
			Gdip_DrawImage(G, pBitmapPlus, (middlePointOfPlusButtonX - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfPlusButtonY - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
			PlusButtonExist:=true
		}
		else if ((tempElList[markedElement].type = "action" or  tempElList[markedElement].type = "condition" or tempElList[markedElement].type = "trigger" or tempElList[markedElement].type = "loop"))
		{
			middlePointOfPlusButtonX:=tempElList[markedElement].x + ElementWidth *0.5 - Offsetx
			middlePointOfPlusButtonY:=tempElList[markedElement].y +ElementWidth *7/8 + SizeOfButtons*0.2 - Offsety
			Gdip_DrawImage(G, pBitmapPlus, (middlePointOfPlusButtonX - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfPlusButtonY - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
			PlusButtonExist:=true
		}
		if (tempElList[markedElement].type = "loop") ;Additional plus button for loop
		{
			middlePointOfPlusButton2X:=tempElList[markedElement].x + ElementWidth *0.5 - Offsetx
			middlePointOfPlusButton2Y:=tempElList[markedElement].y +ElementWidth /8 + ElementHeight*4/3+tempElList[markedElement].HeightOfVerticalBar + SizeOfButtons*0.2 - Offsety
			Gdip_DrawImage(G, pBitmapPlus, (middlePointOfPlusButton2X - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfPlusButton2Y - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
			PlusButton2Exist:=true
			
		}
		
		;Switch on or off Button
		;~ MsgBox % strobj(tempElList[markedElement])
		if (tempElList[markedElement].type = "trigger" )
		{
			if (tempElList[markedElement].enabled)
			{
				PosOfSwitchOnButtonX1:=tempElList[markedElement].x + ElementWidth *0.8 - SizeOfButtons*0.5 - Offsetx
				PosOfSwitchOnButtonX2:=PosOfSwitchOnButtonX1 + (SizeOfButtons * pBitmapSwitchOn_W / pBitmapSwitchOn_size)
				PosOfSwitchOnButtonY1:=tempElList[markedElement].y + ElementHeight *0.25 - SizeOfButtons*0.5 - Offsety			
				PosOfSwitchOnButtonY2:=PosOfSwitchOnButtonY1 + (SizeOfButtons * pBitmapSwitchOn_H / pBitmapSwitchOn_size)
				Gdip_DrawImage(G, pBitmapSwitchOn, (PosOfSwitchOnButtonX1 )*zoomFactor, (PosOfSwitchOnButtonY1) *zoomFactor, (PosOfSwitchOnButtonX2 - PosOfSwitchOnButtonX1) *zoomFactor, (PosOfSwitchOnButtonY2 - PosOfSwitchOnButtonY1) *zoomFactor , 0, 0, pBitmapSwitchOn_w,pBitmapSwitchOn_H)
				SwitchOnButtonExist:=true
				
			}
			else
			{
				PosOfSwitchOffButtonX1:=tempElList[markedElement].x + ElementWidth *0.8 - SizeOfButtons*0.5 - Offsetx
				PosOfSwitchOffButtonX2:=PosOfSwitchOffButtonX1 + (SizeOfButtons * pBitmapSwitchOff_W / pBitmapSwitchOff_size)
				PosOfSwitchOffButtonY1:=tempElList[markedElement].y + ElementHeight *0.25 - SizeOfButtons*0.5 - Offsety			
				PosOfSwitchOffButtonY2:=PosOfSwitchOffButtonY1 + (SizeOfButtons * pBitmapSwitchOff_H / pBitmapSwitchOff_size)
				Gdip_DrawImage(G, pBitmapSwitchOff, (PosOfSwitchOffButtonX1 )*zoomFactor, (PosOfSwitchOffButtonY1) *zoomFactor, (PosOfSwitchOffButtonX2 - PosOfSwitchOffButtonX1) *zoomFactor, (PosOfSwitchOffButtonY2 - PosOfSwitchOffButtonY1) *zoomFactor , 0, 0, pBitmapSwitchOff_w, pBitmapSwitchOff_H)
				SwitchOffButtonExist:=true
			}
		}
		
		;Start filled or empty Button
		;~ MsgBox % strobj(tempElList[markedElement])
		if (tempElList[markedElement].class = "trigger_manual" )
		{
			if (tempElList[markedElement].defaultTrigger)
			{
				PosOfStarFilledButtonX1:=tempElList[markedElement].x + ElementWidth *0.15 - SizeOfButtons*0.5 - Offsetx
				PosOfStarFilledButtonX2:=PosOfStarFilledButtonX1 + (SizeOfButtons * pBitmapStarFilled_W / pBitmapStarFilled_size)
				PosOfStarFilledButtonY1:=tempElList[markedElement].y + ElementHeight *0.20 - SizeOfButtons*0.5 - Offsety			
				PosOfStarFilledButtonY2:=PosOfStarFilledButtonY1 + (SizeOfButtons * pBitmapStarFilled_H / pBitmapStarFilled_size)
				Gdip_DrawImage(G, pBitmapStarFilled, (PosOfStarFilledButtonX1 )*zoomFactor, (PosOfStarFilledButtonY1) *zoomFactor, (PosOfStarFilledButtonX2 - PosOfStarFilledButtonX1) *zoomFactor, (PosOfStarFilledButtonY2 - PosOfStarFilledButtonY1) *zoomFactor , 0, 0, pBitmapStarFilled_w,pBitmapStarFilled_H)
				StarFilledButtonExist:=true
				
			}
			else
			{
				PosOfStarEmptyButtonX1:=tempElList[markedElement].x + ElementWidth *0.15 - SizeOfButtons*0.5 - Offsetx
				PosOfStarEmptyButtonX2:=PosOfStarEmptyButtonX1 + (SizeOfButtons * pBitmapStarEmpty_W / pBitmapStarEmpty_size)
				PosOfStarEmptyButtonY1:=tempElList[markedElement].y + ElementHeight *0.20 - SizeOfButtons*0.5 - Offsety			
				PosOfStarEmptyButtonY2:=PosOfStarEmptyButtonY1 + (SizeOfButtons * pBitmapStarEmpty_H / pBitmapStarEmpty_size)
				Gdip_DrawImage(G, pBitmapStarEmpty, (PosOfStarEmptyButtonX1 )*zoomFactor, (PosOfStarEmptyButtonY1) *zoomFactor, (PosOfStarEmptyButtonX2 - PosOfStarEmptyButtonX1) *zoomFactor, (PosOfStarEmptyButtonY2 - PosOfStarEmptyButtonY1) *zoomFactor , 0, 0, pBitmapStarEmpty_w, pBitmapStarEmpty_H)
				StarEmptyButtonExist:=true
			}
		}
		
		
		
	}
	else if (FlowObj.draw.DrawMoveButtonUnderMouse=true)
	{
		middlePointOfMoveButtonX:=(GDImx)/zoomfactor 
		middlePointOfMoveButtonY:=(GDImy)/zoomfactor 
		
		Gdip_DrawImage(G, pBitmapMove, (middlePointOfMoveButtonX - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfMoveButtonY - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
		
	}
	
	;At the end draw the menu bar
	Gdip_FillRectangle(G, pBrushUnmark, ((0)*zoomFactor), ((0)*zoomFactor), ((NewElementIconWidth *1.2)*zoomFactor *4), ((NewElementIconHeight * 1.2)*zoomFactor)) ;Draw a white area
	
	;Draw an action
	;Gdip_FillRectangle(G, pBrushUnmark, ((ElementWidth *0.1)*zoomFactor), ((ElementHeight * 0.1)*zoomFactor), ((ElementWidth )*zoomFactor), ((ElementHeight )*zoomFactor))
	Gdip_DrawRectangle(G, pPenGrey, (((NewElementIconWidth *0.1))*zoomFactor), (((NewElementIconHeight * 0.1))*zoomFactor), ((NewElementIconWidth)*zoomFactor), ((NewElementIconHeight)*zoomFactor))
	Gdip_TextToGraphics(G, lang("Create new action"), "x" ((NewElementIconWidth *0.1)*zoomFactor+4) " y" ((NewElementIconHeight * 0.1)*zoomFactor+4) " vCenter " TextOptions , Font, ((NewElementIconWidth)*zoomFactor-8), ((NewElementIconHeight)*zoomFactor-8))
	
	;Draw a condition
	Gdip_DrawLines(G, pPenGrey,(((NewElementIconWidth *1.3)+NewElementIconWidth/2)*zoomFactor) "," (((NewElementIconHeight * 0.1)+0)*zoomFactor) "|" (((NewElementIconWidth *1.3)+NewElementIconWidth)*zoomFactor) "," (((NewElementIconHeight * 0.1)+NewElementIconHeight/2)*zoomFactor) "|" (((NewElementIconWidth *1.3)+NewElementIconWidth/2)*zoomFactor) "," (((NewElementIconHeight * 0.1)+NewElementIconHeight)*zoomFactor) "|" (((NewElementIconWidth *1.3)+0)*zoomFactor) "," (((NewElementIconHeight * 0.1)+NewElementIconHeight/2)*zoomFactor) "|" (((NewElementIconWidth *1.3)+NewElementIconWidth/2)*zoomFactor) "," (((NewElementIconHeight * 0.1)+0)*zoomFactor))
	Gdip_TextToGraphics(G, lang("Create new condition"), "x" ((NewElementIconWidth *1.3)*zoomFactor+4) " y" ((NewElementIconHeight * 0.1)*zoomFactor+4) " vCenter " TextOptions , Font, ((NewElementIconWidth)*zoomFactor-8), ((NewElementIconHeight)*zoomFactor-8))
	
	;Draw a loop
	Gdip_DrawLines(G, pPenGrey,((NewElementIconWidth *2.5)*zoomFactor) "," ((NewElementIconHeight * 0.1)*zoomFactor) "|" (((NewElementIconWidth *2.5)+NewElementIconWidth)*zoomFactor) "," ((NewElementIconHeight * 0.1)*zoomFactor) "|"  (((NewElementIconWidth *2.5)+NewElementIconWidth)*zoomFactor) "," (((NewElementIconHeight * 0.1)+NewElementIconHeight/2)*zoomFactor) "|"(((NewElementIconWidth *2.5)+NewElementIconWidth/6)*zoomFactor) "," (((NewElementIconHeight * 0.1)+NewElementIconHeight/2)*zoomFactor) "|" (((NewElementIconWidth *2.5)+NewElementIconWidth/6)*zoomFactor) "," (((NewElementIconHeight * 0.1)+NewElementIconHeight*5/6)*zoomFactor) "|" (((NewElementIconWidth *2.5)+NewElementIconWidth)*zoomFactor) "," (((NewElementIconHeight * 0.1)+NewElementIconHeight*5/6)*zoomFactor) "|" (((NewElementIconWidth *2.5)+NewElementIconWidth)*zoomFactor) "," (((NewElementIconHeight * 0.1)+NewElementIconHeight)*zoomFactor) "|" (((NewElementIconWidth *2.5))*zoomFactor) "," (((NewElementIconHeight * 0.1)+NewElementIconHeight)*zoomFactor) "|" ((NewElementIconWidth *2.5)*zoomFactor) "," ((NewElementIconHeight * 0.1)*zoomFactor)  )
	Gdip_TextToGraphics(G, lang("Create new loop"), "x" ((NewElementIconWidth *2.5)*zoomFactor+4) " y" ((NewElementIconHeight * 0.1)*zoomFactor+4) " vCenter " TextOptions , Font, ((NewElementIconWidth)*zoomFactor-8), ((NewElementIconHeight)*zoomFactor-8))
	
	;Draw a trigger
	Gdip_DrawroundedRectangle(G, pPenGrey, (((NewElementIconWidth *3.7))*zoomFactor), (((NewElementIconHeight * 0.1))*zoomFactor), ((NewElementIconWidth)*zoomFactor), ((NewElementIconHeight)*zoomFactor),(20*zoomFactor))
	Gdip_TextToGraphics(G, lang("Create new trigger"), "x" ((NewElementIconWidth *3.7)*zoomFactor+4) " y" ((NewElementIconHeight * 0.1)*zoomFactor+4) " vCenter " TextOptions , Font, ((NewElementIconWidth)*zoomFactor-8), ((NewElementIconHeight)*zoomFactor-8))
	

	FlowObj.draw.PlusButtonExist:=PlusButtonExist
	FlowObj.draw.PlusButton2Exist:=PlusButton2Exist
	FlowObj.draw.TrashButtonExist:=TrashButtonExist
	FlowObj.draw.EditButtonExist:=EditButtonExist
	FlowObj.draw.MoveButton1Exist:=MoveButton1Exist
	FlowObj.draw.MoveButton2Exist:=MoveButton2Exist	
	FlowObj.draw.SwitchOnButtonExist:=SwitchOnButtonExist
	FlowObj.draw.SwitchOffButtonExist:=SwitchOffButtonExist
	FlowObj.draw.StarFilledButtonExist:=StarFilledButtonExist
	FlowObj.draw.StarEmptyButtonExist:=StarEmptyButtonExist
	
	FlowObj.draw.middlePointOfPlusButtonX:=middlePointOfPlusButtonX * zoomFactor
	FlowObj.draw.middlePointOfPlusButton2X:=middlePointOfPlusButton2X * zoomFactor
	FlowObj.draw.middlePointOfEditButtonX:=middlePointOfEditButtonX * zoomFactor
	FlowObj.draw.middlePointOfTrashButtonX:=middlePointOfTrashButtonX * zoomFactor
	FlowObj.draw.middlePointOfMoveButton2X:=middlePointOfMoveButton2X * zoomFactor
	FlowObj.draw.middlePointOfMoveButton1X:=middlePointOfMoveButton1X * zoomFactor
	FlowObj.draw.middlePointOfPlusButtonY:=middlePointOfPlusButtonY * zoomFactor
	FlowObj.draw.middlePointOfPlusButton2Y:=middlePointOfPlusButton2Y * zoomFactor
	FlowObj.draw.middlePointOfEditButtonY:=middlePointOfEditButtonY * zoomFactor
	FlowObj.draw.middlePointOfTrashButtonY:=middlePointOfTrashButtonY * zoomFactor
	FlowObj.draw.middlePointOfMoveButton2Y:=middlePointOfMoveButton2Y * zoomFactor
	FlowObj.draw.middlePointOfMoveButton1Y:=middlePointOfMoveButton1Y * zoomFactor
	FlowObj.draw.PosOfSwitchOffButtonX1:=PosOfSwitchOffButtonX1 * zoomFactor
	FlowObj.draw.PosOfSwitchOffButtonX2:=PosOfSwitchOffButtonX2 * zoomFactor
	FlowObj.draw.PosOfSwitchOffButtonY1:=PosOfSwitchOffButtonY1 * zoomFactor
	FlowObj.draw.PosOfSwitchOffButtonY2:=PosOfSwitchOffButtonY2	* zoomFactor
	FlowObj.draw.PosOfSwitchOnButtonX1:=PosOfSwitchOnButtonX1 * zoomFactor
	FlowObj.draw.PosOfSwitchOnButtonX2:=PosOfSwitchOnButtonX2 * zoomFactor
	FlowObj.draw.PosOfSwitchOnButtonY1:=PosOfSwitchOnButtonY1 * zoomFactor
	FlowObj.draw.PosOfSwitchOnButtonY2:=PosOfSwitchOnButtonY2 * zoomFactor
	FlowObj.draw.PosOfStarEmptyButtonX1:=PosOfStarEmptyButtonX1 * zoomFactor
	FlowObj.draw.PosOfStarEmptyButtonX2:=PosOfStarEmptyButtonX2 * zoomFactor
	FlowObj.draw.PosOfStarEmptyButtonY1:=PosOfStarEmptyButtonY1 * zoomFactor
	FlowObj.draw.PosOfStarEmptyButtonY2:=PosOfStarEmptyButtonY2	* zoomFactor
	FlowObj.draw.PosOfStarFilledButtonX1:=PosOfStarFilledButtonX1 * zoomFactor
	FlowObj.draw.PosOfStarFilledButtonX2:=PosOfStarFilledButtonX2 * zoomFactor
	FlowObj.draw.PosOfStarFilledButtonY1:=PosOfStarFilledButtonY1 * zoomFactor
	FlowObj.draw.PosOfStarFilledButtonY2:=PosOfStarFilledButtonY2 * zoomFactor
	
	
	FlowObj.draw.NewElementIconWidth:=NewElementIconWidth * zoomFactor
	FlowObj.draw.NewElementIconHeight:=NewElementIconHeight * zoomFactor
	
	
	
	;~ Gdip_TextToGraphics(G, OnTopLabel, "x10 y0 " TextOptionsTopLabel, Font, widthofguipic, heightofguipic)
	
	
	;~ MsgBox %mainguiHwnddc%
	;Show the image
	BitBlt(_share.hwnds["editGUIDC" FlowID], 0, 0, widthofguipic, heightofguipic, hdc, 0, 0)

	; Now the bitmap may be deleted
	DeleteObject(hbm)

	; Also the device context related to the bitmap may be deleted
	DeleteDC(hdc)
	;delete bitmaps
	Gdip_DeleteGraphics(G)
	
	DrawingRightNow:=false
	
	
	if (AnyRecentlyRunElementFound)
		_flows[flowID].draw.mustDraw:=true
	
	
	Return

}

drawElementIcon(G, p_x, p_y, p_w, p_h ,path)
{
	global my_ScriptDir
	static allElementIconBitmaps:=Object()
	
	if (allElementIconBitmaps.haskey(path))
	{
		BitmapIcon:=allElementIconBitmaps[path]
	}
	else
	{
		BitmapIcon := Gdip_CreateBitmapFromFile(my_ScriptDir "\" path)
		allElementIconBitmaps[path]:=BitmapIcon
	}
	
	sw:=Gdip_GetImageWidth(BitmapIcon)
	sh:=Gdip_GetImageHeight(BitmapIcon)
	if (p_w/p_h > sw/sh)
	{
		h := p_h
		w := h*sw/sh
		y:=p_y
		x:=p_x + p_w/2 - w/2
	}
	else
	{
		w := p_w
		h := w*sh/sw
		x:=p_x
		y:=p_y + p_h/2 - h/2
	}
	
	Gdip_DrawImage(G, BitmapIcon, x, y, w, h ,,,,,0.2)
	
}