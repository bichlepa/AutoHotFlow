;Formula for x-position: 0+n*35  	;Width: 35*4=140
;Formula for y-position: 17,5+n*35	;Height: 35*3=105

GDIPars:=Object()
share.GDIPars:=GdiPars
;Initialize values at the beginning
GridX:=35
Gridy:=35
GridyOffset:=17.5
ElementWidth:=140
ElementHeight:=105
NewElementIconWidth:=100
NewElementIconHeight:=75
MinimumHeightOfConnection:=15
SizeOfButtons:=35
textSize:=15
Offsetx:=0
Offsety:=0
zoomFactor:=0.7
zoomFactorMin:=0.1
zoomFactorMax:=3
widthofguipic:=500
heightofguipic:=300
GDIPars.GridX:=GridX
GDIPars.Gridy:=Gridy
GDIPars.GridyOffset:=GridyOffset
GDIPars.ElementWidth:=ElementWidth
GDIPars.ElementHeight:=ElementHeight
GDIPars.NewElementIconWidth:=NewElementIconWidth
GDIPars.NewElementIconHeight:=NewElementIconHeight
GDIPars.MinimumHeightOfConnection:=MinimumHeightOfConnection
GDIPars.SizeOfButtons:=SizeOfButtons
GDIPars.textSize:=textSize
GDIPars.zoomFactorMin:=zoomFactorMin
GDIPars.zoomFactorMax:=zoomFactorMax
VisibleArea:=[]
;~ OnTopLabel=


GDI_DrawPlusUnderMouse:=false


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


;Create new thread for GUI Rendering
ui_initGDIThread()
{
	global
	local tempGIDCode
	
	FileRead,tempGIDCode,% A_ScriptDir "\AutoHotKey\Threads\ui_GDI+Thread.ahk"
	AhkThreadGDI := AhkThread("share:=CriticalObject(" (&share) ") `n" tempGIDCode)
	AhkThreadGDI.ahkAssign("mainguihwnd",maingui.hwnd)
	AhkThreadGDI.ahkAssign("mainguiHwnddc",MainGui.Hwnddc)

	
}



goto,jumpoverUIDRaw


;Call a function in the Rendering thread in oder to make it rendering
ui_Draw()
{
	global
	
	;at first send assign some vars
	share.GDIPars.Offsetx:=Offsetx
	share.GDIPars.Offsety:=Offsety
	share.GDIPars.zoomFactor:=zoomFactor
	share.GDIPars.widthofguipic:=widthofguipic
	share.GDIPars.heightofguipic:=heightofguipic
	share.GDIPars.UserCurrentlyMovesAnElement:=UserCurrentlyMovesAnElement
	
	
	AhkThreadGDI.ahkFunction("ui_DrawThread")
	;~ SoundBeep 100
	;~ ReturnValue := DllCall(A_AhkPath "\ahkFunction","Str","ui_DrawThread","Str","hallo","Cdecl Str")
}


ui_regularUpdateIfWinMoved:
WinGetPos,winx,winy,,,% "ahk_id " MainGui.hwnd
if (winx!=winxold and winy!=winyOld)
{
	winxold:=winx
	winyOld:=winy
	
	ui_Draw()
	
}

return

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

	pBrushRed := Gdip_BrushCreateSolid("0x10ff0000") ;Red brush, very transparent
	
	; Draw a rectangle onto the graphics of the bitmap using the pen just created
	; Draws the rectangle from coordinates (250,80) a rectangle of 300x200 and outline width of 10 (specified when creating the pen)
	Gdip_DrawRectangle(G, pPen, ControlPosx, ControlPosy,  ControlWidth,ControlHeight)
	Gdip_FillRectangle(G, pBrushRed, ControlPosx, ControlPosy, ControlWidth,ControlHeight)
	
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
	
 
	WinSet, ExStyle, +0x20, % "ahk_id " hwnd1 ;Make window click through



}

ui_DeleteShapeOnScreen()
{
	Gui, 6: Destroy
}



ui_Draw:
ui_Draw()
return
jumpoverUIDRaw:
temp= ;Do nothing