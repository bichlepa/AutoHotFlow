global global_allTreeViewItems := Object()
global global_Treeview_currentIcons := Object()
global global_ManagerGUIHWND := ""
global global_ManagerGUIControlHWNDs := ""

; Initialize the manager gui. Does not show it.
init_Manager_GUI()
{
	global

	logger("a2", "initializing manager GUI")
	
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

	; Write translated labels in the manager gui window
	Refresh_Manager_GUI()

	; Save manager hwnd
	gui,+hwndglobal_ManagerGUIHWND
	_setSharedProperty("hwnds.Manager", global_ManagerGUIHWND)
	
	; set the gui icon
	gui, +LastFound
	setGuiIcon(_ScriptDir "\icons\MainIcon.ico")

	;Set title. Do not show yet
	Gui, Show, hide, % "AutoHotFlow " lang("Manager") " " _getShared("AhfVersion")
	
	; enable hotkeys
	OnMessage(0x100, "keyPressed", 1)

	; the icons of the flows are going to be updated repeatedly.
	settimer, updateFlowIcons_Manager_GUI, 100
}

; Write translated labels in the manager gui window
Refresh_Manager_GUI()
{
	gui,manager:default
	
	guicontrol,,Button_manager_NewCategory , % lang("New_Category")
	guicontrol,,Button_manager_NewFlow , % lang("New_Flow")
	guicontrol,,Button_manager_ChangeCategory , % lang("Change_category")
	guicontrol,,Button_manager_DuplicateFlow , % lang("Duplicate #verb")
	guicontrol,,Button_manager_Delete , % lang("Delete")
	guicontrol,,Button_manager_EditFlow , % lang("Edit #verb")
	guicontrol,,Button_manager_EnableFlow , % lang("enable")
	guicontrol,,Button_manager_RunFlow ,% lang("Run #verb")

	guicontrol,,Button_manager_Import_Export ,% lang("Import and export")
	guicontrol,,Button_manager_Settings ,% lang("Settings")
	guicontrol,,Button_manager_Help ,% lang("Help #noun")
	guicontrol,,Button_manager_ShowLog ,% lang("Show log")
	guicontrol,,Button_manager_About ,% lang("About AutoHotFlow")
	guicontrol,,Button_manager_Exit ,% lang("Exit #verb")
}

; Show the manager gui
Show_Manager_GUI()
{
	Gui, manager:Show
}

; Hide the manager gui
Hide_Manager_GUI()
{
	Gui, manager:hide
}

; Disable the manager gui. It is used if an other gui is shown in the foreground, like element settings.
Disable_Manager_GUI()
{
	global
	gui,manager:+disabled
}

;Enable the manager gui
Enable_Manager_GUI()
{
	global
	gui,manager:-disabled
	; somehow the manager gui goes to background if it it reenabled. Activate it as workaround
	WinActivate,% "ahk_id " _getSharedProperty("hwnds.Manager")
}

; Updates the icons of the flows, which show the user whether the flow is disabled, enabled or executing
updateFlowIcons_Manager_GUI()
{
	global 
	static currentLabelButtonRun := ""
	static currentLabelButtonEnable := ""
	
	;TODO: Skip if manger gui is hidden

	; if the treeview needs a full refresh, do it
	if (_getShared("FlowsTreeViewNeedFullRefresh"))
	{
		_setShared("FlowsTreeViewNeedFullRefresh", false)
		TreeView_manager_Refill()
	}
	
	Gui, manager:default
	
	_EnterCriticalSection()
	
	; loop throuth all flows and set the icons
	local forFlowID, forFlowIndex
	for forFlowIndex, forFlowID in _getAllFlowIds()
	{
		local flowTV := _getFlowProperty(forFlowID, "tv")
		if (_getFlowProperty(forFlowID, "executing") = True)
		{
			if (global_Treeview_currentIcons[forFlowID] != Icon_Running)
			{
				TV_Modify(flowTV, Icon_Running)
				global_Treeview_currentIcons[forFlowID] := Icon_Running
			}
		}
		else if (_getFlowProperty(forFlowID, "enabled") = true)
		{
			if (global_Treeview_currentIcons[forFlowID] != Icon_Enabled)
			{
				TV_Modify(flowTV, Icon_Enabled)
				global_Treeview_currentIcons[forFlowID] := Icon_Enabled
			}
		}
		else
		{
			if (global_Treeview_currentIcons[forFlowID] != Icon_Disabled)
			{
				TV_Modify(flowTV, Icon_Disabled)
				global_Treeview_currentIcons[forFlowID] := Icon_Disabled
			}
		}
		
	}
	
	; If a flow is selected, change tha labels of some buttons
	local selectedFlowID := global_allTreeViewItems[TV_GetSelection()].id
	if (_getFlowProperty(selectedFlowID, "executing") = True)
	{
		if (currentLabelButtonRun != "stop")
		{
			guicontrol,,Button_manager_RunFlow ,% lang("Stop #verb")
			currentLabelButtonRun := "Stop"
		}
	}
	else
	{
		if (currentLabelButtonRun != "Run")
		{
			guicontrol,,Button_manager_RunFlow ,% lang("Run #verb")
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
	
	_LeaveCriticalSection()
}

; Dismisses the treeview and refills it
TreeView_manager_Refill()
{
	global

	if not (global_ManagerGUIHWND)
		return

	Gui, manager:default
	
	; Before deleting the tree view, get the selected item, in order to reselect it later
	local tempselectedTV := TV_GetSelection()
	local tempselectedID := global_allTreeViewItems[tempselectedTV].id
	local tempselectedType := global_allTreeViewItems[tempselectedTV].type
	
	; Disable gui to prevent errors if user interacts with the gui during the update
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
	local onecategoryIndex, onecategoryID
	for onecategoryIndex, onecategoryID in _getAllCategoryIds()
	{
		local categoryTV := TreeView_manager_AddEntry("Category", onecategoryID)
		_setCategoryProperty(onecategoryID, "tv", categoryTV)
	}
	
	_EnterCriticalSection()
	;go through all flows and add the tv elements
	local uncategorizedCategoryTV
	local oneflowIndex, oneflowID
	for oneflowIndex, oneflowID in _getAllFlowIds()
	{
		local oneFlowCategory := _getFlowProperty(oneflowID, "category")
		local oneFlowDemo := _getFlowProperty(oneflowID, "demo")

		;Add uncategorized category if there are flows without a category
		if ((not oneFlowCategory) and (not uncategorizedCategoryTV) and (not oneFlowDemo))
		{
			uncategorizedCategoryTV:=TreeView_manager_AddEntry("Category", "uncategorized")
			_setShared("uncategorizedCategoryTV", uncategorizedCategoryTV)
		}
			
		;hide demo flows, if user wants
		if not (HideDemoFlows && oneFlowDemo)
		{
			; Add the flow to the treeview
			local newTV:=TreeView_manager_AddEntry("Flow", oneflowID)
			_setFlowProperty(oneflowID, "tv", newTV)
		}
	}

	_LeaveCriticalSection()

	; the icons need to be reassigned after a refill
	global_Treeview_currentIcons := []

	guicontrol, enable, TreeView_manager
}

;Add an entry to the tree view
; Can add a flow or a category. If a flow is added, the category of this flow must already exist.
TreeView_manager_AddEntry(par_Type, par_ID)
{
	global

	if not (global_ManagerGUIHWND)
		return

	Gui, manager:default
	
	local newTV
	if (par_Type = "flow")
	{
		; a flow should be added

		local flowName := _getFlowProperty(par_ID, "name")
		local categoryID := _getFlowProperty(par_ID, "category")

		if (_getFlowProperty(par_ID, "demo"))
		{
			; All demo flows will get in the category "demo" regardless of the categoryID
			newTV := TV_Add(flowName, _getShared("democategoryTV"), Icon_Disabled)
		}
		else if (not categoryID)
		{
			; If the categoryID is empty, it will be added to the uncategorized category
			newTV := TV_Add(flowName, _getShared("uncategorizedCategoryTV"), Icon_Disabled)
		}
		else
		{
			; The category is known, insert the flow inside the category
			newTV := TV_Add(flowName, _getCategoryProperty(categoryID, "tv"))
		}
		_setFlowProperty(par_ID, "tv", newTV)
	}
	else if (par_Type = "category")
	{
		if (par_ID = "demo")
		{
			; The demo category has always the ID "demo" and an unchangeable name
			newTV := TV_Add(lang("Demonstration"), "", Icon_Folder)
		}
		else if (par_ID = "uncategorized")
		{
			; The uncategorized category has always the ID "uncategorized" and an unchangeable name
			newTV := TV_Add(lang("Uncategorized"), "", Icon_Folder)
		}
		else
		{
			; This is a custom named category
			newTV := TV_Add(_getCategoryProperty(par_ID, "name"), "", Icon_Folder)
		}
	}
	else
	{
		MsgBox unexpected error. 3546548486432
		return
	}

	; Add the tree view entry to a list for later use
	global_allTreeViewItems[newTV] := {id: par_ID, type: par_Type}
	return newTV
}

; Select a tree view entry. Can select a flow or a category.
; If a flow should be selected, the category of the flow is automatically expanded.
; If a category should be selected, it is possible also to expand it
TreeView_manager_Select(par_Type, par_ID, options = "")
{
	global

	if not (global_ManagerGUIHWND)
		return
	if not par_Type
		return

	Gui, manager:default

	if (par_Type = "flow")
	{
		; A flow should be selected
		; expand the category
		local categoryID := _getFlowProperty(par_ID, "category")
		local categoryTV
		if (categoryID)
			categoryTV := _getCategoryProperty(categoryID, "tv")
		else
			categoryTV := _getShared("uncategorizedCategoryTV")
		TV_Modify(categoryTV, "expand")

		; Select the flow
		TV_Modify(_getFlowProperty(par_ID, "tv"))
	}
	else if (par_Type = "category")
	{
		; A category should be selected
		; Select the category
		local categoryTV
		if (par_ID)
			categoryTV := _getCategoryProperty(par_ID, "tv")
		else
			categoryTV := _getShared("uncategorizedCategoryTV")
		TV_Modify(categoryTV)

		; If the category should be expanded, do it
		IfInString,options, expand
			TV_Modify(categoryTV, "expand") ;Expand the category
			
	}
}

; Rename a tree view item
TreeView_manager_Rename(par_Type, par_ID)
{
	global

	if not (global_ManagerGUIHWND)
		return
	
	Gui, manager:default

	; Select the tree view item
	TreeView_manager_Select(par_Type, par_ID)
	; Send F2 in order to start editing the name. TODO: Don't use a hotkey for this. There must be a better way
	controlsend, , {F2},ahk_id %TreeView_manager_HWND%
}


; react on gui events on the treeview
; triggered by the TreeView control
TreeView_manager()
{
	global

	gui,manager:default

	; get information about the selected item
	local tempselectedTV := TV_GetSelection()
	local tempselectedID := global_allTreeViewItems[tempselectedTV].id
	local tempselectedType := global_allTreeViewItems[tempselectedTV].type
	
	if (A_GuiEvent = "e") ;If user has renamed an entry
	{
		; get the new name of the renamed entry
		local tempNewName
		TV_GetText(tempNewName, tempselectedTV)
		
		if (tempselectedType = "category") ;If the item is a category
		{
			; Get the old name and compare it with the new name
			tempOldName := _getCategoryProperty(tempselectedID, "name")
			if !(tempOldName == tempNewName) ;If the name has changed
			{
				;Do not rename demonstration category
				if (tempselectedID = "demo" and tempNewName != lang("Demonstration"))
				{
					soundplay,*16
					MsgBox, 16, % lang("Rename category"), % lang("The demonstration category cannot be renamed.")
					TV_Modify(tempselectedTV, "", lang("Demonstration"))
					return
				}
				;Do not rename if user has entered an empty name
				if (tempNewName = "")
				{
					; Silently restore the old name
					TV_Modify(tempselectedTV, "", tempOldName)
					return
				}
				;Do not rename if another category with same name already exists
				if (_getCategoryIdByName(tempNewName) != "")
				{
					soundplay,*16
					MsgBox, 16, % lang("Rename category"), % lang("A category with name '%1%' already exists.", tempNewName)
					TV_Modify(tempselectedTV, "", tempOldName)
					return
				}

				; If user renamed the uncategorized category, we have to create a new category and delete the uncategorized category
				local oldSelectedID
				if (tempselectedID = "uncategorized")
				{
					oldSelectedID := ""

					;create new category
					tempselectedID:=NewCategory(tempNewName)
				}
				else
				{
					oldSelectedID := tempselectedID

					;rename the category
					_setCategoryProperty(tempselectedID, "name", tempNewName)
				}

				
				; move all flows inside the old category to the new category
				local tempflowId, tempflowIndex
				for tempflowIndex, tempflowId in _getAllFlowIds()
				{
					if (_getFlowProperty(tempflowId, "category") = oldSelectedID)
					{
						ChangeFlowCategory(tempflowid, tempselectedID)
						SaveFlowMetaData(tempflowid)
					}
				}
				
				; We don't need to update the treeview, since the renamed flow is alredy shown
			}
		}
		else if (tempselectedType = "flow") ;If the item is a flow
		{
			tempOldName := _getFlowProperty(tempselectedID, "name")
			if !(tempOldName == tempNewName) ;If the name has changed
			{
				;Do not rename if user has entered an empty name
				if (tempNewName = "")
				{
					; Silently restore the old name
					TV_Modify(tempselectedTV, "", tempOldName)
					return
				}
				;Do not rename if there are prohibited characters.
				;reason: Flow names can be shown and selected in a listbox. When getting multiple flow names from the listbox, they are separated by |
				if (instr(tempNewName,"|"))
				{
					soundplay,*16
					MsgBox, 16, % lang("Rename flow"), % lang("Following characters are prohibited in a flow name: '%1%'", "|")
					;just remove that character
					StringReplace, tempNewName, tempNewName, |,%a_space%, all
					TV_Modify(tempselectedTV, "", tempNewName)
				}
				;Do not rename if there another flow with same name already exists
				if (_getFlowIdByName(tempNewName) != "")
				{
					soundplay,*16
					MsgBox, 16, % lang("Rename flow"), % lang("A flow with name '%1%' already exists.", tempNewName)
					TV_Modify(tempselectedTV, "", tempOldName)
					return
				}
				
				;rename
				_setFlowProperty(tempselectedID, "name", tempNewName)
				SaveFlowMetaData(tempSelectedID)
				
				;TODO notify editor that the name changed
			
			}
			
			
		}
	}


	if (A_GuiEvent ="s") ;If user has selected an item.
	{
		; Enable or disable some buttons depending on which item was selected
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
		
		; Update some button labels
		if (_getFlowProperty(tempselectedID, "enabled") = true)
			guicontrol,,Button_manager_EnableFlow,% lang("Disable")
		else
			guicontrol,,Button_manager_EnableFlow,% lang("Enable")
		if (_getFlowProperty(tempselectedID, "running") = true)
			guicontrol,,Button_manager_RunFlow,% lang("Stop #verb")
		else
			guicontrol,,Button_manager_RunFlow,% lang("Run #verb")
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
	tempselectedID := global_allTreeViewItems[tempselectedTV].id
	tempselectedType := global_allTreeViewItems[tempselectedTV].type
	
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

; When user selects the menu item "delete"
manager_menu_delete()
{
	;Same as if user has pressed the button
	Button_manager_Delete()
}
; When user selects the menu item "duplicate"
manager_menu_duplicate()
{
	;Same as if user has pressed the button
	Button_manager_DuplicateFlow()
}
; When user selects the menu item "rename"
manager_menu_rename()
{
	global
	; Send F2 in order to start editing the name. TODO: Don't use a hotkey for this. There must be a better way
	controlsend,, {f2},ahk_id %TreeView_manager_HWND%
}
; When user selects the menu item "new flow"
manager_menu_newFlow()
{
	;Same as if user has pressed the button
	Button_manager_NewFlow()
}
; When user selects the menu item "change category"
manager_menu_changeCategory()
{
	;Same as if user has pressed the button
	Button_manager_ChangeCategory()
}


; react on key input
keyPressed(wpar, lpar, msg, hwn)
{
	global
	if (hwn != TreeView_manager_HWND)
	{
		; react only if user interacted with the tree view
		return
	}

	; wpar defines the hotkey
	if (wpar = GetKeyVK("F5")) ; F5
	{
		SetTimer, KeyReload, -1
	}
	if (wpar = GetKeyVK("DEL")) ; DEL
	{
		SetTimer, Button_manager_Delete, -1
	}
}

; When user presses F5 to reload the treeview
KeyReload()
{
	global 

	gui,manager:default

	;Find out what is selected in order to reselect it later
	local tempselectedTV := TV_GetSelection()
	local tempselectedID := global_allTreeViewItems[tempselectedTV].id
	local tempselectedType := global_allTreeViewItems[tempselectedTV].type
	
	; refill the tree view
	TreeView_manager_Refill()

	; reselect the previously selected item
	TreeView_manager_Select(tempselectedType, tempselectedID)
}

; When user clicks on the button "new category"
Button_manager_NewCategory(par_Type, par_ID)
{
	global

	gui,manager:default
	
	;create new category
	local newCategoryID := NewCategory()
	; insert it in the treeview (todo: add without full refill)
	TreeView_manager_Refill()
	; start renaming the new category
	TreeView_manager_Rename("category", newCategoryID)
}

; When user clicks on the button "new flow"
Button_manager_NewFlow()
{
	global
	gui,manager:default
	
	; get the selected element tv id.
	local tempSelectedTV := TV_GetSelection()
	local NewFlowID
	local tempSelectedID
	if (tempSelectedTV != 0) ;If an element is selected
	{
		;Create new flow in the category of selected element
		local tempSelectedID := global_allTreeViewItems[tempSelectedTV].id
		
		if (global_allTreeViewItems[tempSelectedTV].type = "Category")
		{
			; a category is selected. Insert the new flow in this category
			if (tempSelectedID = "uncategorized" or tempSelectedID = "demo")
				NewFlowID := NewFlow() ; do not pass the "uncategorized" category. It means, that the flow does not have a category
			else
				NewFlowID := NewFlow(tempSelectedID)
		}
		else if (global_allTreeViewItems[tempSelectedTV].type = "Flow")
		{
			; a flow is selected. Insert the new flow in its category
			tempSelectedID := global_allTreeViewItems[TV_GetParent(tempSelectedTV)].id
			if (tempSelectedID = "uncategorized")
				NewFlowID := NewFlow() ; do not pass the "uncategorized" category. It means, that the flow does not have a category
			else
				NewFlowID := NewFlow(tempSelectedID)
		}
		else
		{
			MsgBox,,Unexpected error, The type of selected element could not be resolved! (95698769890)
			return
		}
		
	}
	else ;If nothing is selected
	{
		;Create a flow in category "uncategorized"
		NewFlowID := NewFlow()
	}
	; initialize the new flow
	initNewFlow(NewFlowID)
	
	; create a new state
	state_New(NewFlowID)
	_setFlowProperty(NewFlowID, "savedState", _getFlowProperty(NewFlowID, "currentState"))

	; save newly created flow 
	SaveFlowMetaData(NewFlowID)
	
	; insert the flow in the tree view (todo: do it without a full refill)
	TreeView_manager_Refill()

	; start renaming the new flow
	TreeView_manager_Rename("flow", NewFlowID)
}

; When user clicks on the button "change category"
Button_manager_ChangeCategory()
{
	global

	gui,manager:default

	; get the selected tv item
	local tempSelectedTV := TV_GetSelection()

	if (global_allTreeViewItems[tempselectedTV].type = "flow") ;this can only be performed on flows
	{
		; change the category of the selected flow
		changeFlowCategory_GUI(global_allTreeViewItems[tempselectedTV].id)
	}
	else
	{
		; this cannot not happen, because the button "duplicate" is disabled when a category is selected
	}
}

; When user clicks on the button "duplicate flow"
Button_manager_DuplicateFlow()
{
	global

	gui,manager:default
	
	; get information of the selected tv item
	local tempselectedTV := TV_GetSelection()
	local tempselectedID := global_allTreeViewItems[tempselectedTV].id
	local tempselectedType := global_allTreeViewItems[tempselectedTV].type
	
	if (tempselectedType = "flow") ;this can only be performed on flows
	{
		; duplicate the flow
		local tempNewFlowID := DuplicateFlow(tempselectedID)

		; insert the flow in the tree view (todo: do it without a full refill)
		TreeView_manager_Refill()

		; select the new flow
		TreeView_manager_Rename("Flow", tempNewFlowID)
	}
	else
	{
		; this cannot not happen, because the button "duplicate" is disabled when a category is selected
	}
}

; When user clicks on the button "import and export"
Button_manager_Import_Export()
{
	; open the import and export gui
	import_and_export_gui()
}

; when user clicks help button
Button_manager_Help()
{
	;open the help window
	ui_showHelp()
}

; when user clicks on button "edit flow"
Button_manager_EditFlow()
{
	global
	;open flow editor
	editFlow(global_allTreeViewItems[TV_GetSelection()].id)
}

; when user clicks on button "run flow"
Button_manager_RunFlow()
{
	global
	; start or stop flow
	ExecuteToggleFlow(global_allTreeViewItems[TV_GetSelection()].id)
}

; when user clicks on button "enable flow"
Button_manager_EnableFlow()
{
	global
	; enable or disable flow
	EnabletoggleFlow(global_allTreeViewItems[TV_GetSelection()].id)
}

; when user clicks on button "delete"
Button_manager_Delete()
{
	global

	gui,manager:default

	; get information about the selected item
	local tempselectedTV := TV_GetSelection()
	local tempselectedID := global_allTreeViewItems[tempselectedTV].id
	local tempselectedType := global_allTreeViewItems[tempselectedTV].type
	
	if (tempselectedType = "flow") ;if a flow should be deleted
	{
		; disable the gui in ordner to prevent errors if user interacts with the gui
		Disable_Manager_GUI()
		
		if (_getFlowProperty(tempselectedID, "category") = "demo") ;Check whether this is a demo flow
		{
			; The demo flows are shipped with AutoHotkey and they cannot be deleted. But user may want to hide them
			MsgBox, 52, AutoHotFlow, % lang("You cannot delete the demonstration flows, but you can hide all of them.") "`n" lang("Do you want to do that now?")
			IfMsgBox yes
			{
				; Save the new setting, this will cause that the demo flows will be hidden
				_setSettings("HideDemoFlows", true)
				write_settings()

				; rebuild the treeview
				TreeView_manager_Refill()
			}
		}
		else
		{
			;ask user for confirmation
			MsgBox, 4, % lang("Confirm_deletion"),% lang("Do you really want to delete the flow '%1%'?", _getFlowProperty(tempselectedID, "name"))
			IfMsgBox,Yes
			{
				; Get the category in order to select it after treeview refill
				local tempCategory := _getFlowProperty(tempselectedID, "category")

				;delete the flow
				DeleteFlow(tempselectedID)

				; Refill the tree view and select the parent category
				TreeView_manager_Refill()
				TreeView_manager_Select("Category", tempCategory, "expand")
				
			}
		}
		
	}
	else if (tempselectedType = "category") ;if a category should be deleted
	{
		Disable_Manager_GUI()
		if (tempselectedID = "uncategorized") ;Do not remove the uncategorized category, since there are flows
		{
			soundplay,*16
			MsgBox, 16, % lang("Delete category"), % lang("This_category_can_not_be_removed")
		}
		else if (tempselectedID = "demo")
		{
			; The demo flows are shipped with AutoHotkey and they cannot be deleted. But user may want to hide them
			MsgBox, 52, AutoHotFlow, % lang("You cannot delete the demonstration category, but you can hide all demonstration flows.") "`n" lang("Do you want to do that now?")
			IfMsgBox yes
			{
				; Save the new setting, this will cause that the demo flows will be hidden
				_setSettings("HideDemoFlows", true)
				write_settings()

				; rebuild the treeview
				TreeView_manager_Refill()
			}
		}
		else
		{
			;Check, whether the category has flows
			local temphasFlows := false
			local oneFlowIndex, oneFlowID
			for oneFlowIndex, oneFlowID in _getAllFlowIds()
			{
				if (_getFlowProperty(oneFlowID, "category") = tempselectedID)
				{
					temphasFlows := true
					break
				}
			}
			
			if (temphasFlows = true) ;If there are flows inside the category
			{
				;ask user for confirmation
				local tempCategoryName := _getCategoryProperty(tempselectedID, "name")
				MsgBox, 4, % lang("Confirm_deletion"), % lang("Do you really want to delete the category '%1%'?", tempCategoryName) "`n" lang("All flows of that category will be moved into the category '%1%'.", lang("Uncategorized"))
				
				IfMsgBox, Yes ; if user approved
				{
					 ;Move all flows that were inside the category to uncategorized
					local tempFlowIndex, tempFlowID
					for tempFlowIndex, tempFlowID in _getAllFlowIds()
					{
						if (_getFlowProperty(tempFlowID, "category") = tempselectedID)
						{
							ChangeFlowCategory(tempFlowID,"")
							SaveFlowMetaData(tempflowid)
						}
					}
					
					; Delete the category
					DeleteCategory(tempselectedID)

					; rebuild the tree view
					TreeView_manager_Refill()

					; Select the uncategorized category
					TreeView_manager_Select("Category", "", "expand")
				}
			}
			else
			{
				; The category has no flows and can be removed without confirmation
				DeleteCategory(tempselectedID)
				
				; rebuild the tree view
				TreeView_manager_Refill()
			}
			
		}
	}

	Enable_Manager_GUI()
}

; when user clicks on button "settings"
Button_manager_Settings()
{
	; open settings gui
	globalSettings_GUI()
}

; when user clicks on button "about"
Button_manager_About()
{
	; open about gui
	init_about_gui()
}

; when user clicks on button "show log"
Button_manager_ShowLog()
{
	; show the log gui
	showlog()
}

; when user clicks on button "exit"
Button_manager_Exit()
{
	; exit AHF
	API_Main_Exit()
}


