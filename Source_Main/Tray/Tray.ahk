

Menu, tray, Icon,%_ScriptDir%\Icons\mainicon.ico
if a_iscompiled
{
	Menu, tray, NoStandard
}
else
{
	Menu, tray, add	
}
Menu, tray, add, % lang("Show Manager"), showManagerGUI
Menu, tray, default,% lang("Show Manager")
Menu, tray, add, % lang("Close"), exit
Menu, tray, tip, % "AutoHotFlow"

showManagerGUI()
{
	API_Manager_ShowWindow()
}
