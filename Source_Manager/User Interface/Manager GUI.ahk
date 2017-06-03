allTreeViewItems := Object()


init_Manager_GUI()
{
	global
	
	allItems:=object()
	
	;initialize image list
	IconList:=IL_Create("","",1)
	IL_Add(IconList, _ScriptDir "\Icons\disabled.ico")
	Icon_Disabled:="icon1"
	IL_Add(IconList, _ScriptDir "\Icons\enabled.ico")
	Icon_Enabled:="icon2"
	IL_Add(IconList, _ScriptDir "\Icons\running.ico")
	Icon_Running:="icon3"
	IL_Add(IconList, _ScriptDir "\Icons\folder.ico")
	Icon_Folder:="icon4"
	gui,manager:default

	;Create main GUI
	gui,font,s15
	Gui, Add, TreeView, vTreeView_manager gTreeView_manager x10 y10 w300 h500 -ReadOnly ImageList%IconList% hwndTreeView_manager_HWND
	gui,font,s12
	gui,add,Button,vButton_manager_NewCategory gButton_manager_NewCategory X330 yp w200 h30
	gui,add,Button,vButton_manager_NewFlow gButton_manager_NewFlow X+10 yp w200 h30
	gui,add,Button,vButton_manager_ChangeCategory gButton_manager_ChangeCategory Disabled Y+20 x330 w130 h30
	gui,add,Button,vButton_manager_DuplicateFlow gButton_manager_DuplicateFlow Disabled X+10 yp w130 h30
	gui,add,Button,vButton_manager_Delete gButton_manager_Delete Disabled X+10 yp w130 h30
	
	gui,add,Button,vButton_manager_EditFlow gButton_manager_EditFlow Disabled Y+50 x330 w200 h30
	gui,add,Button,vButton_manager_EnableFlow gButton_manager_EnableFlow Disabled Y+20 x330 w200 h30
	gui,add,Button,vButton_manager_RunFlow gButton_manager_RunFlow Disabled X+10 yp w200 h30

	gui,add,Button,vButton_manager_Settings gButton_manager_Settings  X330 Y+50 w200 h30
	gui,add,Button,vButton_manager_Import_Export gButton_manager_Import_Export X330 Y+20 w200 h30
	gui,add,Button,vButton_manager_About gButton_manager_About  X330 Y+20 w200 h30
	gui,add,Button,vButton_manager_Help gButton_manager_Help X+10 yp w200 h30
	gui,add,Button,vButton_manager_ShowLog gButton_manager_ShowLog  X330 Y+20 w200 h30
	gui,add,Button,vButton_manager_Exit gButton_manager_Exit X+10 yp w200 h30

	Refresh_Manager_GUI() ; write translated labels

	gui,+hwndManagerGUIHWND
	_share.hwnds.Manager := ManagerGUIHWND
	
	;Set title. Do not show yet
	if a_iscompiled
	{
		Gui, Show,hide, % "AutoHotFlow " lang("Manager") 
	}
	else ;Helps me to find the uncompiled AHF instance
	{
		Gui, Show,hide, % "AutoHotFlow " lang("Manager") " - UNCOMPILED "
	}
	
	hotkey, ifwinactive, ahk_id %ManagerGUIHWND%
	hotkey, f5, TreeView_manager_Refill
	
	settimer, updateFlowIcons_Manager_GUI, 100
}

Refresh_Manager_GUI()
{
	gui,manager:default
	
	guicontrol,,Button_manager_NewCategory , % lang("New_Category")
	guicontrol,,Button_manager_NewFlow , % lang("New_Flow")
	guicontrol,,Button_manager_ChangeCategory , % lang("Change_category")
	guicontrol,,Button_manager_DuplicateFlow , % lang("Duplicate")
	guicontrol,,Button_manager_Delete , % lang("delete")
	guicontrol,,Button_manager_EditFlow , % lang("Edit")
	guicontrol,,Button_manager_EnableFlow , % lang("enable")
	guicontrol,,Button_manager_RunFlow ,% lang("Run")

	guicontrol,,Button_manager_Import_Export ,% lang("Import and export")
	guicontrol,,Button_manager_Settings ,% lang("Settings")
	guicontrol,,Button_manager_Help ,% lang("Help")
	guicontrol,,Button_manager_ShowLog ,% lang("Show log")
	guicontrol,,Button_manager_About ,% lang("About AutoHotFlow")
	guicontrol,,Button_manager_Exit ,% lang("Exit")
}

Show_Manager_GUI()
{
	
	Gui, manager:Show
}


Hide_Manager_GUI()
{
	Gui, manager:hide
}

Disable_Manager_GUI()
{
	global
	gui,manager:+disabled
	
}
Enable_Manager_GUI()
{
	global
	gui,manager:-disabled
	WinActivate,% "ahk_id " _share.hwnds.Manager 
}

updateFlowIcons_Manager_GUI()
{
	global 
	static currentIcons:=Object()
	static currentLabelButtonRun:=""
	static currentLabelButtonEnable:=""
	
	if (_share.FlowsTreeViewNeedFullRefresh)
	{
		_share.FlowsTreeViewNeedFullRefresh:=false
		TreeView_manager_Refill()
	}
	
	Gui, manager:default
	local forFlowID, forFlow, selectedFlow
	for forFlowID, forFlow in _flows
	{
		if (forFlow.executing = True)
		{
			if (currentIcons[forFlowID]!=Icon_Running)
			{
				TV_Modify(forFlow.tv, Icon_Running)
				currentIcons[forFlowID]:=Icon_Running
			}
		}
		else if (forFlow.enabled = true)
		{
			if (currentIcons[forFlowID]!=Icon_Enabled)
			{
				TV_Modify(forFlow.tv, Icon_Enabled)
				currentIcons[forFlowID]:=Icon_Enabled
			}
		}
		else
		{
			if (currentIcons[forFlowID]!=Icon_Disabled)
			{
				TV_Modify(forFlow.tv, Icon_Disabled)
				currentIcons[forFlowID]:=Icon_Disabled
			}
		}
		
	}
	
	
	selectedFlow:=_flows[allTreeViewItems[TV_GetSelection()].id]
	if (selectedFlow.executing = True)
	{
		if (currentLabelButtonRun != "stop")
		{
			guicontrol,,Button_manager_RunFlow ,% lang("Stop")
			currentLabelButtonRun := "Stop"
		}
	}
	else
	{
		if (currentLabelButtonRun != "Run")
		{
			guicontrol,,Button_manager_RunFlow ,% lang("Run")
			currentLabelButtonRun := "Run"
		}
	}
	if (selectedFlow.enabled = True)
	{
		if (currentLabelButtonRun != "disable")
		{
			guicontrol,,Button_manager_EnableFlow ,% lang("Disable")
			currentLabelButtonRun := "disable"
		}
	}
	else
	{
		if (currentLabelButtonRun != "Enable")
		{
			guicontrol,,Button_manager_EnableFlow ,% lang("Enable")
			currentLabelButtonRun := "Enable"
		}
	}
}

TreeView_manager_Refill()
{
	global
	local newTV
	local oneflowID, oneflow, onecategoryID, onecategory
	if not (ManagerGUIHWND)
		return
	Gui, manager:default
	
	tempselectedTV := TV_GetSelection()
	tempselectedID := allTreeViewItems[tempselectedTV].id
	tempselectedType := allTreeViewItems[tempselectedTV].type
	
	guicontrol, disable,TreeView_manager
	;first delete everything
	TV_Delete()
	
	;Add demo category if user wants to see it
	if not (_settings.HideDemoFlows)
		_share.demoCategoryTV:=TreeView_manager_AddEntry("Category", "demo")
	_share.uncategorizedCategoryTV:=""
	;go through all categories and add the tv elements
	for onecategoryID, onecategory in _share.allCategories
	{
		onecategory.tv:=TreeView_manager_AddEntry("Category", onecategoryID)
	}
	
	;go through all flows and add the tv elements
	for oneflowID, oneflow in _flows
	{
		;Add uncategorized category if there are flows without a category
		if ((not oneflow.category) and (not _share.uncategorizedCategoryTV) and (not oneflow.demo))
		{
			_share.uncategorizedCategoryTV:=TreeView_manager_AddEntry("Category", "uncategorized")
		}
			
		;hide demo flows, if user wants
		;~ MsgBox % _settings.HideDemoFlows " - " oneflow.demo
		if not (_settings.HideDemoFlows && oneflow.demo)
			oneflow.tv:=TreeView_manager_AddEntry("Flow", oneflowID)
	}
	
	TreeView_manager_Select(tempselectedType, tempselectedID)
	guicontrol, enable,TreeView_manager
}


TreeView_manager_AddEntry(par_Type, par_ID)
{
	global
	local newTV
	if not (ManagerGUIHWND)
		return
	Gui, manager:default
	
	if (par_Type = "flow")
	{
		if (_flows[par_ID].demo)
		{
			newTV := TV_Add(_flows[par_ID].name, _share.democategoryTV, Icon_Disabled)
		}
		else if (not _flows[par_ID].category)
		{
			newTV := TV_Add(_flows[par_ID].name, _share.uncategorizedCategoryTV, Icon_Disabled)
		}
		else
		{
			newTV := TV_Add(_flows[par_ID].name, _share.allCategories[_flows[par_ID].category].tv, Icon_Disabled)
		}
	}
	else if (par_Type = "category")
	{
		if (par_ID = "demo")
		{
			newTV := TV_Add(lang("Demonstration"), "", Icon_Folder)
		}
		else if (par_ID = "uncategorized")
		{
			newTV := TV_Add(lang("Uncategorized"), "", Icon_Folder)
		}
		else
		{
			newTV := TV_Add(_share.allCategories[par_ID].name, "", Icon_Folder)
		}
	}
	else
		MsgBox unexpected error. 3546548486432

	allTreeViewItems[newTV] := {id: par_ID, type: par_Type}
	return newTV
}

TreeView_manager_DeleteEntry(par_Type, par_ID)
{
	global
	if not (ManagerGUIHWND)
		return
	Gui, manager:default
	
	if (par_Type = "flow")
	{
		if (_flows[par_ID].tv = "")
		{
			MsgBox unexpected error. 88989984942
			return
		}
		
		TV_Delete(_flows[par_ID].tv)
		allTreeViewItems.delete(_flows[par_ID].tv)
	}
	else if (par_Type = "category")
	{
		if (_share.allCategories[par_ID].tv = "")
		{
			MsgBox unexpected error. 88989984943
			return
		}
		TV_Delete(_share.allCategories[par_ID].tv)
		allTreeViewItems.delete(_share.allCategories[par_ID].tv)
	}
	else
		MsgBox unexpected error. 165864846


	return
}

TreeView_manager_Select(par_Type, par_ID, options = "")
{
	global
	if not (ManagerGUIHWND)
		return
	Gui, manager:default
	if (par_Type = "flow")
	{
		TV_Modify(_share.allCategories[_flows[par_ID].category].tv, "expand") ;Expand the category
		TV_Modify(_flows[par_ID].tv) ;Mark
	}
	else if (par_Type = "category")
	{
		TV_Modify(_share.allCategories[par_ID].tv) ;Mark
		IfInString,options, expand
			TV_Modify(_share.allCategories[par_ID].tv, "expand") ;Expand the category
			
	}
}

TreeView_manager_Rename(par_Type, par_ID)
{
	global
	if not (ManagerGUIHWND)
		return
	Gui, manager:default
	TreeView_manager_Select(par_Type, par_ID)
	controlsend, , {F2},ahk_id %TreeView_manager_HWND%
}


;react on gui events on the treeview
TreeView_manager()
{
	global
	local tempselectedTV
	local tempselectedID
	local tempselectedType
	local tempNewName
	local tempitem
	gui,manager:default
	tempselectedTV := TV_GetSelection()
	tempselectedID := allTreeViewItems[tempselectedTV].id
	tempselectedType := allTreeViewItems[tempselectedTV].type
	
	if A_GuiEvent =e ;If user has renamed an entry
	{
		TV_GetText(tempNewName, tempselectedTV)
		;~ d(tempNewName)
		
		if tempselectedType = category ;If the item is a category
		{
			tempOldName := _share.allCategories[tempselectedID].name
			if !(tempOldName == tempNewName) ;If user finished renaming entry and the name has changed
			{
				;Do not rename demonstration category
				if (tempselectedID = "demo" and tempNewName != lang("Demonstration"))
				{
					soundplay,*16
					MsgBox, 16, % lang("Rename category"), % lang("The demonstration category cannot be renamed")
					TV_Modify(tempselectedTV, "", lang("Demonstration"))
					return
				}
				;Do not rename if user has entered an empty name
				if (tempNewName = "")
				{
					soundplay,*16
					MsgBox, 16, % lang("Rename category"), % lang("A_category_can_not_have_an_empty_name")
					TV_Modify(tempselectedTV, "", tempOldName)
					return
				}
				;Do not rename if another category with same name already exists
				if ((FlowIDbyName(tempNewName,"Category") != "") and (FlowIDbyName(tempNewName,"Category") != tempselectedID))
				{
					soundplay,*16
					MsgBox, 16, % lang("Rename category"), % lang("A_category_with_name_%1%_already_exists", tempNewName)
					TV_Modify(tempselectedTV, "", tempOldName)
					return
				}
				
				if (tempselectedID = "uncategorized")
				{
					;create new category
					newcategoryid:=API_Main_NewCategory(tempNewName)
					tempselectedID:=""
				}
				else
				{
					newcategoryid:=tempselectedID
				}
				;rename
				_share.allCategories[newcategoryid].name := tempNewName
				
				;all flows of that category must be saved
				for tempflowid, tempitem in _flows
				{
					if (tempitem.category = tempselectedID)
					{
						API_Main_ChangeFlowCategory(tempflowid, newcategoryid)
						;~ d(tempitem)
						API_Main_SaveFlowMetaData(tempitem.id)
					}
					
				}
				;~ tooltip(lang("Renamed"))
				
			}
		}
		else if tempselectedType = flow ;If the item is a flow
		{
			tempOldName := _flows[tempselectedID].name
			if !(tempOldName == tempNewName) ;If user finished renaming entry and the name has changed
			{
				;Do not rename if user has entered an empty name
				if (tempNewName = "")
				{
					soundplay,*16
					MsgBox, 16, % lang("Rename flow"), % lang("A_flow_can_not_have_an_empty_name")
					TV_Modify(tempselectedTV, "", tempOldName)
					return
				}
				;Do not rename if there are prohibited characters.
				;reason: Flow names can be shown and selected in a listbox. When getting multiple flow names from the listbox, they are separated by |
				if (instr(tempNewName,"|"))
				{
					soundplay,*16
					MsgBox, 16, % lang("Rename flow"), % lang("Following characters are prohibited in a flow name: ""%1%""", "|")
					;just remove that character
					StringReplace, tempNewName, tempNewName, |,%a_space%, all
					TV_Modify(tempselectedTV, "", tempNewName)
				}
				;Do not rename if there another category with same name already exists
				if ((FlowIDbyName(tempNewName,"flow") != "") and (FlowIDbyName(tempNewName,"flow") != tempselectedID))
				{
					soundplay,*16
					MsgBox, 16, % lang("Rename flow"), % lang("A_flow_with_name_%1%_already_exists", tempNewName)
					TV_Modify(tempselectedTV, "", tempOldName)
					return
				}
				
				;rename
				_flows[tempselectedID].name := tempNewName
				API_Main_SaveFlowMetaData(tempSelectedID)
				
				;TODO catch if editor is opened,
				
				;todo warn if the name begins with "D_"
				
				if (substr(tempNewName,1,2)="D_")
					MsgBox, 48,% lang("Warning"),% lang("The name of the flow begins with %1%! Such flows will be deleted or overwritten on next update!","D_")
			
			}
			
			
		}
		return
	}


	if (A_GuiEvent ="s") ;If user has selected an item. En- or disable some buttons.
	{
		
		if (tempselectedType = "flow")
		{
			guicontrol,enable,Button_manager_EditFlow
			guicontrol,enable,Button_manager_RunFlow
			guicontrol,enable,Button_manager_EnableFlow
			guicontrol,enable,Button_manager_ChangeCategory
			guicontrol,enable,Button_manager_Delete
			guicontrol,enable,Button_manager_DuplicateFlow
		}
		else
		{
			guicontrol,Disable,Button_manager_EditFlow
			guicontrol,Disable,Button_manager_RunFlow
			guicontrol,Disable,Button_manager_EnableFlow
			guicontrol,Disable,Button_manager_ChangeCategory
			guicontrol,Disable,Button_manager_DuplicateFlow
			guicontrol,enable,Button_manager_Delete
		}
		
		if (tempselectedType.enabled = true)
			guicontrol,,Button_manager_EnableFlow,% lang("Disable")
		else
			guicontrol,,Button_manager_EnableFlow,% lang("Enable")
		if (tempselectedType.running = true)
			guicontrol,,Button_manager_RunFlow,% lang("Stop")
		else
			guicontrol,,Button_manager_RunFlow,% lang("Run")
	}
}

;Show context menu on right click of user in TreeView
managerGuiContextMenu()
{
	global
	; Launched in response to a right-click or press of the Apps key.
	if A_GuiControl <> TreeView_manager  ;It displays the menu only for clicks inside the TreeView.
		return
	
	;Find out what is selected
	tempselectedTV := TV_GetSelection()
	tempselectedID := allTreeViewItems[tempselectedTV].id
	tempselectedType := allTreeViewItems[tempselectedTV].type
	
	;Build the menu
	if (tempselectedType = "flow")
	{
		try menu,manager_menu,deleteall
		menu,manager_menu,add,manager_menu_rename
		menu,manager_menu,rename,manager_menu_rename,% lang("Rename flow")
		menu,manager_menu,add,manager_menu_changeCategory
		menu,manager_menu,rename,manager_menu_changeCategory,% lang("Change category")
		menu,manager_menu,add,manager_menu_delete
		menu,manager_menu,rename,manager_menu_delete,% lang("Delete flow")
		menu,manager_menu,add,manager_menu_duplicate
		menu,manager_menu,rename,manager_menu_duplicate,% lang("Duplicate flow")
	}
	else if (tempselectedType = "category")
	{
		try menu,manager_menu,deleteall
		menu,manager_menu,add,manager_menu_rename
		menu,manager_menu,rename,manager_menu_rename,% lang("Rename category")
		menu,manager_menu,add,manager_menu_newFlow
		menu,manager_menu,rename,manager_menu_newFlow,% lang("New flow")
		menu,manager_menu,add,manager_menu_delete
		menu,manager_menu,rename,manager_menu_delete,% lang("Delete category")
	}
	else
		return
	
	; Show the menu at the provided coordinates, A_GuiX and A_GuiY.  These should be used
	; because they provide correct coordinates even if the user pressed the Apps key:
	Menu, manager_menu, Show, %A_GuiX%, %A_GuiY%
return
}

manager_menu_delete()
{
	;Same as if user has pressed the button
	Button_manager_Delete()
}
manager_menu_duplicate()
{
	;Same as if user has pressed the button
	Button_manager_DuplicateFlow()
}
manager_menu_rename()
{
	global
	controlsend,, {f2},ahk_id %TreeView_manager_HWND%
}
manager_menu_newFlow()
{
	;Same as if user has pressed the button
	Button_manager_NewFlow()
}
manager_menu_changeCategory()
{
	;Same as if user has pressed the button
	Button_manager_ChangeCategory()
}




Button_manager_NewCategory(par_Type, par_ID)
{
	global
	local newCategoryID
	local newTV
	gui,manager:default
	
	newCategoryID := API_Main_NewCategory()
	TreeView_manager_Rename("category", newCategoryID)
}


Button_manager_NewFlow()
{
	global
	local tempSelectedTV
	local tempSelectedID
	local NewFlowID
	gui,manager:default
	
	tempSelectedTV := TV_GetSelection()
	if (tempSelectedTV != 0) ;If an element is selected
	{
		;Create new flow in the category of selected element
		tempSelectedID := allTreeViewItems[tempSelectedTV].id
		
		if (allTreeViewItems[tempSelectedTV].type = "Category")
		{
			NewFlowID := API_Main_NewFlow(tempSelectedID)
		}
		else if (allTreeViewItems[tempSelectedTV].type = "Flow")
		{
			NewFlowID := API_Main_NewFlow(allTreeViewItems[TV_GetParent(tempSelectedTV)].id)
		}
		else
		{
			MsgBox,,Unexpected error, The type of selected element could not be resolved!
		}
		
	}
	else ;If nothing is selected
	{
		;Create a flow in category "uncategorized"
		NewFlowID := API_Main_NewFlow()
	}
	TreeView_manager_Rename("flow", NewFlowID)
}

Button_manager_ChangeCategory()
{
	global
	local tempSelectedTV
	gui,manager:default
	tempSelectedTV := TV_GetSelection()
	if (allTreeViewItems[tempselectedTV].type = "flow")
	{
		changeFlowCategory_GUI(allTreeViewItems[tempselectedTV].id)
	}
}
Button_manager_DuplicateFlow()
{
	global
	gui,manager:default
	
	tempselectedTV := TV_GetSelection()
	tempselectedID := allTreeViewItems[tempselectedTV].id
	tempselectedType := allTreeViewItems[tempselectedTV].type
	
	if tempselectedType=flow ;this can only be performed on flows
		API_Main_DuplicateFlow(tempselectedID)
}

Button_manager_Import_Export()
{
	import_and_export_gui()
}

Button_manager_Help()
{
	ui_showHelp()
}

Button_manager_EditFlow()
{
	global
	API_Main_editFlow(allTreeViewItems[TV_GetSelection()].id)
}

Button_manager_RunFlow()
{
	global
	API_Main_ExecuteToggleFlow(allTreeViewItems[TV_GetSelection()].id)
}

Button_manager_EnableFlow()
{
	global
	API_Main_EnabletoggleFlow(allTreeViewItems[TV_GetSelection()].id)
}

;Delete marked Item
Button_manager_Delete()
{
	global
	local tempselectedTV
	local tempselectedID
	local tempselectedType
	local temphasFlows
	local tempUncategorizedID
	local tempUncategorizedTV
	gui,manager:default
	tempselectedTV := TV_GetSelection()
	tempselectedID := allTreeViewItems[tempselectedTV].id
	tempselectedType := allTreeViewItems[tempselectedTV].type
	
	if tempselectedType=flow ;if a flow should be deleted
	{
		Disable_Manager_GUI()
		
		if (_flows[tempselectedID].demo)
		{
			MsgBox, 52, AutoHotFlow, % lang("You cannot delete the demonstration flows, but you can hide all of them.") "`n" lang("Do you want to do that now?")
			IfMsgBox yes
			{
				_settings.HideDemoFlows:=true
				TreeView_manager_Refill()
				API_Main_write_settings()
			}
		}
		else
		{
			;ask user for confirmation
			MsgBox, 4, % lang("Confirm_deletion"),% lang("Do_you_really_want_to_delete_the_flow_%1%?",_flows[tempselectedID].name)
			IfMsgBox,Yes
			{
				;delete
				API_Main_DeleteFlow(tempselectedID)
				
			}
		}
		
	}
	else if tempselectedType=category ;if a category should be deleted
	{
		Disable_Manager_GUI()
		if (tempselectedID = "uncategorized") ;Do not remove the uncategorized category, since there are flows
		{
			soundplay,*16
			MsgBox, 16, % lang("Delete category"), % lang("This_category_can_not_be_removed")
		}
		else if (tempselectedID = "demo")
		{
			MsgBox, 52, AutoHotFlow, % lang("You cannot delete the demonstration category, but you can hide all demonstration flows.") "`n" lang("Do you want to do that now?")
			IfMsgBox yes
			{
				_settings.HideDemoFlows:=true
				TreeView_manager_Refill()
				API_Main_write_settings()
			}
		}
		else
		{
			;Check, whether the category has flows
			temphasFlows := false
			for count, oneFlow in _flows
			{
				if (oneFlow.category = tempselectedID)
					temphasFlows := true
			}
			
			if (temphasFlows = true)
			{
				;If there are flows inside the category
				;ask user for confirmation
				MsgBox, 4, % lang("Confirm_deletion"),% lang("Do_you_really_want_to_delete_the_category_%1%?",_share.allCategories[tempselectedID].name) "`n" lang("All_flows_of_that_category_will_be_moved_into_the_category",lang("Uncategorized")) ;confirm by user 
				IfMsgBox,Yes
				{
					;Create the category uncategorized if it is not present and get the tv
					;~ d(tempUncategorizedID)
					for count, tempFlow in _flows ;Move all flows that were inside the category to uncategorized
					{
						if (tempFlow.category = tempselectedID)
						{
							;~ d(tempFlow)
							API_Main_ChangeFlowCategory(tempFlow.id,"")
						}
					}
					
					API_Main_DeleteCategory(tempselectedID)
				}
			}
			else
			{
				API_Main_DeleteCategory(tempselectedID)
			}
		}
	}
	;debug()
	;~ removeUncategorizedCategoryIfPossible()
	Enable_Manager_GUI()
}

Button_manager_Settings()
{
	globalSettings_GUI()
}
Button_manager_About()
{
	;TODO
}

Button_manager_ShowLog()
{
	showlog()
}

Button_manager_Exit()
{
	exit_all()
}


