menu, tray, NoStandard

menu, tray, add,  Show
menu, tray, Default, Show
menu, tray, rename,  Show, % lang("Show manager")
menu, tray, add, Exit
menu, tray, rename, Exit,% lang("Exit")

menu,tray,tip,% lang("AutoHotFlow Manager")
menu,tray,icon,Icons\MainIcon.ico

goto,JumpOverTrayStuff



Show:
goto ShowMainGUI

return

JumpOverTrayStuff:
temp= ;Do nothing