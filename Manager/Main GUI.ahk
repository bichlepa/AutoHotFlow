


;initialize image list
IconList:=IL_Create("","",1)
IL_Add(IconList,"Icons\disabled.ico")
IL_Add(IconList,"Icons\enabled.ico")
IL_Add(IconList,"Icons\running.ico")
IL_Add(IconList,"Icons\folder.ico")


goto,jumpOverGUIStuff

CreateMainGUI:
gui,1:default

;Create main GUI
gui,font,s15
Gui, Add, TreeView, gTreeView x10 y10 w300 h500 -ReadOnly AltSubmit ImageList%IconList%
gui,font,s12
gui,add,Button,vButtonNewCategory gButtonNewCategory X330 yp w200 h30 , % lang("New_Category")
gui,add,Button,vButtonNewFlow gButtonNewFlow X+10 yp w200 h30, % lang("New_Flow")
gui,add,Button,vButtonChangeCategory gButtonChangeCategory Disabled Y+30 x330 w200 h30, % lang("Change_category")
;gui,add,Button,vButtonCopyFlow gButtonCopyFlow Disabled X+10 yp w200 h30, % lang("Copy")
gui,add,Button,vButtonEditFlow gButtonEditFlow Disabled Y+30 x330 w200 h30, % lang("Edit")
gui,add,Button,vButtonDeleteFlow gButtonDeleteFlow Disabled X+10 yp w200 h30, % lang("delete")
gui,add,Button,vButtonEnableFlow gButtonEnableFlow Disabled Y+30 x330 w200 h30, % lang("enable")
gui,add,Button,vButtonRunFlow gButtonRunFlow Disabled X+10 yp w200 h30,% lang("Run")

gui,add,Button,vButtonSelectLanguage gButtonSelectLanguage  X330 Y+100 w200 h30,% lang("Change_Language")
gui,add,Button,vButtonHelp gButtonHelp X+10 yp w200 h30,% lang("Help")
gui,add,Button,vButtonSettings gButtonSettings  X330 Y+30 w200 h30,% lang("Settings")
gui,add,Button,vButtonAbout gButtonAbout  X330 Y+30 w200 h30,% lang("About AutoHotFlow")
gui,add,Button,vButtonShowLog gButtonShowLog  X330 Y+30 w200 h30,% lang("Show log")


Gui, Show,hide, % "•AutoHotFlow• " lang("Manager")  ; Do not show window while loading flows. Otherway the treeview will not show the plus signs


return



ShowMainGUI:

Gui, 1:Show
return

HideMainGUI:
Gui, 1:hide
return

ButtonNewCategory:

NewTvNumber:=NewCategory(lang("New_Category"),"new")
TV_Modify(NewTvNumber) ;Mark The new entry
controlsend,SysTreeView321,{F2},•AutoHotFlow• ;Rename Entry
return

ButtonNewFlow:
tempselected:=TV_GetSelection()
if tempselected<>0
{
	;MsgBox % TypeOf(tempselected)
	temptype:=TypeOf(tempselected)
	
	if temptype=Category
		NewTvNumber:=NewFlow(lang("New_Flow"),NameOf(tempselected),"",true)
	else if temptype=flow
		NewTvNumber:=NewFlow(lang("New_Flow"),NameOf(TV_GetParent(tempselected)),"",true)
	else
		MsgBox,,Internal error, The type of selected element could not be resolved!
	TV_Modify(NewTvNumber) ;Mark The new entry
	controlsend,SysTreeView321,{F2},•AutoHotFlow• ;Rename Entry. It's a workaround.
}
return

ButtonChangeCategory:
tempselected:=TV_GetSelection() 
tempselectedID:=IDOf(tempselected)
changeCategory(tempselectedID)
return

ButtonHelp:
IfNotExist, Help\%UILang%\index.html
{
	IfNotExist, Help\en\index.html
	{
		MsgBox, 16, % lang("Error"),% lang("No help file was found")
		Return
	}
	run,Help\en\index.html
}
else
	run,Help\%UILang%\index.html
return

ButtonEditFlow:
tempselected:=TV_GetSelection() 
tempselectedID:=IDOf(tempselected)

editFlow(tempselectedID)

return

ButtonRunFlow:
tempselected:=TV_GetSelection() 
tempselectedID:=IDOf(tempselected)
if %tempselectedID%running=true
{
	stopFlow(tempselectedID)
}
else
{
	runFlow(tempselectedID)
}
return

ButtonEnableFlow:
tempselected:=TV_GetSelection() 
tempselectedID:=IDOf(tempselected)
if %tempselectedID%enabled=false
{
	enableFlow(tempselectedID)
}
else
{
	disableFlow(tempselectedID)
}

updateIcon(tempID)

return

TreeView:
tempselectedTV:=TV_GetSelection() 
tempselectedID:=IDOf(tempselectedTV)

if A_GuiEvent =E ;If user has renamed an entry
{
	TV_GetText(OutputVar, tempselectedTV)
	
	;MsgBox,% "-"OutputVar "-" %tempSelectedID%name "-"
	if !(%tempSelectedID%name==OutputVar) ;If user finished renaming entry and the name has changed
	{
		tempOldName:=%tempSelectedID%name
		if %tempSelectedID%type=category ;If the item is a category, all flows of that category must be saved
		{
			if (OutputVar<>"" and (IDOfName(OutputVar,"Category")="" or (!(OutputVar==%tempSelectedID%name) and IDOfName(OutputVar,"Category")=tempSelectedID))) ;It will only be renamed if the user didn't enter an empty name and there isn't already a flow with the same name. It wil also rename if user only changed the case of a letter.
			{
				for count, tempitem in allItems
				{
					if %tempitem%type=flow
					{
						if (%tempitem%category=%tempSelectedID%name)
						{
							%tempitem%category:=OutputVar
							SaveFlow(tempitem)
							tooltip(lang("Renamed"))
							;MsgBox, % %tempitem%name
						}
					}
				}
				
				%tempSelectedID%name:=OutputVar
			}
			else
			{
				soundplay,*16
				if OutputVar=
					ToolTip(lang("A_category_can_not_have_an_empty_name"),5000)
				else
					ToolTip(lang("A_category_with_name_%1%_already_exists",OutputVar),5000)
				TV_Modify(tempselectedTV,"",tempOldName)
			}
		}
		else if %tempSelectedID%type=flow ;If the item is a flow
		{
			if ((OutputVar<>"") and (IDOfName(OutputVar,"Flow")="" )) ;It will only be renamed if the user didn't enter an empty name and there isn't already a flow with the same name. 
			{
				%tempSelectedID%name:=OutputVar
				SaveFlow(tempSelectedID)
				com_SendCommand({function: "FlowParametersChanged"},tempOldName) ;Send the command to the Editor.
				tooltip(lang("Renamed"))
				;warn if the name begins with "D_"
				
				if (substr(OutputVar,1,2)="D_")
					MsgBox, 48,% lang("Warning"),% lang("The name of the flow begins with %1%! Such flows will be deleted or overwritten on next update!","D_")
			}
			else
			{
				soundplay,*16
				if OutputVar=
					ToolTip(lang("A_flow_can_not_have_an_empty_name"),5000)
				else
					ToolTip(lang("A_flow_with_name_%1%_already_exists",OutputVar),5000)
				TV_Modify(tempselectedTV,"",tempOldName)
			}
		}
		
		
		
	}
	return
}

if (A_GuiEvent ="s") ;If user has selected an item. En- or disable some buttons.
{
	tempSelectedID:=IDOf(A_Eventinfo)
	
	if %tempSelectedID%type=flow
	{
		guicontrol,enable,ButtonEditFlow
		guicontrol,enable,ButtonRunFlow
		guicontrol,enable,ButtonEnableFlow
		guicontrol,enable,ButtonChangeCategory
		guicontrol,enable,ButtonDeleteFlow
	}
	else
	{
		guicontrol,Disable,ButtonEditFlow
		guicontrol,Disable,ButtonRunFlow
		guicontrol,Disable,ButtonEnableFlow
		guicontrol,Disable,ButtonChangeCategory
		guicontrol,enable,ButtonDeleteFlow
	}
	
	if %tempSelectedID%enabled=true
		guicontrol,,ButtonEnableFlow,% lang("Disable")
	else
		guicontrol,,ButtonEnableFlow,% lang("Enable")
	if %tempSelectedID%running=true
		guicontrol,,ButtonRunFlow,% lang("Stop")
	else
		guicontrol,,ButtonRunFlow,% lang("Run")
}



return



ButtonDeleteFlow: ;Delete marked Item
tempselectedTV:=TV_GetSelection() 
tempselectedID:=IDOf(tempselectedTV)

if %tempselectedID%type=flow
{
	DisableMainGUI()
	MsgBox, 4, % lang("Confirm_deletion"),% lang("Do_you_really_want_to_delete_the_flow_%1%?",%tempselectedID%name)
	IfMsgBox,Yes
	{
		com_SendCommand({function: "immediatelyexit"},%tempselectedID%name) ;Send the command to the Editor.
		if not errorlevel
			sleep,500
		FileDelete,% %tempselectedID%ini
		TV_Delete(tempselectedTV)
		for count, tempItem in allItems
		{
			if (tempItem=tempselectedID)
				allItems.Remove(count)
		}
		
	}
	
}
else if %tempselectedID%type=category
{
	DisableMainGUI()
	if lang("Uncategorized")=%tempselectedID%name ;Do not remove the uncategorized category, since there are flows
	{
		MsgBox,% lang("This_category_can_not_be_removed!")
		EnableMainGUI()
	}
	else
	{
		MsgBox, 4, % lang("Confirm_deletion"),% lang("Do_you_really_want_to_delete_the_category_%1%?",%tempselectedID%name) "`n" lang("All_flows_of_that_category_will_be_moved_into_the_category",lang("Uncategorized")) ;confirm by user 
		IfMsgBox,Yes
		{
			;debug()
			temptodeleteID:=tempselectedID
			temptodeleteTV:=tempselectedTV
			if (IDOfName(lang("Uncategorized"),"Category")="") ;Create the category uncategorized if it is not present
			{
				
				tempUncategorizedTV:=NewCategory(lang("uncategorized"))
			}
			else
				tempUncategorizedTV:=TVOf(IDOfName(lang("uncategorized"),"Category"))
			
			for count, tempItem in allItems ;Move all flows that were inside the category
			{
				
				if %tempItem%type=flow
				{
					
					if (%tempItem%category=%temptodeleteID%name)
					{
						MoveFlow(tempItem,lang("uncategorized"))
						
					}
				}
				
			}
			
			TV_Delete(temptodeleteTV) ;Delete the category
			
			for count, tempItem in allItems
			{
				if (tempItem=temptodeleteID)
				{
					allItems.remove(count,count)
					
					break
				}
			}
			
		}
	}
}
;debug()
removeUncategorizedCategoryIfPossible()
EnableMainGUI()
return

ButtonAbout:
goto,BaseFrame_About

return

ButtonShowLog:
showlog()

return

jumpOverGUIStuff:
temp= ;Do nothing