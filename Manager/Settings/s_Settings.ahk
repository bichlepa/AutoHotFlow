goto,JumpOverSettings

ButtonSettings:

IfExist,%A_Startup%\AutoHotFlow.lnk 
	GuiSettingAutostart=1
else
	GuiSettingAutostart=0

DisableMainGUI()

gui,8:default
gui,add,text,,% lang("Startup") 
gui,add,Checkbox,w200 checked%GuiSettingAutostart% vGuiSettingAutostart ,% lang("Start with windows") 
gui,add,Button,w120 gGuiSettingsChooseOK vGuiSettingsChooseOK default,% lang("OK")
gui,add,Button,w70 X+10 yp gGuiSettingsChooseCancel,% lang("Cancel")
gui,show
return
8guiclose:
GuiSettingsChooseCancel:
EnableMainGUI()
gui,destroy
gui,1:default
return

GuiSettingsChooseOK:
gui,Submit,nohide

if GuiSettingAutostart
{
	FileCreateShortcut,%A_ScriptFullPath%,%A_Startup%\AutoHotFlow.lnk ,,AutomaticStartup
}
else
	FileDelete,%A_Startup%\AutoHotFlow.lnk 

gui,destroy
EnableMainGUI()


gui,1:default


return

JumpOverSettings:
temp=