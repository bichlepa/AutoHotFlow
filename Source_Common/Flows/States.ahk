

global global_statesCounter:=0
global MAX_COUNT_OF_STATES:=100


state_New(p_FlowID, stateID="", params="")
{
	EnterCriticalSection(_cs_shared)
	
	UpdateConnectionLists(p_FlowID)
	
	;~ MsgBox new state %p_FlowID% 
	if (stateID = "")
	{
		states_DeleteNewerThanCurrent(p_FlowID)
		
		newState:=Object()
		newState.ID:="state" . format("{1:010u}",++global_statesCounter)
		_setFlowProperty(p_FlowID, "states." newState.id, newState)
		states_DeleteTooOld(p_FlowID)
	}
	else
	{
		newState:=Object()
		newState.ID:=stateID
		_setFlowProperty(p_FlowID, "states." newState.id, newState)
	}
	
	states_Update(p_FlowID, newState.ID)
	
	IfNotInString, params, NotAsCurrent
		_setFlowProperty(p_FlowID, "currentState", newState.ID)
	
	LeaveCriticalSection(_cs_shared)
}

state_Undo(p_FlowID)
{
	found:=false
	restored:=false
	
	EnterCriticalSection(_cs_shared)

	;~ MsgBox undo state %p_FlowID%  
	;Try to find an older state than the current and set it.
	currentState := _getFlowProperty(p_FlowID, "currentState")
	for state, stateId in _getAllFlowPropertyKeys(p_FlowID, "states")
	{
		;If this is the current state and a previous state was found
		if (stateid =  and found)
		{
			;Restore previous state
			restored := True
			states_Restore(p_FlowID, previousState)
			_setFlowProperty(p_FlowID, "currentState", previousState)
			break
		}
		;~ MsgBox % stateid " current: " _flows[p_FlowID].currentState
		found:=true
		previousState:=stateid
	}
	
	;Try to find a backup
	if (restored = False and _getFlowProperty(p_FlowID, "backupsLoaded") != True)
	{
		filename := _getFlowProperty(p_FlowID, "FileName")
		currentStateIsFromBackup:=false
		foundfilename:=""
		foundbackupdate:=""
		foundfilepath:=""
		foundBackups:=Object()
		;~ MsgBox %_WorkingDir%\saved Flows\backup\%filename%_backup_*.ini
		;~ loop, files, %_WorkingDir%\savedFlows\backup\%filename%_backup_*.ini
		currentStateDate := currentState
		StringReplace,currentStateDate,currentStateDate,Backup_
		if (errorlevel = 0)
		{
			currentStateIsFromBackup := True
		}
		loop, files, %_WorkingDir%\saved Flows\backup\%filename%_backup_*.ini
		{
			StringReplace,backupdate,a_loopfilename,%filename%_backup_
			StringTrimRight,backupdate,backupdate,4
			
			if (((currentStateIsFromBackup = True and currentStateDate > backupdate) or (currentStateIsFromBackup = False)) and (_getFlowProperty(FlowID, "firstLoadedTime") > backupdate))
			{
				;~ MsgBox %currentStateIsFromBackup% - %currentStateDate% - %backupdate%
				foundBackups.push({foundfilepath: A_LoopFileFullPath, foundfilename: A_LoopFileName, foundbackupdate: backupdate})
				
			}
		}
		
		if (foundBackups.MaxIndex() >0)
		{
			
			MsgBox, 36, % lang("Undo"), % lang("There are backups available. Do you want to load them?")
			IfMsgBox yes
			{
				SplashTextOn,300,80,,% lang("loading backups")
				for forindex, forbackupfile in foundBackups
				{
					LoadFlow(p_FlowID,forbackupfile.foundfilepath, "NoNewState|LoadAgain|keepDraw|keepPosition")
					if (foundBackups.MaxIndex() = forindex)
						state_New(p_FlowID, "Backup_" forbackupfile.foundbackupdate)
					else
						state_New(p_FlowID, "Backup_" forbackupfile.foundbackupdate, "NotAsCurrent")
				}
				_setFlowProperty(p_FlowID, "backupsLoaded", True)
				SplashTextOff
			}
		}
		
		
	}
	
	LeaveCriticalSection(_cs_shared)
}

state_Redo(p_FlowID)
{
	EnterCriticalSection(_cs_shared)
	
	currentState := _getFlowProperty(p_FlowID, "currentState")
	found:=false
	;~ MsgBox redo state %p_FlowID% 
	;Try to find a newer state than the current and set it. This is only possible after user has done a redo and did not changed anything yet.
	assignnext := false
	for stateIndex, stateID in _getAllFlowPropertyKeys(p_FlowID, "states")
	{
		if (assignnext = true)
		{
			;~ currentStateID:=id
			states_Restore(p_FlowID, stateID)
			_setFlowProperty(p_FlowID, "currentState", stateID)
			break
		}
		if (stateID =  currentState)
		{
			assignnext:=true
		}
		
	}
	
	LeaveCriticalSection(_cs_shared)
}


states_Update(p_FlowID, p_StateID)
{
	EnterCriticalSection(_cs_shared)
	
	;Find out whether there are changes in trigger parameters. If so, the trigger must be disabled and reenabled again
	currentState := _getFlowProperty(p_FlowID, "currentState")
	changedTriggers := findTriggersWhichHaveBeenChanged(p_FlowID, currentState)
	
	for oneIndex, oneelementID in changedTriggers
	{
		disableOneTrigger(p_FlowID, oneelementID, false)
	}
	
	allElements := _getFlowProperty(p_FlowID, "allElements")
	_setFlowProperty(p_FlowID, "states." p_StateID ".allElements", allElements, false)

	allConnections := _getFlowProperty(p_FlowID, "allConnections")
	_setFlowProperty(p_FlowID, "states." p_StateID ".allConnections", allConnections, false)

	allTriggers := _getFlowProperty(p_FlowID, "allTriggers")
	_setFlowProperty(p_FlowID, "states." p_StateID ".allTriggers", allTriggers, false)

	Settings := _getFlowProperty(p_FlowID, "Settings")
	_setFlowProperty(p_FlowID, "states." p_StateID ".Settings", Settings, false)
	
	for oneIndex, oneelementID in changedTriggers
	{
		enableOneTrigger(p_FlowID, oneelementID, false)
	}
	
	LeaveCriticalSection(_cs_shared)
}

states_Restore(p_FlowID, p_StateID)
{
	EnterCriticalSection(_cs_shared)
	
	;Find out whether there are changes in trigger parameters. If so, the trigger must be disabled and reenabled again
	currentState := _getFlowProperty(p_FlowID, "currentState")
	changedTriggers := findTriggersWhichHaveBeenChanged(p_FlowID, currentState) ;todo: is this line correct?
	
	for oneIndex, oneelementID in changedTriggers
	{
		disableOneTrigger(p_FlowID, oneelementID, false)
	}
	
	allElements := _getFlowProperty(p_FlowID, "states." p_StateID ".allElements")
	_setFlowProperty(p_FlowID, "allElements", allElements, false)
	allConnections := _getFlowProperty(p_FlowID, "states." p_StateID ".allConnections")
	_setFlowProperty(p_FlowID, "allConnections", allConnections, false)
	allTriggers := _getFlowProperty(p_FlowID, "states." p_StateID ".allTriggers")
	_setFlowProperty(p_FlowID, "allTriggers", allTriggers, false)
	Settings := _getFlowProperty(p_FlowID, "states." p_StateID ".Settings")
	_setFlowProperty(p_FlowID, "Settings", Settings, false)
	
	for oneIndex, oneelementID in changedTriggers
	{
		enableOneTrigger(p_FlowID, oneelementID, false)
	}
	
	;Restore marked elements
	markedelements := _getFlowProperty(p_FlowID,  "markedelements")
	allElementIDs := _getAllElementIds(p_FlowID)
	for forIndex, forElementID in allElementIDs
	{
		if markedelements.haskey(forElementID)
		{
			_setElementProperty(p_FlowID, forElementID, "marked", True)
		}
		else
		{
			_setElementProperty(p_FlowID, forElementID, "marked", False)
		}
	}
	allConnectionIDs := _getAllConnectionIds(p_FlowID)
	for forIndex, forConnectionID in allConnectionIDs
	{
		if markedelements.haskey(forConnectionID)
		{
			_setConnectionProperty(p_FlowID, forConnectionID, "marked", True)
		}
		else
		{
			_setConnectionProperty(p_FlowID, forConnectionID, "marked", False)
		}
	}
	
	LeaveCriticalSection(_cs_shared)
	
}
state_RestoreCurrent(p_FlowID)
{
	EnterCriticalSection(_cs_shared)
	
	currentState := _getFlowProperty(p_FlowID, "currentState")
	states_Restore(p_FlowID, currentState)
	
	LeaveCriticalSection(_cs_shared)
}

states_DeleteNewerThanCurrent(p_FlowID)
{
	EnterCriticalSection(_cs_shared)
	
	currentState := _getFlowProperty(p_FlowID, "currentState")

	statesToRemove:=[]
	found := false
	for stateIndex, stateID in _getAllFlowPropertyKeys(p_FlowID, "states")
	{
		if (found)
		{
			_deleteFlowProperty(p_FlowID, "states." stateID)
		}
		if (stateID = currentState)
		{
			found := true
		}
	}
	
	LeaveCriticalSection(_cs_shared)
}

states_DeleteTooOld(p_FlowID)
{
	EnterCriticalSection(_cs_shared)
	allStateIds := _getAllFlowPropertyKeys(p_FlowID, "states")
	if (allStateIds.count() > MAX_COUNT_OF_STATES)
	{
		Loop % allStateIds.count() - MAX_COUNT_OF_STATES
		{
			_deleteFlowProperty(p_FlowID, "states." allStateIds[a_index])
		}
	}
	
	LeaveCriticalSection(_cs_shared)
}


findTriggersWhichHaveBeenChanged(p_FlowID, p_StateID)
{
	EnterCriticalSection(_cs_shared)
	
	;Find out whether there are changes in trigger parameters.
	allElementIDs := _getAllElementIds(p_FlowID)
	changedTriggers:=Object()
	for oneelementIndex, oneelementID in allElementIDs
	{
		elementType := _getElementProperty(p_FlowID, oneelementID, "type")
		elementEnabled := _getElementProperty(p_FlowID, oneelementID, "enabled")
		if (elementType = "trigger" and elementEnabled = true)
		{
			elementClass := _getElementProperty(p_FlowID, oneelementID, "class")
			elementPars := _getElementProperty(p_FlowID, oneelementID, "pars")
			elementInStateClass := _getFlowProperty(p_FlowID, "states." p_StateID ".allElements." oneelementID ".class")
			elementInStatePars := _getFlowProperty(p_FlowID, "states." p_StateID ".allElements." oneelementID ".pars")

			differenceFound:=false
				;~ d(oneelement)
				;~ d(secondElement)
			
			differenceFound := !ObjFullyCompare_oneDir(elementClass, elementInStatePars)
			
			if (elementClass != elementInStateClass)
			{
				differenceFound:=true
			}
			if (differenceFound)
			{
				changedTriggers.push(oneelementID)
			}
		}
	}
	
	LeaveCriticalSection(_cs_shared)
	
	return changedTriggers
}