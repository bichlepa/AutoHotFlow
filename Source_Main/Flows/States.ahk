

global_statesCounter:=0
MAX_COUNT_OF_STATES:=100


state_New(p_FlowID)
{
	global _flows, global_statesCounter
	UpdateConnectionLists(p_FlowID)
	
	if ! isobject(_flows[p_FlowID].states)
		_flows[p_FlowID].states:=Object()
	
	;~ MsgBox new state %p_FlowID% 
	states_DeleteNewerThanCurrent(p_FlowID)
	
	newState:=Object()
	newState.ID:="state" . format("{1:010u}",++global_statesCounter)
	
	_flows[p_FlowID].states[newState.id]:=newState
	
	states_DeleteTooOld(p_FlowID)
	
	states_Update(p_FlowID, newState.ID)
	
	_flows[p_FlowID].currentState:=newState.ID
}

state_Undo(p_FlowID)
{
	global _flows
	found:=false
	;~ MsgBox undo state %p_FlowID%  
	;Try to find an older state than the current and set it.
	for stateid, state in _flows[p_FlowID].states
	{
		;If this is the current state and a previous state was found
		if (stateid=_flows[p_FlowID].currentState and found)
		{
			;Restore previous state
			states_Restore(p_FlowID, previousState)
			_flows[p_FlowID].currentState:=previousState
			break
		}
		;~ MsgBox % stateid " current: " _flows[p_FlowID].currentState
		found:=true
		previousState:=stateid
	}
	
}

state_Redo(p_FlowID)
{
	global _flows
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
}


states_Update(p_FlowID, p_StateID)
{
	global _flows
	_flows[p_FlowID].states[p_StateID].allElements:=ObjFullyClone(_flows[p_FlowID].allElements)
	_flows[p_FlowID].states[p_StateID].allElements["action2"].bla:="blabla"
	
	_flows[p_FlowID].states[p_StateID].allConnections:=ObjFullyClone(_flows[p_FlowID].allConnections)
	_flows[p_FlowID].states[p_StateID].allTriggers:=ObjFullyClone(_flows[p_FlowID].allTriggers)
	_flows[p_FlowID].states[p_StateID].Settings:=ObjFullyClone(_flows[p_FlowID].Settings)
	
}
states_Restore(p_FlowID, p_StateID)
{
	global _flows
	_flows[p_FlowID].allElements:=ObjFullyClone(_flows[p_FlowID].states[p_StateID].allElements)
	_flows[p_FlowID].allConnections:=ObjFullyClone(_flows[p_FlowID].states[p_StateID].allConnections)
	_flows[p_FlowID].allTriggers:=ObjFullyClone(_flows[p_FlowID].states[p_StateID].allTriggers)
	_flows[p_FlowID].Settings:=ObjFullyClone(_flows[p_FlowID].states[p_StateID].Settings)
	
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
	
}
state_RestoreCurrent(p_FlowID)
{
	global _flows
	states_Restore(p_FlowID, _flows[p_FlowID].currentstate)
}

states_DeleteNewerThanCurrent(p_FlowID)
{
	global _flows
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
	
}

states_DeleteTooOld(p_FlowID)
{
	global _flows
	if (_flows[p_FlowID].states.count() > MAX_COUNT_OF_STATES)
	{
		Loop % _flows[p_FlowID].states.count() - MAX_COUNT_OF_STATES
		{
			for id, state in this
			{
				todelete:=id
				break
			}
			_flows[p_FlowID].states[todelete].delete()
		}
	}
	
}