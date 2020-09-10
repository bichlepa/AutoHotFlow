

;Find flows in folder "saved Flows" und show them in the tv.
;Additionally read the state of flow and activate it if it should be active
;This function must be called once
FindFlows()
{
	global
	if not fileexist(_WorkingDir "\Saved Flows")
		FileCreateDir,%_WorkingDir%\Saved Flows
	
	;Load existing Flows
	loop %_WorkingDir%\Saved Flows\*.ini
	{
		InitFlow(A_LoopFileFullPath)
	}
	_setShared("FindFlows_Called",True)
	API_manager_TreeView_Refill()
}

InitFlow(FileFullPath)
{
	global
	local tempflowName
	local tempcategoryname
	local tempCategoryID
	local tempflowenabled
	local tempflowid
	local tempdemo
	local newFlowID
	
	SplitPath, FileFullPath,,ThisFlowFolder,,ThisFlowFilename

	;Read information about flow 
	iniread, tempflowName, %FileFullPath%, general, name
	
	;Load Flow ID. If no id saved, set filename as flow ID (backward compatibility)
	iniread, tempflowID, %FileFullPath%, general, id, %ThisFlowFilename%
	;~ MsgBox %A_LoopFileFullPath% %tempflowName%
	
	;read flow information
	iniread, tempcategoryname, %FileFullPath%, general, category, %a_space% 
	iniread, tempflowenabled, %FileFullPath%, general, enabled, 0
	iniread, tempdemo, %FileFullPath%, general, demo, 0
	
	;MsgBox %FileFullPath% - %tempflowcategory%
	
	;Check category. Create new one if it does not exist yet. Demo flows don't need a dedicated category
	if (not tempdemo)
	{
		if (tempcategoryname != "")
			tempCategoryID := NewCategory(tempcategoryname)
	}

	;Make sure the flow ID does not exist yet. If it exists, generate a new one
	
	if _existsFlow(tempflowID)
	{
		Loop
		{
			random,randomValue
			tempflowID := lang("Flow") " " randomValue
			if (not _existsFlow(tempflowID))
				break
		}
	}

	;Do not allow two flows to have the same name. If a loaded flow has a name that an other flow already has, the flow will be renamed
	Loop
	{
		if (FlowIDbyName(tempflowName, "flow"))
		{
			StringGetPos,posspace,tempflowName,%a_space%,R
			tempFlowNumberInName:=substr(tempFlowName,posspace+2)
			if tempFlowNumberInName is number
				tempflowName:=substr(tempFlowName,1,posspace) " " tempFlowNumberInName+1
			else
				tempflowName:=tempFlowName " " 2
		}
		else
			break
	}
	
	;Add flow to the list
	newFlowid:=tempflowID
	newFlow := Object()
	
	newFlow.file := FileFullPath
	newFlow.Folder := ThisFlowFolder
	newFlow.FileName := ThisFlowFilename
	
	newFlow.id := newFlowid
	newFlow.FlowID := newFlowid
	newFlow.name := tempflowName
	;~ newFlow.defaultname := true
	newFlow.Type := "Flow"
	newFlow.category := tempCategoryID
	newFlow.demo := tempdemo
	
	;~ d(newFlow)
	
	newFlow.draw := Object()
	newFlow.states := Object()
	
	_setFlow(newFlowid, newFlow)

	UpdateFlowCategoryName(newFlowid)

	if (tempflowenabled != 0) ;Enable flow
	{
		loop, parse,tempflowenabled,|
		{
			enableOneTrigger(newFlowID, A_LoopField, False)
		}
	}

	if (_getShared("FindFlows_Called"))
	{
		API_manager_TreeView_Refill()
		API_manager_TreeView_Select("Flow", newFlowid)
	}
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
		tempCategoryID := ""
	}
	else if (par_CategoryID = "uncategorized")
	{
		tempCategoryID := ""
	}
	else
	{
		tempCategoryID := par_CategoryID
	}
	
	;Generate a new unique ID
	Loop
	{
		random,randomValue
		newFlowid := lang("Flow") " " randomValue
		if (not _existsFlow(newFlowid))
			break
	}
	;Generate a new unique flow name
	randomValue:=1
	Loop
	{
		tempflowName := lang("New flow") " " randomValue
		if (not FlowIDbyName(tempflowName, "flow"))
			break
		randomValue+=1
	}
	;Create the flow in the global variable
	newFlow := object()
	newFlow.id := newFlowid
	newFlow.name := tempflowName
	newFlow.Type := "Flow"
	newFlow.category := tempCategoryID
	newFlow.enabled := false
	
	;Create a new file but do not overwrite existing file. Change file name if necessary.
	NewName := newFlow.Name 
	newFlow.folder := _WorkingDir "\Saved Flows"
	newFlow.filename := newFlowid
	newFlow.file := _WorkingDir "\Saved Flows\" newFlowid ".ini"
	newFlow.states := Object()
	
	_setFlow(newFlowid, newFlow)

	UpdateFlowCategoryName(newFlowid)
	SaveFlowMetaData(newFlowid)


	;Add TV entry
	if (_getShared("FindFlows_Called"))
	{
		API_manager_TreeView_Refill()
		API_manager_TreeView_Select("Flow", newFlowid)
	}
	
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
	local retval
	
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
			for tempcount, tempCategoryID in _getAllCategoryIds()
			{
				;~ d( tempitem,Newname)
				if (_getCategoryProperty(tempCategoryID, "name") = tempNewname)
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
		for tempcount, tempCategoryID in _getAllCategoryIds()
		{
			if (_getCategoryProperty(tempCategoryID, "name") = Newname)
			{
				;If it already exists, return the id
				retval:= tempCategoryID
				break
			}
			;MsgBox,%tempcategoryexist% 
		}
	}
	if not retval
	{
		;Add the category to the list
		newCategoryid := "category" _getAndIncrementShared("CategoryIDCounter")
		newCategory := object()
		newCategory.id := newCategoryid
		newCategory.Name := Newname
		newCategory.Type := "Category"
		_setCategory(newCategoryid, newCategory)

		if (_getShared("FindFlows_Called"))
		{
			API_manager_TreeView_Refill()
			API_manager_TreeView_Select("Flow", newFlowid)
		}
		;~ d(allCategories)
	}
	
	return newCategoryid
}

ChangeFlowCategory(par_FlowID, par_CategoryID)
{
	global
	
	if (par_FlowID = "")
	{
		MsgBox,,Unexpected error, 5616486132156
	}
	
	_setFlowProperty(par_FlowID, "category", par_CategoryID)
	UpdateFlowCategoryName(par_FlowID)
	SaveFlowMetaData(par_FlowID)
	
	if (_getShared("FindFlows_Called"))
	{
		API_manager_TreeView_Refill()
		API_manager_TreeView_Select("Flow", newFlowid)
	}
}

UpdateFlowCategoryName(par_FlowID)
{
	categoryID := _getFlowProperty(par_FlowID, "category")
	categoryName := _getCategoryProperty(par_FlowID, "name")

	_setFlowProperty(par_FlowID, "categoryName",categoryName)
}


DeleteFlow(par_ID)
{
	global
	;TODO: Close editor and stop flow execution
	
	
	FileDelete,% _getFlowProperty(par_ID, "file")
	
	;parentcategory:=_flows[par_ID].category
	
	_deleteFlow(par_ID)
	
	;Refresh treeview
	if (_getShared("FindFlows_Called"))
	{
		API_manager_TreeView_Refill()
		API_manager_TreeView_Select("Flow", newFlowid)
	}
	
}

DuplicateFlow(par_ID)
{
	global
	local newFlowid

	
	;Create the flow in the global variable
	;~ d(NewName " - " tempcategoryid " - " Categoryname)
	Loop
	{
		random,randomValue
		newFlowid := lang("Flow") " " randomValue
		if (not  _existsFlow(newFlowid))
			break
	}
	
	;copy and change some metadata
	newFlow := _getFlow(par_ID)
	newFlow.id := newFlowid
	newFlow.name .= " " lang("copy")
	newFlow.enabled := false
	newFlow.demo := false ;If user copies a demo flow, the copy is not a demo flow anymore and user can edit it
	
	;Do not allow two flows to have the same name. If a loaded flow has a name that an other flow already has, the flow will be renamed
	tempflowName:=newFlow.name
	Loop
	{
		if (FlowIDbyName(tempflowName, "flow"))
		{
			StringGetPos,posspace,tempflowName,%a_space%,R
			tempFlowNumberInName:=substr(tempFlowName,posspace+2)
			if tempFlowNumberInName is number
				tempflowName:=substr(tempFlowName,1,posspace) " " tempFlowNumberInName+1
			else
				tempflowName:=tempFlowName " " 2
		}
		else
			break
	}
	newFlow.name:=tempflowName
	
	;Create a new file
	oldFile:=newFlow.file
	newFlow.folder := _WorkingDir "\Saved Flows"
	newFlow.filename := newFlowid
	newFlow.file := _WorkingDir "\Saved Flows\" newFlowid ".ini"

	_setFlow(newFlowid, newFlow)

	filecopy,% oldFile, % newFlow.file
	
	SaveFlowMetaData(newFlowid)

	;Add TV entry
	if (_getShared("FindFlows_Called"))
	{
		API_manager_TreeView_Refill()
		API_manager_TreeView_Select("Flow", newFlowid)
	}

}

DeleteCategory(par_ID)
{
	global
	
	
	_deleteCategory(par_ID)
	
	;Upadte TV entries
	if (_getShared("FindFlows_Called"))
	{
		API_manager_TreeView_Refill()
		API_manager_TreeView_Select("Flow", newFlowid)
	}
	
}


FlowIDbyName(par_name,Type="") ;Returns the id by name
{
	if ((type = "flow") or (type = ""))
	{
		retval := _getFlowIdByName(par_name)
	}
	if (not retval and (type = "category") or (type = ""))
	{
		retval := _getCategoryIdByName(par_name)
	}
	
	return retval
}
