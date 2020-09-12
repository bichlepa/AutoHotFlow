if (_settings.developing)
{
	hotkey, ^numpadenter, d_showGlobals
	hotkey, ^numpadadd, d_showAnyVariable
}

; shows the contents of a text or an object
d(text,header="",wait=1)
{
	static
	global dedit, dbutton, dbuttonShowGlobals, _settings
	if not (_settings.developing)
		return
	
	dfinished:=false
	
	if (isobject(text))
		text:=strobj(text)
	
	gui,d:destroy
	gui,d:margin,5,5
	gui,d:add,edit,readonly vdedit,% text
	gui,d:add,button,vdbutton w200 h30 gdClose Default, OK
	gui,d:add,button,vdbuttonShowGlobals w200 h30 X+10 gdShowGlobals, Show globals
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
	guicontrol,d:move,dbutton,% "w" (A_GuiWidth / 2) - 10 " y" A_GuiHeight -35
	guicontrol,d:move,dbuttonShowGlobals,% "w" (A_GuiWidth / 2) - 10 " y" A_GuiHeight -35 " x" (A_GuiWidth / 2) +5
	return
	
	dShowGlobals:
	gui,d:destroy
	d_showGlobals()
	dfinished:=true
	return
}

; shows all global variables in a gui
d_showGlobals(wait=1)
{
	static
	global allFlows
	text:=""
	; text.="Call stack:`n"
	; text.=CallStack(10)
	text.="Flows:`n"
	
	text.=strobj(_flows) "`n`nSettings:`n"
	text.=strobj(_settings) "`n`nExecution:`n"
	text.=strobj(_execution) "`n`nShare:`n"
	text.=strobj(_share) "`n`nAllFlows:`n"
	;~ text.=strobj(allFlows)
	
	;~ MsgBox % strobj(_flows)
	Clipboard := text
	
	gui,dGlobals:destroy
	gui,dGlobals:margin,5,5
	gui,dGlobals:add,edit,readonly vdedit,% text
	gui,dGlobals:add,button,vdbutton w100 h30 gdGlobalsClose Default, OK
	guicontrol,dGlobals:focus,dbutton
	gui,dGlobals:show,hide
	gui,dGlobals:+resize
	gui,dGlobals:+hwndddGlobalsHWND
	
	VarSetCapacity(rc, 16)
    DllCall("GetClientRect", "uint", ddGlobalsHWND, "uint", &rc)
    dw := NumGet(rc, 8, "int")
    dh := NumGet(rc, 12, "int")
	
	
	if (dh>a_screenheight)
		dh:= a_screenheight -50
	if (dw>A_ScreenWidth)
		dw:= A_ScreenWidth -50
	if (dw<300)
		dw:=300
	
	
	gui,dGlobals:show,h%dh% w%dw%,Global variables
	
	if (wait=1 or wait="wait")
		Loop
		{
			if (dfinished=true)
				break
			else
				sleep 100
		}
		
	return
	
	dGlobalsClose:
	dGlobalsGUIClose:
	gui,dGlobals:destroy
	dfinished:=true
	return
	
	dGlobalsGuisize:
	;~ MsgBox % A_GuiWidth " " A_GuiHeight
	guicontrol,dGlobals:move,dedit,% "w" A_GuiWidth-10 " h" A_GuiHeight -45
	guicontrol,dGlobals:move,dbutton,% "w" A_GuiWidth-10 " y" A_GuiHeight -35
	return
}

d_showAnyVariable()
{
	global
	local varname
	local counter
	local split
	InputBox,varname,Debug,Enter variable name
	StringSplit,split,varname,.
	if (split0 = 1)
		d(%varname%, varname)
	else if (split0 = 2)
		d(%split1%[split2], varname)
	else if (split0 = 3)
		d(%split1%[split2][split3], varname)
	else if (split0 = 4)
		d(%split1%[split2][split3][split4], varname)
}

CallStack(deepness = 5, printLines = 1)
{
	loop % deepness
	{
		lvl := -1 - deepness + A_Index
		oEx := Exception("", lvl)
		oExPrev := Exception("", lvl - 1)
		FileReadLine, line, % oEx.file, % oEx.line
		if(oEx.What = lvl)
			continue
		stack .= (stack ? "`n" : "") "File '" oEx.file "', Line " oEx.line (oExPrev.What = lvl-1 ? "" : ", in " oExPrev.What) (printLines ? ":`n" line : "") "`n"
	}
	return stack
}