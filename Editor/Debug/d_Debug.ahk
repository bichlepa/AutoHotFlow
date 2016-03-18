d_debug()
{
	
}

if not a_iscompiled
{
	hotkey,F12,d_showElementDetais, on
	hotkey,^F12,d_showElementDetais, on
	hotkey,F11,d_ExportAllDataToFile, on
	hotkey,^F11,d_ExportAllDataToFile, on
	hotkey,F10,d_showAllStates, on
}

d_showElementDetais()
{
	global
	if GetKeyState("ctrl")
		MsgBox % strobj(markedElement)
	else
		ToolTip(strobj(markedElement),10000)
	
}

d_ExportAllDataToFile()
{
	global
	local tempallelements, tempallconnections, tempalltriggers, temptext
	tempallelements:=strobj(allelements)
	tempallconnections:=strobj(allConnections)
	tempalltriggers:=strobj(alltriggers)
	tempMarkedElements:=strobj(MarkedElements)
	
	temptext=
	( ltrim
		----- All Elements -------
		%tempallelements%
		
		----- All Connections -------
		%tempallconnections%
		
		----- All Triggers -------
		%tempalltriggers%
		
		----- Marked Elements -------
		%tempMarkedElements%
	)
	StringReplace,temptext,temptext,`r`n,`n, all
	StringReplace,temptext,temptext,`n,`r`n, all
	FileDelete,debugExport.txt
	FileAppend,%temptext%, debugExport.txt
	if GetKeyState("ctrl")
		run,debugExport.txt
	
}


d_showAllStates()
{
	global
	d("current state: " currentstateid "`n`n" strobj(states))
}

d(text,header="",wait=1)
{
	static
	global dedit, dbutton
	dfinished:=false
	
	if (isobject(text))
		text:=strobj(text)
	
	gui,d:destroy
	gui,d:margin,5,5
	gui,d:add,edit,readonly vdedit,% text
	gui,d:add,button,vdbutton w100 h30 gdClose Default, OK
	guicontrol,d:focus,dbutton
	gui,d:show,hide
	gui,d:+resize
	gui,d:+hwnddHWND
	
	VarSetCapacity(rc, 16)
    DllCall("GetClientRect", "uint", dHWND, "uint", &rc)
    dw := NumGet(rc, 8, "int")
    dh := NumGet(rc, 12, "int")
	
	
	if (dh>a_screenheight)
		dh:= a_screenheight -50
	if (dw>A_ScreenWidth)
		dw:= A_ScreenWidth -50
	if (dw<300)
		dw:=300
	
	
	gui,d:show,h%dh% w%dw%,%header%
	
	if (wait=1 or wait="wait")
		Loop
		{
			if (dfinished=true)
				break
			else
				sleep 100
		}
		
	return
	dClose:
	dGUIClose:
	gui,d:destroy
	dfinished:=true
	return
	
	dGuisize:
	;~ MsgBox % A_GuiWidth " " A_GuiHeight
	guicontrol,d:move,dedit,% "w" A_GuiWidth-10 " h" A_GuiHeight -45
	guicontrol,d:move,dbutton,% "w" A_GuiWidth-10 " y" A_GuiHeight -35
	return
}
