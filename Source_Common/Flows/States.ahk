﻿

global_statesCounter:=0
MAX_COUNT_OF_STATES:=100


state_New(p_FlowID, stateID="", params="")
{
	global global_statesCounter
	
	EnterCriticalSection(_cs_shared)
	EnterCriticalSection(_cs_execution)
	
	UpdateConnectionLists(p_FlowID)
	
	if ! isobject(_flows[p_FlowID].states)
		_flows[p_FlowID].states:=Object()
	
	;~ MsgBox new state %p_FlowID% 
	if (stateID = "")
	{
		states_DeleteNewerThanCurrent(p_FlowID)
		
		newState:=Object()
		newState.ID:="state" . format("{1:010u}",++global_statesCounter)
		_flows[p_FlowID].states[newState.id]:=newState
		states_DeleteTooOld(p_FlowID)
	}
	else
	{
		newState:=Object()
		newState.ID:=stateID
		_flows[p_FlowID].states[newState.id]:=newState
	}
	
	states_Update(p_FlowID, newState.ID)
	
	IfNotInString, params, NotAsCurrent
		_flows[p_FlowID].currentState:=newState.ID
	
	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_shared)
}

state_Undo(p_FlowID)
{
	found:=false
	restored:=false
	
	EnterCriticalSection(_cs_shared)
	EnterCriticalSection(_cs_execution)

	;~ MsgBox undo state %p_FlowID%  
	;Try to find an older state than the current and set it.
	for stateid, state in _flows[p_FlowID].states
	{
		;If this is the current state and a previous state was found
		if (stateid=_flows[p_FlowID].currentState and found)
		{
			;Restore previous state
			restored := True
			states_Restore(p_FlowID, previousState)
			_flows[p_FlowID].currentState:=previousState
			break
		}
		;~ MsgBox % stateid " current: " _flows[p_FlowID].currentState
		found:=true
		previousState:=stateid
	}
	
	;Try to find a backup
	if (restored = False and _flows[p_FlowID].backupsLoaded != True)
	{
		filename:=_flows[p_FlowID].FileName
		currentStateIsFromBackup:=false
		foundfilename:=""
		foundbackupdate:=""
		foundfilepath:=""
		foundBackups:=Object()
		;~ MsgBox %_WorkingDir%\saved Flows\backup\%filename%_backup_*.ini
		;~ loop, files, %_WorkingDir%\savedFlows\backup\%filename%_backup_*.ini
		currentStateDate:=_flows[p_FlowID].currentState
		StringReplace,currentStateDate,currentStateDate,Backup_
		if (errorlevel = 0)
		{
			currentStateIsFromBackup := True
		}
		loop, files, %_WorkingDir%\saved Flows\backup\%filename%_backup_*.ini
		{
			StringReplace,backupdate,a_loopfilename,%filename%_backup_
			StringTrimRight,backupdate,backupdate,4
			
			if (((currentStateIsFromBackup = True and currentStateDate > backupdate) or (currentStateIsFromBackup = False)) and (_flows[p_FlowID].firstLoadedTime > backupdate))
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
				_flows[p_FlowID].backupsLoaded:=True
				SplashTextOff
			}
		}
		
		
	}
	
	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_shared)
}

state_Redo(p_FlowID)
{
	EnterCriticalSection(_cs_shared)
	EnterCriticalSection(_cs_execution)
	
	found:=false
	;~ MsgBox redo state %p_FlowID% 
	;Try to find a newer state than the current and set it. This is only possible after user has done a redo and did not changed anything yet.
	assignnext:=false
	for stateid, state in _flows[p_FlowID].states
	{
		if (assignnext=true)
		{
			;~ currentStateID:=id
			states_Restore(p_FlowID, stateid)
			_flows[p_FlowID].currentState:=stateid
			break
		}
		if (stateid=_flows[p_FlowID].currentState)
		{
			assignnext:=true
		}
		
	}
	
	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_shared)
}


states_Update(p_FlowID, p_StateID)
{
	EnterCriticalSection(_cs_shared)
	EnterCriticalSection(_cs_execution)
	
	;Find out whether there are changes in trigger parameters. If so, the trigger must be disabled and reenabled again
	changedTriggers := findTriggersWhichHaveBeenChanged(p_FlowID, _flows[p_FlowID].currentState)
	
	for oneIndex, oneelementID in changedTriggers
	{
		disableOneTrigger(p_FlowID, oneelementID, false)
	}
	
	_flows[p_FlowID].states[p_StateID].allElements:=ObjFullyClone(_flows[p_FlowID].allElements)
	_flows[p_FlowID].states[p_StateID].allConnections:=ObjFullyClone(_flows[p_FlowID].allConnections)
	_flows[p_FlowID].states[p_StateID].allTriggers:=ObjFullyClone(_flows[p_FlowID].allTriggers)
	_flows[p_FlowID].states[p_StateID].Settings:=ObjFullyClone(_flows[p_FlowID].Settings)
	
	for oneIndex, oneelementID in changedTriggers
	{
		enableOneTrigger(p_FlowID, oneelementID, false)
	}
	
	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_shared)
}

states_Restore(p_FlowID, p_StateID)
{
	EnterCriticalSection(_cs_shared)
	EnterCriticalSection(_cs_execution)
	
	;Find out whether there are changes in trigger parameters. If so, the trigger must be disabled and reenabled again
	changedTriggers := findTriggersWhichHaveBeenChanged(p_FlowID, _flows[p_FlowID].currentState)
	
	for oneIndex, oneelementID in changedTriggers
	{
		disableOneTrigger(p_FlowID, oneelementID, false)
	}
	
	_flows[p_FlowID].allElements:=ObjFullyClone(_flows[p_FlowID].states[p_StateID].allElements)
	_flows[p_FlowID].allConnections:=ObjFullyClone(_flows[p_FlowID].states[p_StateID].allConnections)
	_flows[p_FlowID].allTriggers:=ObjFullyClone(_flows[p_FlowID].states[p_StateID].allTriggers)
	_flows[p_FlowID].Settings:=ObjFullyClone(_flows[p_FlowID].states[p_StateID].Settings)
	
	for oneIndex, oneelementID in changedTriggers
	{
		enableOneTrigger(p_FlowID, oneelementID, false)
	}
	
	;Restore marked elements
	for tempID, tempObj in _flows[p_FlowID].allElements
	{
		if _flows[p_FlowID].markedelements.haskey(tempID)
		{
			tempObj.marked:=True
		}
		else
		{
			tempObj.marked:=False
		}
	}
	for tempID, tempObj in _flows[p_FlowID].allConnections
	{
		if _flows[p_FlowID].markedelements.haskey(tempID)
		{
			tempObj.marked:=True
		}
		else
		{
			tempObj.marked:=False
		}
	}
	
	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_shared)
	
}
state_RestoreCurrent(p_FlowID)
{
	EnterCriticalSection(_cs_shared)
	EnterCriticalSection(_cs_execution)
	
	states_Restore(p_FlowID, _flows[p_FlowID].currentstate)
	
	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_shared)
}

states_DeleteNewerThanCurrent(p_FlowID)
{
	EnterCriticalSection(_cs_shared)
	EnterCriticalSection(_cs_execution)
	
	currentnumber:=substr(_flows[p_FlowID].currentState,StrLen("state")+1)
	statesToRemove:=[]
	for id, state in _flows[p_FlowID].states
	{
		ForNumber:=substr(id,StrLen("state")+1)
		if (ForNumber>currentnumber)
		{
			statesToRemove.push(id)
		}
	}
	for index, id in statesToRemove
	{
		_flows[p_FlowID].states.delete(id)
	}
	
	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_shared)
}

states_DeleteTooOld(p_FlowID)
{
	EnterCriticalSection(_cs_shared)
	EnterCriticalSection(_cs_execution)
	
	if (_flows[p_FlowID].states.count() > MAX_COUNT_OF_STATES)
	{
		Loop % _flows[p_FlowID].states.count() - MAX_COUNT_OF_STATES
		{
			for id, state in _flows[p_FlowID].states
			{
				todelete:=id
				break
			}
			_flows[p_FlowID].states[todelete].delete()
		}
	}
	
	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_shared)
}


findTriggersWhichHaveBeenChanged(p_FlowID, p_StateID)
{
	EnterCriticalSection(_cs_shared)
	EnterCriticalSection(_cs_execution)
	
	;Find out whether there are changes in trigger parameters.
	changedTriggers:=Object()
	for oneelementID, oneelement in _flows[p_FlowID].allElements
	{
		if (oneelement.type = "trigger" and oneelement.enabled = true)
		{
			secondElement:=_flows[p_FlowID].states[p_StateID].allElements[oneelementID]
			differenceFound:=false
				;~ d(oneelement)
				;~ d(secondElement)
			
			differenceFound := !ObjFullyCompare_oneDir(oneelement.pars, secondElement.pars)
			
			if (oneelement.class != secondElement.class)
			{
				differenceFound:=true
			}
			if (differenceFound)
			{
				changedTriggers.push(oneelementID)
			}
		}
	}
	
	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_shared)
	
	return changedTriggers
}