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
	_setSharedProperty("hwnds.Manager", ManagerGUIHWND)
	
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
	WinActivate,% "ahk_id " _getSharedProperty("hwnds.Manager")
}

updateFlowIcons_Manager_GUI()
{
	global 
	static currentIcons:=Object()
	static currentLabelButtonRun:=""
	static currentLabelButtonEnable:=""
	
	if (_getShared("FlowsTreeViewNeedFullRefresh"))
	{
		_setShared("FlowsTreeViewNeedFullRefresh", false)
		TreeView_manager_Refill()
	}
	
	Gui, manager:default
	local forFlowID, forFlow, selectedFlow
	
	EnterCriticalSection(_cs_shared)
	
	for forFlowIndex, forFlowID in _getAllFlowIds()
	{
		local flowTV := _getFlowProperty(forFlowID, "tv")
		if (_getFlowProperty(forFlowID, "executing") = True)
		{
			if (currentIcons[forFlowID]!=Icon_Running)
			{
				TV_Modify(flowTV, Icon_Running)
				currentIcons[forFlowID]:=Icon_Running
			}
		}
		else if (_getFlowProperty(forFlowID, "enabled") = true)
		{
			if (currentIcons[forFlowID]!=Icon_Enabled)
			{
				TV_Modify(flowTV, Icon_Enabled)
				currentIcons[forFlowID]:=Icon_Enabled
			}
		}
		else
		{
			if (currentIcons[forFlowID]!=Icon_Disabled)
			{
				TV_Modify(flowTV, Icon_Disabled)
				currentIcons[forFlowID]:=Icon_Disabled
			}
		}
		
	}
	
	local selectedFlowID := allTreeViewItems[TV_GetSelection()].id
	if (_getFlowProperty(selectedFlowID, "executing") = True)
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
	if (_getFlowProperty(selectedFlowID, "enabled") = True)
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
	
	LeaveCriticalSection(_cs_shared)
}

TreeView_manager_Refill()
{
	global
	local newTV
	local oneflowID, onecategoryID, onecategory
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
	local HideDemoFlows := _getSettings("HideDemoFlows")
	if not (HideDemoFlows)
	{
		local demoCategoryTV := TreeView_manager_AddEntry("Category", "demo")
		_setShared("demoCategoryTV", demoCategoryTV)
	}
	_setShared("uncategorizedCategoryTV", "")

	;go through all categories and add the tv elements
	for onecategoryIndex, onecategoryID in _getAllCategoryIds()
	{
		local categoryTV := TreeView_manager_AddEntry("Category", onecategoryID)
		_setCategoryProperty(onecategoryID, "tv", categoryTV)
	}
	
	EnterCriticalSection(_cs_shared)
	;go through all flows and add the tv elements
	local uncategorizedCategoryTV
	for oneflowIndex, oneflowID in _getAllFlowIds()
	{
		local oneFlowCategory := _getFlowProperty(oneflowID, "category")
		local oneFlowDemo := _getFlowProperty(oneflowID, "demo")
		;Add uncategorized category if there are flows without a category
		if ((not oneFlowCategory) and (not uncategorizedCategoryTV) and (not oneFlowDemo))
		{
			uncategorizedCategoryTV:=TreeView_manager_AddEntry("Category", "uncategorized")
		}
			
		;hide demo flows, if user wants
		if not (HideDemoFlows && oneFlowDemo)
		{
			oneflow.tv:=TreeView_manager_AddEntry("Flow", oneflowID)
		}
	}
	_setShared("uncategorizedCategoryTV", uncategorizedCategoryTV)
	LeaveCriticalSection(_cs_shared)
	
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
		local flowName := _getFlowProperty(par_ID, "name")

		if (_getFlowProperty(par_ID, "demo"))
		{
			newTV := TV_Add(flowName, _getShared("democategoryTV"), Icon_Disabled)
		}
		else if (not _getFlowProperty(par_ID, "category"))
		{
			newTV := TV_Add(flowName, _getShared("uncategorizedCategoryTV"), Icon_Disabled)
		}
		else
		{
			local categoryID := _getFlowProperty(par_ID, "category")
			newTV := TV_Add(flowName, _getCategoryProperty(categoryID, "tv"))
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
			newTV := TV_Add(_getCategoryProperty(par_ID, "name"), "", Icon_Folder)
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
		local flowTV := _getFlowProperty(par_ID, "tv")
		if (flowTV = "")
		{
			MsgBox unexpected error. 88989984942
			return
		}
		
		TV_Delete(flowTV)
		allTreeViewItems.delete(flowTV)
	}
	else if (par_Type = "category")
	{
		local categoryTV := _getCategoryProperty(par_ID, "tv")
		if (categoryTV = "")
		{
			MsgBox unexpected error. 88989984943
			return
		}
		TV_Delete(categoryTV)
		allTreeViewItems.delete(categoryTV)
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
		local categoryID := _getFlowProperty(par_ID, "category")
		TV_Modify(_getCategoryProperty(categoryID, "tv"), "expand") ;Expand the category
		TV_Modify(_getFlowProperty(par_ID, "tv")) ;Mark
	}
	else if (par_Type = "category")
	{
		local categoryTV := _getCategoryProperty(par_ID, "tv")
		TV_Modify(categoryTV) ;Mark
		IfInString,options, expand
			TV_Modify(categoryTV, "expand") ;Expand the category
			
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
	local tempflowid
	gui,manager:default
	tempselectedTV := TV_GetSelection()
	tempselectedID := allTreeViewItems[tempselectedTV].id
	tempselectedType := allTreeViewItems[tempselectedTV].type
	
	if A_GuiEvent =e ;If user has renamed an entry
	{
		TV_GetText(tempNewName, tempselectedTV)
		;~ d(tempNewName)
		
		if (tempselectedType = "category") ;If the item is a category
		{
			tempOldName := _getCategoryProperty(tempselectedID, "name")
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
					newcategoryid:=NewCategory(tempNewName)
					tempselectedID:=""
				}
				else
				{
					newcategoryid:=tempselectedID
				}
				;rename
				_setCategoryProperty(newcategoryid, "name", tempNewName)
				
				;all flows of that category must be saved
				EnterCriticalSection(_cs_shared)
				
				for tempflowIndex, tempflowId in _getAllFlowIds()
				{
					if (_getFlowProperty(tempflowId, "category") = tempselectedID)
					{
						ChangeFlowCategory(tempflowid, newcategoryid)
						;~ d(tempitem)
						SaveFlowMetaData(tempflowid)
					}
					
				}
				
				LeaveCriticalSection(_cs_shared)
				;~ tooltip(lang("Renamed"))
				
			}
		}
		else if (tempselectedType = "flow") ;If the item is a flow
		{
			tempOldName := _getFlowProperty(tempselectedID, "name")
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
				_setFlowProperty(tempselectedID, "name", tempNewName)
				SaveFlowMetaData(tempSelectedID)
				
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
	
	newCategoryID := NewCategory()
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
			NewFlowID := NewFlow(tempSelectedID)
		}
		else if (allTreeViewItems[tempSelectedTV].type = "Flow")
		{
			NewFlowID := NewFlow(allTreeViewItems[TV_GetParent(tempSelectedTV)].id)
		}
		else
		{
			MsgBox,,Unexpected error, The type of selected element could not be resolved!
		}
		
	}
	else ;If nothing is selected
	{
		;Create a flow in category "uncategorized"
		NewFlowID := NewFlow()
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
		DuplicateFlow(tempselectedID)
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
	editFlow(allTreeViewItems[TV_GetSelection()].id)
}

Button_manager_RunFlow()
{
	global
	ExecuteToggleFlow(allTreeViewItems[TV_GetSelection()].id)
}

Button_manager_EnableFlow()
{
	global
	EnabletoggleFlow(allTreeViewItems[TV_GetSelection()].id)
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
		
		if (_getFlowProperty(tempselectedID, "name"))
		{
			MsgBox, 52, AutoHotFlow, % lang("You cannot delete the demonstration flows, but you can hide all of them.") "`n" lang("Do you want to do that now?")
			IfMsgBox yes
			{
				_setSettings("HideDemoFlows", true)
				TreeView_manager_Refill()
				write_settings()
			}
		}
		else
		{
			;ask user for confirmation
			MsgBox, 4, % lang("Confirm_deletion"),% lang("Do_you_really_want_to_delete_the_flow_%1%?", _getFlowProperty(tempselectedID, "name"))
			IfMsgBox,Yes
			{
				;delete
				DeleteFlow(tempselectedID)
				
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
				_setSettings("HideDemoFlows", true)
				TreeView_manager_Refill()
				write_settings()
			}
		}
		else
		{
			;Check, whether the category has flows
			temphasFlows := false
			for oneFlowIndex, oneFlowID in _getAllFlowIds()
			{
				if (_getFlowProperty(oneFlowID, "category") = tempselectedID)
					temphasFlows := true
			}
			
			if (temphasFlows = true)
			{
				;If there are flows inside the category
				;ask user for confirmation
				local tempCategoryName := _getCategoryProperty(tempselectedID, "name")
				MsgBox, 4, % lang("Confirm_deletion"),% lang("Do_you_really_want_to_delete_the_category_%1%?", tempCategoryName) "`n" lang("All_flows_of_that_category_will_be_moved_into_the_category",lang("Uncategorized")) ;confirm by user 
				IfMsgBox,Yes
				{
					;Create the category uncategorized if it is not present and get the tv
					;~ d(tempUncategorizedID)
					for tempFlowIndex, tempFlowID in _getAllFlowIds() ;Move all flows that were inside the category to uncategorized
					{
						if (_getFlowProperty(oneFlowID, "category") = tempselectedID)
						{
							;~ d(tempFlow)
							ChangeFlowCategory(tempFlowID,"")
						}
					}
					
					DeleteCategory(tempselectedID)
				}
			}
			else
			{
				DeleteCategory(tempselectedID)
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
	API_Main_Exit()
}


