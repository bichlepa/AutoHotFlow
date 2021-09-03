assistant_ChooseColor(neededInfo)
{
	global
	local chosenColor
	ui_disableElementSettingsWindow()
	
	chosenColor:=chooseColor(x_Par_GetValue(neededInfo.Color))
	if chosenColor
		x_Par_SetValue(neededInfo.Color, chosenColor)
	
	ui_enableElementSettingsWindow()
	return
}


chooseColor(Color,CustomColors="")
{
	static
	global SettingsGUIHWND
	;Swap red and blue
	setformat,IntegerFast,H
	Color:=(Color&255)<<16|(Color&65280)|(Color>>16),Color:=SubStr(Color,1)
	SetFormat,IntegerFast,D
	
	
	if !cc{
		VarSetCapacity(CUSTOM,16*A_PtrSize,0),cc:=1,size:=VarSetCapacity(CHOOSECOLOR,9*A_PtrSize,0)
		Loop,16{
			IniRead,col,settings.ini,CustomColors,%A_Index%,0
			NumPut(col,CUSTOM,(A_Index-1)*4,"UInt")
		}
	}
	NumPut(size,CHOOSECOLOR,0,"UInt"),NumPut(SettingsGUIHWND,CHOOSECOLOR,A_PtrSize,"UPtr")
	,NumPut(Color,CHOOSECOLOR,3*A_PtrSize,"UInt"),NumPut(3,CHOOSECOLOR,5*A_PtrSize,"UInt")
	,NumPut(&CUSTOM,CHOOSECOLOR,4*A_PtrSize,"UPtr")
	ret:=DllCall("comdlg32\ChooseColor","UPtr",&CHOOSECOLOR,"UInt")
	if !ret
		return
	
	Loop,16
	{
		IniWrite,% NumGet(custom,(A_Index-1)*4,"UInt"),settings.ini,CustomColors,%A_Index%
	}
	
	Color:=NumGet(CHOOSECOLOR,3*A_PtrSize,"UInt")
	
	;Swap red and blue
	setformat,IntegerFast,H
	Color:=(Color&255)<<16|(Color&65280)|(Color>>16),Color:=SubStr(Color,1)
	SetFormat,IntegerFast,D
	Color:=format("0x{1:6.6X}",Color)

	return Color
	
}