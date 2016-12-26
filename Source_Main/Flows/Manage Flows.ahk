global_FlowIDCounter = 1
global_CategoryIDCounter = 1

;Find flows in folder "saved Flows" und show them in the tv.
;Additionally read the state of flow and activate it if it should be active
;This function must be called once
FindFlows() ;API
{
	global
	local filenameNoExt
	local FileFullPath
	local tempflowName
	local tempcategoryname
	local tempflowenabled
	local tempflowid
	local newFlowID
	
	if not fileexist(my_WorkingDir "\Saved Flows")
		FileCreateDir,%my_WorkingDir%\Saved Flows
	
	;Load existing Flows
	loop %my_WorkingDir%\Saved Flows\*.ini
	{
		SplitPath, A_LoopFileFullPath,,ThisFlowFolder,,ThisFlowFilename
	
		;Compare file name and flow name 
		StringTrimRight, filenameNoExt, A_LoopFileName ,4
		iniread, tempflowName, %A_LoopFileFullPath%, general, name
		;~ MsgBox %A_LoopFileFullPath% %tempflowName%
		;~ if (filenameNoExt!=tempflowName) ;renaming flow ini files is risky. Instead a feature flow export should be implemented
		;~ {
			
			
			;~ ;MsgBox %tempflowName%
			;~ FileMove,Saved Flows\%filenameNoExt%.ini,Saved Flows\%tempflowName%.ini
			;~ if not errorlevel
			;~ {
				;~ ;MsgBox  Saved Flows\%filenameNoExt%.ini - Saved Flows\%tempflowName%.ini
				;~ FileFullPath=Saved Flows\%tempflowName%.ini
			;~ }
			;~ else
				;~ FileFullPath:=A_LoopFileFullPath
		;~ }
		;~ else
			FileFullPath := A_LoopFileFullPath
		
		
		
		
		;read flow information
		iniread, tempcategoryname, %FileFullPath%, general, category, %a_space% 
		iniread, tempflowenabled, %FileFullPath%, general, enabled, false
		
		;MsgBox %FileFullPath% - %tempflowcategory%
		
		;Check category. Create new one if it does not exist yet
		if (tempcategoryname != "")
			tempCategoryID := NewCategory(tempcategoryname)
		else
			tempCategoryID := NewCategory(lang("Uncategorized"))

		
		;Add flow to the list
		newFlowID := "flow" global_FlowIDCounter++
		_flows[newFlowid] := object()
		
		_flows[newFlowID].file := FileFullPath
		_flows[newFlowID].Folder := ThisFlowFolder
		_flows[newFlowID].FileName := ThisFlowFilename
		
		_flows[newFlowid].id := newFlowid
		_flows[newFlowid].name := tempflowName
		;~ _flows[newFlowid].defaultname := true
		_flows[newFlowid].Type := "Flow"
		_flows[newFlowid].category := tempCategoryID
		UpdateFlowCategoryName(newFlowid)
		
		if (tempflowenabled = "true")
			_flows[newFlowid].enabled := true
		else
			_flows[newFlowid].enabled := false
		;~ d(_flows[newFlowid])
		_flows[newFlowID].tv := API_manager_TreeView_AddEntry("Flow", newFlowid)
		
		_flows[newFlowID].draw := []
		
		
		;~ if (tempflowenabled = "true") ;Enable flow
		;~ {
			;~ ;TODO
			;~ ;Decide whether AutoHotFlow has been started after a reboot. This would start the trigger "Startup".
			;~ LastStartupTime := a_now
			;~ Envadd, LastStartupTime, % -(A_TickCount/1000), Seconds
			;~ ;FormatTime,LastStartupTime2,% LastStartupTime
			;~ ;FormatTime,LastExecutionTime2,% LastExecutionTime
			
			;~ EnvSub, LastStartupTime, % LastExecutionTime, Seconds
			;~ ;FormatTime,LastStartupTime3,LastStartupTime
			;~ ;MsgBox % LastStartupTime2 "`n" LastExecutionTime2 "`n" LastStartupTime3 "`n" LastStartupTime
			;~ if (LastStartupTime > 0)
				;~ enableFlow(tempflowid, "Startup")
			;~ else
			;~ {
				;~ enableFlow(tempflowid)
			;~ }
			
		;~ }
	}
	;~ d(_flows)
}

;Create a new file for a flow
NewFlow(par_CategoryID = "")
{
	global
	local newFlowid
	local tempCategoryID
	
	;If category ID not given, move to Category "Uncategorized"

	if (par_CategoryID = "")
	{
		tempCategoryID := NewCategory(lang("Uncategorized"))
	}
	else
	{
		tempCategoryID := par_CategoryID
	}
	
	;Create the flow in the global variable
	;~ d(NewName " - " tempcategoryid " - " Categoryname)
	newFlowid := "flow" global_FlowIDCounter++
	_flows[newFlowid] := object()
	_flows[newFlowid].id := newFlowid
	_flows[newFlowid].name := lang("New flow")
	_flows[newFlowid].Type := "Flow"
	_flows[newFlowid].category := tempCategoryID
	_flows[newFlowid].enabled := false
	UpdateFlowCategoryName(newFlowid)
	
	;Create a new file but do not overwrite existing file. Change file name if necessary.
	NewName := _flows[newFlowid].Name 
	_flows[newFlowid].folder := my_WorkingDir "\Saved Flows"
	_flows[newFlowid].filename := NewName
	_flows[newFlowid].file := my_WorkingDir "\Saved Flows\" NewName ".ini"
	
	Loop 
	{
		if FileExist(_flows[newFlowid].file)
		{
			_flows[newFlowid].folder := my_WorkingDir "\Saved Flows"
			_flows[newFlowid].filename := NewName a_index
			_flows[newFlowid].file := my_WorkingDir "\Saved Flows\" NewName a_index ".ini"
			_flows[newFlowid].Name := NewName " " a_index
		}
		else
		{
			SaveFlowMetaData(newFlowid)
			break
		}
		
	}
	
	;Add TV entry
	_flows[newFlowid].TV := API_manager_TreeView_AddEntry("Flow", newFlowid)

	return newFlowid
}


NewCategory(par_Newname = "")
{
	global
	local newCategoryid
	local tempfound
	local Newname
	local tempNewname
	local tempindex
	
	;~ d(par_Newname)
	if (par_Newname = "") ;If a new category should be created and the name is not given
	{
		Newname := lang("New category")
		tempNewname := Newname
		
		;Check wheter a category with this name is already given. If so, append an index
		;~ d(allCategories)
		Loop
		{
			tempfound := false
			tempindex := a_index
			for tempcount, tempitem in _share.allCategories
			{
				;~ d( tempitem,Newname)
				if (tempitem.name = tempNewname)
				{
					tempNewname := Newname " " tempindex
					tempfound := true
				}
				
			}
			if (tempfound = false)
			{
				Newname := tempNewname
				break
			}
		}
	}
	else ;If the name is given, check wheter a category exists
	{
		Newname := par_Newname
		for tempcount, tempitem in _share.allCategories
		{
			if (tempitem.name = Newname)
			{
				;If it already exists, return the id
				;~ d(tempitem)
				return tempitem.id
			}
			;MsgBox,%tempcategoryexist% 
		}
	}
	
	;Add the category to the list
	newCategoryid := "category" global_CategoryIDCounter++
	_share.allCategories[newCategoryid] := object()
	_share.allCategories[newCategoryid].id := newCategoryid
	_share.allCategories[newCategoryid].Name := Newname
	_share.allCategories[newCategoryid].Type = Category
	_share.allCategories[newCategoryid].TV := API_manager_TreeView_AddEntry("Category", newCategoryid)
	;~ d(allCategories)
	return newCategoryid
}

ChangeFlowCategory(par_FlowID, par_CategoryID)
{
	global
	
	if (par_FlowID = "" or par_CategoryID = "")
	{
		MsgBox,,Unexpected error, 5616486132156
	}
	
	_flows[par_FlowID].category := par_CategoryID
	UpdateFlowCategoryName(par_FlowID)
	SaveFlowMetaData(par_FlowID)
	;~ d(_flows, par_FlowID)
	;~ d(allCategories, par_CategoryID)
	API_manager_TreeView_ChangeFlowCategory(par_FlowID)
}

UpdateFlowCategoryName(par_FlowID)
{
	global
	_flows[par_FlowID].categoryName := _share.allCategories[_flows[par_FlowID].category].name
}

IDOfName(par_name,Type="") ;Returns the id by name
{
	global
	if ((type = "flow") or (type = ""))
	{
		for count, tempitem in _flows
		{
			if (tempitem.name = par_name)
			{
				return tempitem.id
			}
			
		}
	}
	else if ((type = "category") or (type = ""))
	{
		for count, tempitem in _share.allCategories
		{
			if (tempitem.name = par_name)
			{
				return tempitem.id
			}
			
		}
	}
	return 
}


DeleteFlow(par_ID)
{
	global
	;TODO: Close editor and stop flow execution
	
	FileDelete,% _flows[par_ID].file
	
	_flows.delete(par_ID)
}

DeleteCategory(par_ID)
{
	global
	_share.allCategories.delete(par_ID)
}