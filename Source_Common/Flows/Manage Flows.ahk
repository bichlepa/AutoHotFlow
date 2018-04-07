
global global_CategoryIDCounter = 1

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
	_share.FlowsTreeViewNeedFullRefresh:=True
	_share.FindFlows_Called:=True
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
	
	EnterCriticalSection(_cs.flows)
	
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
	
	if _flows.haskey(tempflowID)
	{
		Loop
		{
			random,randomValue
			tempflowID := lang("Flow") " " randomValue
			if (not _flows.haskey(tempflowID))
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
	_flows[newFlowid] := object()
	
	_flows[newFlowID].file := FileFullPath
	_flows[newFlowID].Folder := ThisFlowFolder
	_flows[newFlowID].FileName := ThisFlowFilename
	
	_flows[newFlowid].id := newFlowid
	_flows[newFlowid].FlowID := newFlowid
	_flows[newFlowid].name := tempflowName
	;~ _flows[newFlowid].defaultname := true
	_flows[newFlowid].Type := "Flow"
	_flows[newFlowid].category := tempCategoryID
	_flows[newFlowid].demo := tempdemo
	UpdateFlowCategoryName(newFlowid)
	
	;~ d(_flows[newFlowid])
	if (_share.FindFlows_Called)
	{
		_share.managerTasks.refillTree:=true
		_share.managerTasks.select:="Flow:" newFlowid
	}
	
	_flows[newFlowID].draw := CriticalObject()
	
	if (tempflowenabled != 0) ;Enable flow
	{
		loop, parse,tempflowenabled,|
		{
			enableOneTrigger(newFlowID, A_LoopField, False)
		}
	}
	
	LeaveCriticalSection(_cs.flows)
}

;Create a new file for a flow
NewFlow(par_CategoryID = "")
{
	global
	local newFlowid
	local tempCategoryID
	
	EnterCriticalSection(_cs.flows)
	
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
		if (not _flows.haskey(newFlowid))
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
	_flows[newFlowid] := object()
	_flows[newFlowid].id := newFlowid
	_flows[newFlowid].name := tempflowName
	_flows[newFlowid].Type := "Flow"
	_flows[newFlowid].category := tempCategoryID
	_flows[newFlowid].enabled := false
	UpdateFlowCategoryName(newFlowid)
	
	;Create a new file but do not overwrite existing file. Change file name if necessary.
	NewName := _flows[newFlowid].Name 
	_flows[newFlowid].folder := _WorkingDir "\Saved Flows"
	_flows[newFlowid].filename := newFlowid
	_flows[newFlowid].file := _WorkingDir "\Saved Flows\" newFlowid ".ini"
	

	SaveFlowMetaData(newFlowid)


	;Add TV entry
	if (_share.FindFlows_Called)
	{
		_share.managerTasks.refillTree:=true
		_share.managerTasks.select:="Flow:" newFlowid
	}

	LeaveCriticalSection(_cs.flows)
	
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
	
	EnterCriticalSection(_cs.flows)
	
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
				LeaveCriticalSection(_cs.flows)
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
	if (_share.FindFlows_Called)
	{
		_share.managerTasks.refillTree:=true
		_share.managerTasks.select:="Flow:" newFlowid
	}
	;~ d(allCategories)
	
	LeaveCriticalSection(_cs.flows)
	
	return newCategoryid
}

ChangeFlowCategory(par_FlowID, par_CategoryID)
{
	global
	
	EnterCriticalSection(_cs.flows)
	
	if (par_FlowID = "")
	{
		MsgBox,,Unexpected error, 5616486132156
	}
	
	_flows[par_FlowID].category := par_CategoryID
	UpdateFlowCategoryName(par_FlowID)
	SaveFlowMetaData(par_FlowID)
	
	if (_share.FindFlows_Called)
	{
		_share.managerTasks.refillTree:=true
		_share.managerTasks.select:="Flow:" newFlowid
	}
	
	LeaveCriticalSection(_cs.flows)
}

UpdateFlowCategoryName(par_FlowID)
{
	EnterCriticalSection(_cs.flows)
	_flows[par_FlowID].categoryName := _share.allCategories[_flows[par_FlowID].category].name
	LeaveCriticalSection(_cs.flows)
}


DeleteFlow(par_ID)
{
	global
	;TODO: Close editor and stop flow execution
	
	EnterCriticalSection(_cs.flows)
	
	FileDelete,% _flows[par_ID].file
	
	parentcategory:=_flows[par_ID].category
	
	_flows.delete(par_ID)
	
	;Refresh treeview
	if (_share.FindFlows_Called)
	{
		_share.managerTasks.refillTree:=true
		_share.managerTasks.select:="Category:" parentcategory ":expand"
	}
	
	LeaveCriticalSection(_cs.flows)
}

DuplicateFlow(par_ID)
{
	global
	local newFlowid
	
	EnterCriticalSection(_cs.flows)
	
	;Create the flow in the global variable
	;~ d(NewName " - " tempcategoryid " - " Categoryname)
	Loop
	{
		random,randomValue
		newFlowid := lang("New flow") " " randomValue
		if (not _flows.haskey(newFlowid))
			break
	}
	
	;copy and change some metadata
	_flows[newFlowid] := objfullyclone(_flows[par_ID])
	_flows[newFlowid].id := newFlowid
	_flows[newFlowid].name .= " " lang("copy")
	_flows[newFlowid].enabled := false
	_flows[newFlowid].demo := false ;If user copies a demo flow, the copy is not a demo flow anymore and user can edit it
	
	;Do not allow two flows to have the same name. If a loaded flow has a name that an other flow already has, the flow will be renamed
	tempflowName:=_flows[newFlowid].name
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
	_flows[newFlowid].name:=tempflowName
	
	;Create a new file
	_flows[newFlowid].folder := _WorkingDir "\Saved Flows"
	_flows[newFlowid].filename := newFlowid
	_flows[newFlowid].file := _WorkingDir "\Saved Flows\" newFlowid ".ini"
	filecopy,% _flows[par_ID].file, % _flows[newFlowid].file
	
	SaveFlowMetaData(newFlowid)

	;Add TV entry
	if (_share.FindFlows_Called)
	{
		_share.managerTasks.refillTree:=true
		_share.managerTasks.select:="Flow:" newFlowid
	}

	LeaveCriticalSection(_cs.flows)
}

DeleteCategory(par_ID)
{
	global
	
	EnterCriticalSection(_cs.flows)
	
	_share.allCategories.delete(par_ID)
	
	;Upadte TV entries
	if (_share.FindFlows_Called)
	{
		_share.managerTasks.refillTree:=true
		_share.managerTasks.select:="Flow:" newFlowid
	}
	
	LeaveCriticalSection(_cs.flows)
}


FlowIDbyName(par_name,Type="") ;Returns the id by name
{
	EnterCriticalSection(_cs.flows)
	
	if ((type = "flow") or (type = ""))
	{
		for count, tempitem in _flows
		{
			if (tempitem.name = par_name)
			{
				;~ MsgBox % tempitem.id " - " tempitem.name
				retval:= tempitem.id
				break
			}
			
		}
	}
	else if ((type = "category") or (type = ""))
	{
		for count, tempitem in _share.allCategories
		{
			if (tempitem.name = par_name)
			{
				retval:= tempitem.id
				break
			}
			
		}
	}
	
	LeaveCriticalSection(_cs.flows)
	
	return retval
}
