#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

string:=""

SysGet, MonitorPrimary, MonitorPrimary
SysGet,MonitorWorkArea,MonitorWorkArea,%MonitorPrimary% 
SysGet, VirtualWidth, 78
SysGet, VirtualHeight, 79

string.="MonitorPrimary: " MonitorPrimary "`n"
string.="MonitorWorkAreaLeft: " MonitorWorkAreaLeft "`n"
string.="MonitorWorkArearight: " MonitorWorkArearight "`n"
string.="MonitorWorkAreatop: " MonitorWorkAreatop "`n"
string.="MonitorWorkAreabottom: " MonitorWorkAreabottom "`n"
string.="A_ScreenWidth: " A_ScreenWidth "`n"
string.="A_ScreenHeight: " A_ScreenHeight "`n"
string.="VirtualWidth: " VirtualWidth "`n"
string.="VirtualHeight: " VirtualHeight "`n"

gui,add,edit, readonly,% string
gui,add,button, vcopyClipboard gcopyClipboard,Copy to clipboard
GuiControl,focus,copyClipboard
gui,show
return

copyClipboard:

Clipboard:=string
ToolTip,Copied to clipboard
sleep,1000
ToolTip
return

GuiClose:
ExitApp
