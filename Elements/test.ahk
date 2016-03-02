PrintScreen::

result:=RegExReplace(Clipboard,"mi)guicontrol\s?,\s?(enable|disable)\s?,\s?GUISettingsOfElement`%ID`%(\w*)","ElementSettingsFieldParIDs[""$2""].$1()")
;~ result:=RegExReplace(Clipboard,"m)GuiControl,Enable,GUISettingsOfElement`%ID`%(\w*)",", ElementSettingsFieldParIDs[""$1""].enablr()")
result:=RegExReplace(result,"m)GUISettingsOfElement`%ID`%(\w*)","ElementSettingsFieldParIDs[""$1""].getvalue()")

;~ MsgBox,%result%
Clipboard:=result