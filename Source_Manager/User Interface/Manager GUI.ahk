allTreeViewItems := Object()


init_Manager_GUI()
{
	global
	
	allItems:=object()
	
	;initialize image list
	IconList:=IL_Create("","",1)
	IL_Add(IconList,"Icons\disabled.ico")
	Icon_Disabled:="icon1"
	IL_Add(IconList,"Icons\enabled.ico")
	Icon_Enabled:="icon2"
	IL_Add(IconList,"Icons\running.ico")
	Icon_Running:="icon3"
	IL_Add(IconList,"Icons\folder.ico")
	Icon_Folder:="icon4"
	gui,manager:default

	;Create main GUI
	gui,font,s15
	Gui, Add, TreeView, vTreeView_manager gTreeView_manager x10 y10 w300 h500 -ReadOnly AltSubmit ImageList%IconList%
	gui,font,s12
	gui,add,Button,vButton_manager_NewCategory gButton_manager_NewCategory X330 yp w200 h30 , % lang("New_Category")
	gui,add,Button,vButton_manager_NewFlow gButton_manager_NewFlow X+10 yp w200 h30, % lang("New_Flow")
	gui,add,Button,vButton_manager_ChangeCategory gButton_manager_ChangeCategory Disabled Y+30 x330 w200 h30, % lang("Change_category")
	;gui,add,Button,vButtonCopyFlow gButtonCopyFlow Disabled X+10 yp w200 h30, % lang("Copy")
	gui,add,Button,vButton_manager_EditFlow gButton_manager_EditFlow Disabled Y+30 x330 w200 h30, % lang("Edit")
	gui,add,Button,vButton_manager_DeleteFlow gButton_manager_DeleteFlow Disabled X+10 yp w200 h30, % lang("delete")
	gui,add,Button,vButton_manager_EnableFlow gButton_manager_EnableFlow Disabled Y+30 x330 w200 h30, % lang("enable")
	gui,add,Button,vButton_manager_RunFlow gButton_manager_RunFlow Disabled X+10 yp w200 h30,% lang("Run")

	gui,add,Button,vButton_manager_SelectLanguage gButton_manager_SelectLanguage  X330 Y+100 w200 h30,% lang("Change_Language")
	gui,add,Button,vButton_manager_Help gButton_manager_Help X+10 yp w200 h30,% lang("Help")
	gui,add,Button,vButton_manager_Settings gButton_manager_Settings  X330 Y+20 w200 h30,% lang("Settings")
	gui,add,Button,vButton_manager_About gButton_manager_About  X330 Y+20 w200 h30,% lang("About AutoHotFlow")
	gui,add,Button,vButton_manager_ShowLog gButton_manager_ShowLog  X330 Y+20 w200 h30,% lang("Show log")
	gui,add,Button,vButton_manager_Exit gButton_manager_Exit X+10 yp w200 h30,% lang("Exit")

	gui,+hwndManagerGUIHWND
	_share.hwnds.Manager := ManagerGUIHWND
	
	updateFlowIcons_Manager_GUI()
	
	if a_iscompiled
	{
		menu,tray, tip,% "AutoHotFlow " lang("Manager")
		Gui, Show,hide, % "AutoHotFlow " lang("Manager")  ; Do not show window while loading flows. Otherway the treeview will not show the plus signs
	}
	else ;Helps me to find the uncompiled AHF instance
	{
		menu,tray, tip,% "AutoHotFlow " lang("Manager") " - UNCOMPILED "
		Gui, Show,hide, % "AutoHotFlow " lang("Manager") " - UNCOMPILED "
	}
	
	settimer, updateFlowIcons_Manager_GUI, 100
}

Refresh_Manager_GUI()
{
	gui,manager:default
	
	guicontrol,,Button_manager_NewCategory , % lang("New_Category")
	guicontrol,,Button_manager_NewFlow , % lang("New_Flow")
	guicontrol,,Button_manager_ChangeCategory , % lang("Change_category")
	guicontrol,,Button_manager_EditFlow , % lang("Edit")
	guicontrol,,Button_manager_DeleteFlow , % lang("delete")
	guicontrol,,Button_manager_EnableFlow , % lang("enable")
	guicontrol,,Button_manager_RunFlow ,% lang("Run")

	guicontrol,,Button_manager_SelectLanguage ,% lang("Change_Language")
	guicontrol,,Button_manager_Settings ,% lang("Settings")
	guicontrol,,Button_manager_Help ,% lang("Help")
	guicontrol,,Button_manager_ShowLog ,% lang("Show log")
	guicontrol,,Button_manager_About ,% lang("About AutoHotFlow")
	guicontrol,,Button_manager_Exit ,% lang("Exit")

	Gui, Show,, % "AutoHotFlow " lang("Manager")  ; Show the window and its TreeView.

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
TreeView_manager_AddEntry(par_Type, par_ID)
{
	global
	Gui, manager:default
	local newTV
	local tempParentTV
	if (par_Type = "flow")
	{
		newTV := TV_Add(_flows[par_ID].name, _share.allCategories[_flows[par_ID].category].tv, Icon_Disabled)
	}
	else if (par_Type = "category")
	{
		newTV := TV_Add(_share.allCategories[par_ID].name, "", Icon_Folder)
	}
	else
		MsgBox unexpected error. 3546548486432

	allTreeViewItems[newTV] := {id: par_ID, type: par_Type}
	return newTV
}

TreeView_manager_DeleteEntry(par_Type, par_ID)
{
	global
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

TreeView_manager_Select(par_Type, par_ID)
{
	global
	Gui, manager:default
	if (par_Type = "flow")
	{
		TV_Modify(_share.allCategories[_flows[par_ID].category].tv, "expand") ;Expand the category
		TV_Modify(_flows[par_ID].tv) ;Mark
	}
	else if (par_Type = "category")
	{
		TV_Modify(_share.allCategories[par_ID].tv) ;Mark
	}
}

TreeView_manager_Rename(par_Type, par_ID)
{
	global
	Gui, manager:default
	TreeView_manager_Select(par_Type, par_ID)
	controlsend, SysTreeView321, {F2}, % "ahk_id " _share.hwnds.Manager ;Rename Entry
}

TreeView_manager_ChangeFlowCategory(par_ID)
{
	global
	gui,manager:default
	;~ d(_flows[par_ID])
	;~ d(allTreeViewItems,_flows[par_ID].TV)
	;~ d(_flows[par_ID],_share.allCategories[_flows[par_ID].category].tv)
	if (_flows[par_ID].tv = "")
	{
		;~ d(_flows[par_ID],845646)
		MsgBox unexpected error. 86486431861613
		return
	}
			
	res:=TV_Delete(_flows[par_ID].TV)
	;~ d(_flows[par_ID].TV, res)
	allTreeViewItems.delete(_flows[par_ID].TV)
	_flows[par_ID].TV := TV_Add(_flows[par_ID].name, _share.allCategories[_flows[par_ID].category].tv, Icon_Disabled)
	
	allTreeViewItems[_flows[par_ID].TV] := {id: par_ID, type: "flow"}
	;~ d(allTreeViewItems,_flows[par_ID].TV)
	
	TreeView_manager_Select("flow", par_ID)
	guicontrol, manager:focus, TreeView_manager
}

Button_manager_NewCategory(par_Type, par_ID)
{
	global
	local newCategoryID
	local newTV
	
	newCategoryID := NewCategory()
	TreeView_manager_Rename("category", newCategoryID)
}


Button_manager_NewFlow()
{
	global
	local tempSelectedTV
	local tempSelectedID
	local NewFlowID
	
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
	tempSelectedTV := TV_GetSelection()
	if (allTreeViewItems[tempselectedTV].type = "flow")
	{
		changeFlowCategory_GUI(allTreeViewItems[tempselectedTV].id)
	}
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
	API_Main_RuntoggleFlow(allTreeViewItems[TV_GetSelection()].id)
}

Button_manager_EnableFlow()
{
	global
	API_Main_EnabletoggleFlow(allTreeViewItems[TV_GetSelection()].id)
}

TreeView_manager()
{
	global
	local tempselectedTV
	local tempselectedID
	local tempselectedType
	local tempNewName
	local tempitem
	tempselectedTV := TV_GetSelection()
	tempselectedID := allTreeViewItems[tempselectedTV].id
	tempselectedType := allTreeViewItems[tempselectedTV].type
	
	if A_GuiEvent =E ;If user has renamed an entry
	{
		TV_GetText(tempNewName, tempselectedTV)
		;~ d(tempNewName)
		
		if tempselectedType = category ;If the item is a category
		{
			tempOldName := _share.allCategories[tempselectedID].name
			if !(tempOldName == tempNewName) ;If user finished renaming entry and the name has changed
			{
				;Do not rename if user has entered an empty name
				if (tempNewName = "")
				{
					soundplay,*16
					MsgBox, 16, % lang("Rename category"), % lang("A_category_can_not_have_an_empty_name")
					TV_Modify(tempselectedTV, "", tempOldName)
					return
				}
				;Do not rename if there another category with same name already exists
				if ((IDOfName(tempNewName,"Category") != "") and (IDOfName(tempNewName,"Category") != tempselectedID))
				{
					soundplay,*16
					MsgBox, 16, % lang("Rename category"), % lang("A_category_with_name_%1%_already_exists", tempNewName)
					TV_Modify(tempselectedTV, "", tempOldName)
					return
				}
				
				;rename
				_share.allCategories[tempselectedID].name := tempNewName
				
				;all flows of that category must be saved
				for count, tempitem in _flows
				{
					if (tempitem.category = tempselectedID)
					{
						UpdateFlowCategoryName(par_FlowID)
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
				;Do not rename if there another category with same name already exists
				if ((IDOfName(tempNewName,"flow") != "") and (IDOfName(tempNewName,"flow") != tempselectedID))
				{
					soundplay,*16
					MsgBox, 16, % lang("Rename flow"), % lang("A_flow_with_name_%1%_already_exists", tempNewName)
					TV_Modify(tempselectedTV, "", tempOldName)
					return
				}
				
				;rename
				_flows[tempselectedID].name := tempNewName
				API_Main_SaveFlowMetaData(tempSelectedID)
				
				;TODO if editor is opened,
				
				;warn if the name begins with "D_"
				
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
			guicontrol,enable,Button_manager_DeleteFlow
		}
		else
		{
			guicontrol,Disable,Button_manager_EditFlow
			guicontrol,Disable,Button_manager_RunFlow
			guicontrol,Disable,Button_manager_EnableFlow
			guicontrol,Disable,Button_manager_ChangeCategory
			guicontrol,enable,Button_manager_DeleteFlow
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


;Delete marked Item
Button_manager_DeleteFlow()
{
	global
	local tempselectedTV
	local tempselectedID
	local tempselectedType
	local temphasFlows
	local tempUncategorizedID
	local tempUncategorizedTV
	tempselectedTV := TV_GetSelection()
	tempselectedID := allTreeViewItems[tempselectedTV].id
	tempselectedType := allTreeViewItems[tempselectedTV].type

	if tempselectedType=flow ;if a flow should be deleted
	{
		Disable_Manager_GUI()
		
		;ask user for confirmation
		MsgBox, 4, % lang("Confirm_deletion"),% lang("Do_you_really_want_to_delete_the_flow_%1%?",_flows[tempselectedID].name)
		IfMsgBox,Yes
		{
			;delete
			TreeView_manager_DeleteEntry("Flow", tempselectedID)
			DeleteFlow(tempselectedID)
			
		}
		
	}
	else if tempselectedType=category ;if a category should be deleted
	{
		Disable_Manager_GUI()
		if (lang("Uncategorized") = _share.allCategories[tempselectedID].name) ;Do not remove the uncategorized category, since there are flows
		{
			soundplay,*16
			MsgBox, 16, % lang("Delete category"), % lang("This_category_can_not_be_removed")
			Enable_Manager_GUI()
			return
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
					
					tempUncategorizedID := NewCategory(lang("uncategorized"))
					tempUncategorizedTV := _share.allCategories[tempUncategorizedID].tv
					;~ d(tempUncategorizedID)
					for count, tempFlow in _flows ;Move all flows that were inside the category to uncategorized
					{
						if (tempFlow.category = tempselectedID)
						{
							;~ d(tempFlow)
							ChangeFlowCategory(tempFlow.id,tempUncategorizedID)
						}
					}
					
				}
				else
				{
					Enable_Manager_GUI()
					return
				}
				
				
			}
			TreeView_manager_DeleteEntry("Category", tempselectedID)
			DeleteCategory(tempselectedID)
		}
	}
	;debug()
	;~ removeUncategorizedCategoryIfPossible()
	Enable_Manager_GUI()
}

Button_manager_SelectLanguage()
{
	SelectLanguage_GUI()
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


