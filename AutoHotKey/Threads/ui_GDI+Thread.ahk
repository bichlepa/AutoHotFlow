;Here at the top there will be something like this line:
; share:=Criticalobject(1234)
;The object share contains values which are shared among this and other threads

#Persistent
#include language\language.ahk ;Must be very first
#include External Scripts\gdi+\gdip.ahk
#include External Scripts\Object to file\String-object-file.ahk

;initialize languages
lang_FindAllLanguages()

;Initialize values at the beginning
GridX:=share.GDIPars.GridX
Gridy:=share.GDIPars.Gridy
GridyOffset:=share.GDIPars.GridyOffset
ElementWidth:=share.GDIPars.ElementWidth
ElementHeight:=share.GDIPars.ElementHeight
NewElementIconWidth:=share.GDIPars.NewElementIconWidth
NewElementIconHeight:=share.GDIPars.NewElementIconHeight
MinimumHeightOfConnection:=share.GDIPars.MinimumHeightOfConnection
SizeOfButtons:=share.GDIPars.SizeOfButtons
textSize:=share.GDIPars.textSize
zoomFactorMin:=share.GDIPars.zoomFactorMin
zoomFactorMax:=share.GDIPars.zoomFactorMax
VisibleArea:=[]
;~ OnTopLabel=

;~ MsgBox %GridX% %Gridy%
GDIPars.DrawPlusUnderMouse:=false


CoordMode,mouse,client

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
pBrushRunning := Gdip_BrushCreateSolid("0x50ff0000") ;Red brush, transparent
pBrushLastRunning := Gdip_BrushCreateSolid("0x10ff0000") ;Red brush, very transparent
pBrushBackground := Gdip_BrushCreateSolid("0xFFeaf0ea") ;Almost white brush for background





mainguiHwnddc := GetDC(MainGuihwnd) ;Needed by GDI+


;Called by the main thread
;it prepares some values and starts a timer which calls UI_drawEverything()
ui_DrawThread()
{
	global
	;~ SoundBeep 2000
	;~ ToolTip redraw %par% %mainguihwnd% %GridX%
	;~ return
	local temp
	DetectHiddenWindows off
	WinGetTitle,temp,% "ahk_id " mainguihwnd
	;~ ToolTip %temp%
	IfWinExist,% temp
	{
		DetectHiddenWindows on
		
		Offsetx:=share.GDIPars.Offsetx
		Offsety:=share.GDIPars.Offsety
		zoomFactor:=share.GDIPars.zoomFactor
		widthofguipic:=share.GDIPars.widthofguipic
		heightofguipic:=share.GDIPars.heightofguipic
		TheOnlyOneMarkedElement:=share.TheOnlyOneMarkedElement
		;~ ToolTip % strobj(TheOnlyOneMarkedElement)
		;Check whether the zoomfactor is inside the allowed bounds
		if (zoomFactor<zoomFactorMin)
			zoomFactor:=zoomFactorMin
		if (zoomFactor>zoomFactorMax)
			zoomFactor:=zoomFactorMax
		;~ ToolTip %widthofguipic% - %heightofguipic%
		;Prevent that the function ui_DrawEverything() is called twice at same time. Under sircumstances this would cause a crash.
		if (DrawingRightNow=true)
		{
			
			DrawAgain:=true
			
			
			;MsgBox DrawingRightNow %DrawingRightNow%
			
			return
		}
		else
		{
			SetTimer,ui_drawEverything,10
			;~ ui_drawEverything(widthofguipic,heightofguipic)
		}
		
	}

	DetectHiddenWindows on
	
	;~ SetTimer,ui_regularUpdateIfWinMoved,100
}



;Draws everything in the main GUI
ui_DrawEverything()
{
	global
	Posw:=widthofguipic
	Posh:=heightofguipic
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
	;~ ToolTip %posw% %posh%
	;~ return
	;~ MsgBox % strobj(share.allElements)
	;~ Critical,on
	
	DrawingRightNow:=true
	
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
	
	
	if (share.GDIPars.DrawMoveButtonUnderMouse=true or tempFromEl="MOUSE" or tempToEl="MOUSE")
	{
		MouseGetPos,tempmx,tempmy,tempmwin,,2 ;Get the mouse position
		if (tempmwin=mainguihwnd)
		{
			;~ SoundBeep 200
			GDImx:=tempmx
			GDImy:=tempmy
		}
		;~ else
			;~ SoundBeep 2000
	}
	
	
	hbm := CreateDIBSection(Posw, Posh)
	hdc := CreateCompatibleDC()
	obm := SelectObject(hdc, hbm)
	G := Gdip_GraphicsFromHDC(hdc)
	Gdip_SetSmoothingMode(G, 4) ;We will also set the smoothing mode of the graphics to 4 (Antialias) to make the shapes we use smooth
	
	
	
	Gdip_FillRectangle(G, pBrushBackground, 0, 0, posw,posh)

	;~ pBitmap := Gdip_CreateBitmap(Posw, Posh)
	;~ G := Gdip_GraphicsFromImage(pBitmap)
	;~ Gdip_SetSmoothingMode(G, 4)
	
	VisibleArea.X1:=Offsetx
	VisibleArea.Y1:=Offsety
	VisibleArea.X2:=Offsetx+widthofguipic/zoomFactor
	VisibleArea.Y2:=Offsety+heightofguipic/zoomFactor
	VisibleArea.W:=VisibleArea.X2-VisibleArea.X1
	VisibleArea.H:=VisibleArea.Y2-VisibleArea.Y1
	
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
	for index, tempelement in share.allConnections
	{
		if (tempelement.marked)
			tempElementList2.push(tempelement)
		else
			tempElementList.push(tempelement)
	}
	for index, tempelement in tempElementList2
	{
		tempElementList.push(tempelement)
	}
	for index, drawElement in tempElementList
	{
		
		tempFromEl:=share.allElements[drawElement.from]
		if (not isobject(tempFromEl))
			tempFromEl:=drawElement.from
		tempToEl:=share.allElements[drawElement.to]
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
			else
				drawElement.delete(lastRun)
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
		
		
		
		drawElement.CountOfParts:=0
		
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
			
			;Define area of parts
			drawElement["part" a_index "x1"]:=((lin%a_index%x-20-Offsetx)*zoomFactor)
			drawElement["part" a_index "y1"]:=((lin%a_index%y-20-Offsety)*zoomFactor)
			drawElement["part" a_index "x2"]:=((lin%a_index%x+lin%a_index%w+20-Offsetx)*zoomFactor)
			drawElement["part" a_index "y2"]:=((lin%a_index%y+lin%a_index%h+20-Offsety)*zoomFactor)
			drawElement.CountOfParts++
			;~ drawElement.ClickPriority:=200
		}
		
	}
	
	
	
	;Draw elements
	tempElementList:=[]
	tempElementList2:=[]
	for index, tempelement in share.allElements
	{
		if (tempelement.marked)
			tempElementList2.push(tempelement)
		else
			tempElementList.push(tempelement)
	}
	for index, tempelement in tempElementList2
	{
		tempElementList.push(tempelement)
	}
	for index, drawElement in tempElementList
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
				drawElement.delete(lastRun)
		}
		
		;~ MsgBox % strobj(drawelement)
		
		if (drawElement.Type="Trigger")
		{
			if (((drawElement.x+ElementWidth)<(Offsetx)) or ((drawElement.x)>(Offsetx+widthofguipic/zoomFactor)) or ((drawElement.y+ElementHeight)<(Offsety)) or ((drawElement.y)>(Offsety+heightofguipic/zoomFactor)))
			{
				continue
			}
			
			Gdip_FillRoundedRectangle(G, pBrushUnmark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor),(30*zoomFactor))
			Gdip_DrawroundedRectangle(G, pPenGrey, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor),(30*zoomFactor))
			Gdip_TextToGraphics(G, drawElement.name, "x" ((drawElement.x-Offsetx)*zoomFactor +4) " y" ((drawElement.y-Offsety)*zoomFactor+4) " vCenter " TextOptions , Font, ((ElementWidth)*zoomFactor-8), ((ElementHeight)*zoomFactor-8))
			;~ ToolTip % drawElement.id " - " drawElement.marked
			if (drawElement.marked=true)
				Gdip_FillroundedRectangle(G, pBrushMark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor),(30*zoomFactor))
			if (drawElement.isRunning) ;If element is running
			{
				Gdip_FillroundedRectangle(G, pBrushRunning, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor),(30*zoomFactor))
			}
			else if (tempElementHasRecentlyRun) ;If element has recently run
			{
				Gdip_FillroundedRectangle(G, pBrushLastRunning, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor),(30*zoomFactor))
			}
			
			;MsgBox,% "x" (drawElement.x*zoomFactor +4) "y" (drawElement.y*zoomFactor+4) TextOptions Font (180*zoomFactor-8) (135*zoomFactor-8)
			;Define area of parts
			drawElement.part1x1:=((drawElement.x-Offsetx)*zoomFactor)
			drawElement.part1y1:=((drawElement.y-Offsety)*zoomFactor)
			drawElement.part1x2:=((drawElement.x+ElementWidth-Offsetx)*zoomFactor)
			drawElement.part1y2:=((drawElement.y+ElementHeight-Offsety)*zoomFactor)
			;MsgBox,% "x1 " drawElement.part1x1 " y1 " drawElement.part1y1 " x2 " drawElement.part1x2 "y2" drawElement.part1y2
			drawElement.CountOfParts:=1
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
			;Gdip_TextToGraphics(G, drawElement.name, "x" ((drawElement.x-Offsetx)*zoomFactor +4) "y" ((drawElement.y-Offsety)*zoomFactor+4) TextOptions , Font, ((ElementWidth)*zoomFactor-8), ((ElementHeight)*zoomFactor-8))
			Gdip_TextToGraphics(G, drawElement.name, "x" ((drawElement.x-Offsetx)*zoomFactor +4) " y" ((drawElement.y-Offsety)*zoomFactor+4) " vCenter " TextOptions , Font, ((ElementWidth)*zoomFactor-8), (ElementHeight*zoomFactor-8))
			if (drawElement.marked=true)
				Gdip_FillRectangle(G, pBrushMark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor))
			if (drawElement.isrunning) ;If element is running
			{
				Gdip_FillRectangle(G, pBrushRunning, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor))
			}
			else if (tempElementHasRecentlyRun) ;If element has recently run
			{
				Gdip_FillRectangle(G, pBrushLastRunning, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor))
			}
			;MsgBox, % element "`n" drawElement.marked
			
			;Define area of parts
			drawElement.part1x1:=((drawElement.x-Offsetx)*zoomFactor)
			drawElement.part1y1:=((drawElement.y-Offsety)*zoomFactor)
			drawElement.part1x2:=((drawElement.x+ElementWidth-Offsetx)*zoomFactor)
			drawElement.part1y2:=((drawElement.y+ElementHeight-Offsety)*zoomFactor)
			drawElement.CountOfParts:=1
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
			
			Gdip_TextToGraphics(G, drawElement.name, "x" ((drawElement.x-Offsetx)*zoomFactor +4) " y" ((drawElement.y-Offsety)*zoomFactor+4) " vCenter " TextOptions , Font, (ElementWidth*zoomFactor-8), (ElementHeight*zoomFactor-8))
			if (drawElement.marked=true)
				Gdip_FillroundedRectangle(G, pBrushMark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor),(30*zoomFactor))
			
			if (drawElement.isrunning) ;If element is running
			{
				Gdip_FillroundedRectangle(G, pBrushRunning, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor),(30*zoomFactor))
			}
			else if (tempElementHasRecentlyRun) ;If element has recently run
			{
				Gdip_FillroundedRectangle(G, pBrushLastRunning, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor),(30*zoomFactor))
			}
			;Define area of parts
			drawElement.part1x1:=((drawElement.x-Offsetx)*zoomFactor)
			drawElement.part1y1:=((drawElement.y-Offsety)*zoomFactor)
			drawElement.part1x2:=((drawElement.x+ElementWidth-Offsetx)*zoomFactor)
			drawElement.part1y2:=((drawElement.y+ElementHeight-Offsety)*zoomFactor)
			drawElement.CountOfParts:=1
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
			
			Gdip_TextToGraphics(G, drawElement.name, "x" ((drawElement.x-Offsetx)*zoomFactor +4) " y" ((drawElement.y-Offsety)*zoomFactor+4) " vCenter " TextOptions , Font, (ElementWidth*zoomFactor-8), (ElementHeight*zoomFactor-8))
			Gdip_TextToGraphics(G, "break", "x" ((drawElement.x+(ElementWidth *3/4)-Offsetx)*zoomFactor ) " y" ((drawElement.y+ElementHeight+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor) " vCenter " TextOptionsSmall , Font, (ElementWidth*1/4*zoomFactor), (ElementHeight*1/3*zoomFactor)) ;Break text
			if (drawElement.marked=true)
			{
				;~ Gdip_FillRectangle(G, pBrushMark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), (ElementWidth*zoomFactor), (ElementHeight*zoomFactor))
				Gdip_FillRectangle(G, pBrushMark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight)*zoomFactor))
				Gdip_FillRectangle(G, pBrushMark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y+ElementHeight-Offsety)*zoomFactor), ((ElementWidth/8)*zoomFactor), ((drawElement.HeightOfVerticalBar)*zoomFactor))
				Gdip_FillRectangle(G, pBrushMark, ((drawElement.x-Offsetx)*zoomFactor), ((drawElement.y+ElementHeight+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor), ((ElementWidth)*zoomFactor), ((ElementHeight/3)*zoomFactor))
			}
			
			if (drawElement.isrunning) ;If element is running
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
			drawElement.part1x1:=((drawElement.x-Offsetx)*zoomFactor)
			drawElement.part1y1:=((drawElement.y-Offsety)*zoomFactor)
			drawElement.part1x2:=((drawElement.x+ElementWidth-Offsetx)*zoomFactor)
			drawElement.part1y2:=((drawElement.y+ElementHeight-Offsety)*zoomFactor)
			drawElement.part2x1:=((drawElement.x-Offsetx)*zoomFactor)
			drawElement.part2y1:=((drawElement.y+ElementHeight-Offsety)*zoomFactor)
			drawElement.part2x2:=((drawElement.x+ElementWidth/8-Offsetx)*zoomFactor)
			drawElement.part2y2:=((drawElement.y+ElementHeight+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor)
			drawElement.part3x1:=((drawElement.x-Offsetx)*zoomFactor)
			drawElement.part3y1:=((drawElement.y+ElementHeight+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor)
			drawElement.part3x2:=((drawElement.x+ElementWidth*3/4-Offsetx)*zoomFactor)
			drawElement.part3y2:=((drawElement.y+ElementHeight*4/3+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor)
			drawElement.part4x1:=((drawElement.x+ElementWidth*3/4-Offsetx)*zoomFactor)
			drawElement.part4y1:=((drawElement.y+ElementHeight+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor)
			drawElement.part4x2:=((drawElement.x+ElementWidth-Offsetx)*zoomFactor)
			drawElement.part4y2:=((drawElement.y+ElementHeight*4/3+drawElement.HeightOfVerticalBar-Offsety)*zoomFactor)
			drawElement.CountOfParts:=4
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
	;~ MsgBox % share.markedelementscount
	if (share.markedelementscount=1 and share.GDIPars.DrawMoveButtonUnderMouse!=true and share.GDIPars.UserCurrentlyMovesAnElement!=true)
	{
		
		pBitmapEdit := Gdip_CreateBitmapFromFile("Icons\edit.ico")
		pBitmapPlus := Gdip_CreateBitmapFromFile("Icons\plus.ico")
		pBitmapMove := Gdip_CreateBitmapFromFile("Icons\move.ico")
		pBitmapTrash := Gdip_CreateBitmapFromFile("Icons\trash.ico")
		
		;Move Button
		if (TheOnlyOneMarkedElement.type = "connection")
		{
			tempFromEl:=share.allelements[TheOnlyOneMarkedElement.from]
			tempToEl:=share.allelements[TheOnlyOneMarkedElement.to]
			
			
			if (tempFromEl.type="loop")
			{

				if (TheOnlyOneMarkedElement.ConnectionType="Normal")
				{
					if (TheOnlyOneMarkedElement.fromPart="HEAD")
					{
						middlePointOfMoveButton1X:=tempFromEl.x + ElementWidth *0.5 - Offsetx
						middlePointOfMoveButton1Y:=tempFromEl.y +ElementHeight - Offsety
					}
					else
					{
						middlePointOfMoveButton1X:=tempFromEl.x + ElementWidth *0.5 - Offsetx
						middlePointOfMoveButton1Y:=tempFromEl.y + tempFromEl.HeightOfVerticalBar+ElementHeight*4/3 - Offsety
					}
				}
				else
				{
					middlePointOfMoveButton1X:=tempFromEl.x + ElementWidth *0.5 - Offsetx
					middlePointOfMoveButton1Y:=tempFromEl.y + tempFromEl.HeightOfVerticalBar+ElementHeight*4/3 - Offsety
					}
			}
			else
			{
				middlePointOfMoveButton1X:=tempFromEl.x + ElementWidth *0.5 - Offsetx
				middlePointOfMoveButton1Y:=tempFromEl.y +ElementHeight  - Offsety
			}
			
			
			
			if (tempToEl.type="loop")
			{

				if (TheOnlyOneMarkedElement.toPart="HEAD")
				{
					middlePointOfMoveButton2X:=tempToEl.x + ElementWidth *0.5 - Offsetx
					middlePointOfMoveButton2Y:=tempToEl.y  - Offsety
				}
				else if (TheOnlyOneMarkedElement.toPart="BREAK")
				{
					middlePointOfMoveButton2X:=tempToEl.x + ElementWidth *7/8 - Offsetx
					middlePointOfMoveButton2Y:=tempToEl.y + tempToEl.HeightOfVerticalBar+ElementHeight - Offsety
				}
				else
				{
					 middlePointOfMoveButton2X:=tempToEl.x + ElementWidth *0.5 - Offsetx
					middlePointOfMoveButton2Y:=tempToEl.y + tempToEl.HeightOfVerticalBar+ElementHeight - Offsety
				}
				
			}
			else
			{
				middlePointOfMoveButton2X:=tempToEl.x + ElementWidth *0.5 - Offsetx
				middlePointOfMoveButton2Y:=tempToEl.y  - Offsety
			}
			
			Gdip_DrawImage(G, pBitmapMove, (middlePointOfMoveButton1X - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfMoveButton1Y - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
			
			
			Gdip_DrawImage(G, pBitmapMove, (middlePointOfMoveButton2X - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfMoveButton2Y - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
			
			MoveButton1Exist:=true
			MoveButton2Exist:=True
		}
		
		
		;Edit Button
		if ((TheOnlyOneMarkedElement.type = "action" or  TheOnlyOneMarkedElement.type = "condition" or TheOnlyOneMarkedElement.type = "trigger" or TheOnlyOneMarkedElement.type = "loop"))
		{
			middlePointOfEditButtonX:=TheOnlyOneMarkedElement.x - ElementWidth *0.125 - SizeOfButtons*0.2 - Offsetx
			middlePointOfEditButtonY:=TheOnlyOneMarkedElement.y +ElementWidth *0.375 - Offsety
			
		}
		else if (TheOnlyOneMarkedElement.type = "connection")
		{
			middlePointOfEditButtonX:=((TheOnlyOneMarkedElement.part3x1 +  TheOnlyOneMarkedElement.part3x2)/2  ) / zoomFactor - SizeOfButtons*1.3
			middlePointOfEditButtonY:=(TheOnlyOneMarkedElement.part3y1   ) / zoomFactor + SizeOfButtons*0.5 
		}
		Gdip_DrawImage(G, pBitmapEdit, (middlePointOfEditButtonX - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfEditButtonY - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
		EditButtonExist:=true
		
		;Trash Button
		if (TheOnlyOneMarkedElement.type="action" or  TheOnlyOneMarkedElement.type = "condition" or TheOnlyOneMarkedElement.type = "connection" or TheOnlyOneMarkedElement.type = "loop")
		{
			if (TheOnlyOneMarkedElement.type = "connection")
			{
				middlePointOfTrashButtonX:=((TheOnlyOneMarkedElement.part3x1 +  TheOnlyOneMarkedElement.part3x2)/2  ) / zoomFactor + SizeOfButtons*1.3
				middlePointOfTrashButtonY:=(TheOnlyOneMarkedElement.part3y1  ) / zoomFactor + SizeOfButtons*0.5 
			}
			else
			{
				middlePointOfTrashButtonX:=TheOnlyOneMarkedElement.x + ElementWidth *9/8 + SizeOfButtons*0.2 - Offsetx
				middlePointOfTrashButtonY:=TheOnlyOneMarkedElement.y +ElementWidth *0.375 - Offsety
			}
			Gdip_DrawImage(G, pBitmapTrash, (middlePointOfTrashButtonX - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfTrashButtonY - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
			TrashButtonExist:=true
		}
		
		;Plus Button
		if (TheOnlyOneMarkedElement.type = "connection")
		{
			middlePointOfPlusButtonX:=((TheOnlyOneMarkedElement.part3x1 +  TheOnlyOneMarkedElement.part3x2)/2  ) / zoomFactor 
			middlePointOfPlusButtonY:=(TheOnlyOneMarkedElement.part3y1  ) / zoomFactor + SizeOfButtons*0.5 
			Gdip_DrawImage(G, pBitmapPlus, (middlePointOfPlusButtonX - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfPlusButtonY - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
			PlusButtonExist:=true
		}
		else if ((TheOnlyOneMarkedElement.type = "action" or  TheOnlyOneMarkedElement.type = "condition" or TheOnlyOneMarkedElement.type = "trigger" or TheOnlyOneMarkedElement.type = "loop"))
		{
			middlePointOfPlusButtonX:=TheOnlyOneMarkedElement.x + ElementWidth *0.5 - Offsetx
			middlePointOfPlusButtonY:=TheOnlyOneMarkedElement.y +ElementWidth *7/8 + SizeOfButtons*0.2 - Offsety
			Gdip_DrawImage(G, pBitmapPlus, (middlePointOfPlusButtonX - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfPlusButtonY - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
			PlusButtonExist:=true
		}
		if (TheOnlyOneMarkedElement.type = "loop") ;Additional plus button for loop
		{
			middlePointOfPlusButton2X:=TheOnlyOneMarkedElement.x + ElementWidth *0.5 - Offsetx
			middlePointOfPlusButton2Y:=TheOnlyOneMarkedElement.y +ElementWidth /8 + ElementHeight*4/3+TheOnlyOneMarkedElement.HeightOfVerticalBar + SizeOfButtons*0.2 - Offsety
			Gdip_DrawImage(G, pBitmapPlus, (middlePointOfPlusButton2X - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfPlusButton2Y - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
			PlusButton2Exist:=true
			
		}
		
		
	}
	else if (share.GDIPars.DrawMoveButtonUnderMouse=true)
	{
		middlePointOfMoveButtonX:=(GDImx)/zoomfactor 
		middlePointOfMoveButtonY:=(GDImy)/zoomfactor 
		
		Gdip_DrawImage(G, pBitmapMove, (middlePointOfMoveButtonX - (SizeOfButtons*0.5) )*zoomFactor, ( middlePointOfMoveButtonY - (SizeOfButtons*0.5)) *zoomFactor, SizeOfButtons*zoomFactor, SizeOfButtons*zoomFactor , 0, 0, 48, 48)
		
	}
	
	;At the end draw the menu bar
	Gdip_FillRectangle(G, pBrushUnmark, ((0)*zoomFactor), ((0)*zoomFactor), ((NewElementIconWidth *1.2)*zoomFactor *3), ((NewElementIconHeight * 1.2)*zoomFactor)) ;Draw a white area
	
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
	

	share.PlusButtonExist:=PlusButtonExist
	share.PlusButton2Exist:=PlusButton2Exist
	share.TrashButtonExist:=TrashButtonExist
	share.EditButtonExist:=EditButtonExist
	share.MoveButton1Exist:=MoveButton1Exist
	share.MoveButton2Exist:=MoveButton2Exist
	
	share.middlePointOfPlusButtonX:=middlePointOfPlusButtonX
	share.middlePointOfPlusButton2X:=middlePointOfPlusButton2X
	share.middlePointOfEditButtonX:=middlePointOfEditButtonX
	share.middlePointOfTrashButtonX:=middlePointOfTrashButtonX
	share.middlePointOfMoveButton2X:=middlePointOfMoveButton2X
	share.middlePointOfMoveButton1X:=middlePointOfMoveButton1X
	share.middlePointOfPlusButtonY:=middlePointOfPlusButtonY
	share.middlePointOfPlusButton2Y:=middlePointOfPlusButton2Y
	share.middlePointOfEditButtonY:=middlePointOfEditButtonY
	share.middlePointOfTrashButtonY:=middlePointOfTrashButtonY
	share.middlePointOfMoveButton2Y:=middlePointOfMoveButton2Y
	share.middlePointOfMoveButton1Y:=middlePointOfMoveButton1Y
	
	;~ Gdip_TextToGraphics(G, OnTopLabel, "x10 y0 " TextOptionsTopLabel, Font, widthofguipic, heightofguipic)
	
	
	;~ MsgBox %mainguiHwnddc%
	;Show the image
	BitBlt(mainguiHwnddc, 0, 0, posw, posh, hdc, 0, 0)

	; Now the bitmap may be deleted
	DeleteObject(hbm)

	; Also the device context related to the bitmap may be deleted
	DeleteDC(hdc)
	;delete bitmaps
	Gdip_DeleteGraphics(G)
	
	DrawingRightNow:=false
	
	if (DrawAgain=true or AnyRecentlyRunElementFound)
	{
		DrawAgain:=false
		;~ ToolTip("Draw Again")
		;~ Sleep 10
		
		;~ ui_DrawEverything(Posw,Posh)
		;~ SetTimer,ui_DrawEverything,-10
	}
	else
		SetTimer,ui_DrawEverything,off
	
	
	Return

}

