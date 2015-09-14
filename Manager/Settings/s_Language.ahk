goto,JumpOverLanguage

ButtonSelectLanguage:
allLangs:=Object()
stringalllangs=`n
Loop,language\*.ini
{
	StringReplace,filenameNoExt,A_LoopFileName,.%A_LoopFileExt%
	
	IniRead,%filenameNoExt%enlangname,language\%filenameNoExt%.ini,general,enname
	IniRead,%filenameNoExt%langname,language\%filenameNoExt%.ini,general,name
	if %filenameNoExt%enlangname!=Error
	{
		allLangs.insert(filenameNoExt)
		
	}
	stringalllangs.= filenameNoExt " (" %filenameNoExt%enlangname " - "  %filenameNoExt%langname ")|"
	;MsgBox %  filenameNoExt "|" %filenameNoExt%langname
}



DisableMainGUI()

gui,7:default
gui,add,text,,% lang("Select_Language.")
gui,add,ListBox,w200 h300 AltSubmit vGuiLanguageChoose gGuiLanguageChoose ,%stringalllangs%
gui,add,Button,w120 gGuiLanguageChooseOK vGuiLanguageChooseOK default Disabled,% lang("OK")
gui,add,Button,w70 X+10 yp gGuiLanguageChooseCancel,% lang("Cancel")
gui,show
return
7guiclose:
GuiLanguageChooseCancel:
EnableMainGUI()
gui,destroy
gui,1:default
return
GuiLanguageChoose:
if A_GuiEvent =DoubleClick 
{
	if GuiLanguageChoose>0	
	goto GuiLanguageChooseOK
}
gui,submit,nohide
if GuiLanguageChoose>0	
	GuiControl,enable,GuiLanguageChooseOK
else
	GuiControl,disable,GuiLanguageChooseOK
return
GuiLanguageChooseOK:
gui,Submit,nohide

IniWrite,% allLangs[GuiLanguageChoose],settings.ini,common,UILanguage
iniread,UILang,settings.ini,common,UILanguage
lang_LoadCurrentLanguage()

gui,destroy

EnableMainGUI()


gui,1:default

guicontrol,,ButtonNewCategory , % lang("New_Category")
guicontrol,,ButtonNewFlow , % lang("New_Flow")
guicontrol,,ButtonChangeCategory , % lang("Change_category")
guicontrol,,ButtonEditFlow , % lang("Edit")
guicontrol,,ButtonDeleteFlow , % lang("delete")
guicontrol,,ButtonEnableFlow , % lang("enable")
guicontrol,,ButtonRunFlow ,% lang("Run")

guicontrol,,ButtonSelectLanguage ,% lang("Change_Language")
guicontrol,,ButtonSettings ,% lang("Settings")

Gui, Show,, % "•AutoHotFlow• " lang("Manager")  ; Show the window and its TreeView.

for count, tempItem in allItems
{
	com_SendCommand({function: "languageChanged"},"Editor",nameOf(tempItem)) ;Send the command to the Editor.
	
}

return

JumpOverLanguage:
temp=