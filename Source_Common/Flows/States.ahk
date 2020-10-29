

global MAX_COUNT_OF_STATES := 100

; create a new state.
; A state is a copy of all flow properties including all elements.
; A new state is created whenever user changes something.
; During execution always the current state is taken, because it does not contain temporary changes
;   like a new element that was not configured yet, or connections that start or end at mouse position.
state_New(p_FlowID)
{
	_EnterCriticalSection()
	logger("a2", "going to create a new state", p_FlowID)
	
	; if a new state was created, something was changed. Often the connection list has to be updated
	UpdateConnectionLists(p_FlowID)
	
	; if user did undo some actions, we need to delete all states that would be restored if user wanted to redo 
	states_DeleteNewerThanCurrent(p_FlowID)
	
	; create a new state ID
	newState := Object()
	newState.ID := "state" . format("{1:010u}", _getAndIncrementFlowProperty(p_FlowID, "statesCounter"))
	_setFlowProperty(p_FlowID, "states." newState.id, newState)

	; write current state
	states_Update(p_FlowID, newState.ID)

	; keep only a limited count of states (limited count of possible undo actions)
	states_DeleteTooOld(p_FlowID)
	
	_LeaveCriticalSection()
}

; restore a previous state (perform an undo action)
state_Undo(p_FlowID)
{
	logger("a2", "going to perform an undo", p_FlowID)

	found := false
	restored := false
	
	_EnterCriticalSection()

	;Try to find an older state than the current and set it.
	currentState := _getFlowProperty(p_FlowID, "currentState")
	previousState := ""
	for state, stateId in _getAllFlowPropertyKeys(p_FlowID, "states")
	{
		;If this is the current state and a previous state was found
		if (stateid = currentState and previousState)
		{
			;Restore previous state
			restored := True
			states_Restore(p_FlowID, previousState)
			_setFlowProperty(p_FlowID, "currentState", previousState)
			logger("a3", "current state is now " previousState, p_FlowID)
			break
		}

		; we found a state which is older than the current. remember it if next state is the current one
		previousState := stateid
	}
	
	_LeaveCriticalSection()
}

; restore a next state (perform a redo action)
state_Redo(p_FlowID)
{
	logger("a2", "going to perform a redo", p_FlowID)

	_EnterCriticalSection()
	
	currentState := _getFlowProperty(p_FlowID, "currentState")
	
	;Try to find a newer state than the current and set it. This is only possible after user has done a redo and did not changed anything yet.
	assignnext := false
	for stateIndex, stateID in _getAllFlowPropertyKeys(p_FlowID, "states")
	{
		if (assignnext = true)
		{
			; restore the state after the current state
			states_Restore(p_FlowID, stateID)
			_setFlowProperty(p_FlowID, "currentState", stateID)
			logger("a3", "current state is now " stateID, p_FlowID)
			break
		}
		if (stateID =  currentState)
		{
			; we found the current state in list. The next state (if any) will be restored
			assignnext := true
		}
		
	}
	
	_LeaveCriticalSection()
}

; update a state. 
; It will make a full copy of the current flow settings and elements
states_Update(p_FlowID, p_StateID, p_previousStateID = "")
{
	_EnterCriticalSection()
	logger("a2", "Going to update state  " p_StateID, p_FlowID)
	
	; get current (resp. previous) state ID
	currentState := _getFlowProperty(p_FlowID, "currentState")

	if (currentState)
	{
		;Find out whether there are changes in trigger parameters. If so, the trigger must be disabled and reenabled again
		changedTriggers := findEnabledTriggersWhichHaveBeenChanged(p_FlowID, currentState)

		; disable all found changed enabled triggers
		for oneIndex, oneelementID in changedTriggers
		{
			logger("a3", "updating state: Going to temporarely disable changed trigger " oneelementID, p_FlowID)
			; disable one trigger. Do not save the disabled state
			disableOneTrigger(p_FlowID, oneelementID, false)
		}
	}
	; else: this is the first call after the flow was created or loaded. we don't need to reenable triggers

	; copy all elements, connections and settings
	allElements := _getFlowProperty(p_FlowID, "allElements")
	_setFlowProperty(p_FlowID, "states." p_StateID ".allElements", allElements, false)

	allConnections := _getFlowProperty(p_FlowID, "allConnections")
	_setFlowProperty(p_FlowID, "states." p_StateID ".allConnections", allConnections, false)

	Settings := _getFlowProperty(p_FlowID, "Settings")
	_setFlowProperty(p_FlowID, "states." p_StateID ".Settings", Settings, false)
	
	; save current state
	_setFlowProperty(p_FlowID, "currentState", p_StateID)

	; if we have disabled some triggers, because they were changed on this state change, we will reenable them again
	for oneIndex, oneelementID in changedTriggers
	{
		logger("a3", "updating state: Going to reenable changed trigger " oneelementID, p_FlowID)
		enableOneTrigger(p_FlowID, oneelementID, false)
	}
	
	_LeaveCriticalSection()
}

; restore a state
; it will restore a copy of the flow settings and elements
states_Restore(p_FlowID, p_StateID)
{
	_EnterCriticalSection()
	logger("a2", "Going to restore state  " p_StateID, p_FlowID)
	
	; get current (resp. previous) state ID
	currentState := _getFlowProperty(p_FlowID, "currentState")

	;Find out whether there are changes in trigger parameters. If so, the trigger must be disabled and reenabled again
	changedTriggers := findEnabledTriggersWhichHaveBeenChanged(p_FlowID, currentState)

	; disable all found changed enabled triggers
	for oneIndex, oneelementID in changedTriggers
	{
		logger("a3", "restoring state: Going to temporarely disable changed trigger " oneelementID, p_FlowID)
		; disable one trigger. Do not save the disabled state
		disableOneTrigger(p_FlowID, oneelementID, false)
	}
	
	; copy all elements, connections and settings. Keep the info property in each element
	allElements := _getFlowProperty(p_FlowID, "states." p_StateID ".allElements")
	for oneElementID, oneElement in allElements
	{
		oneElement.info := _getElementProperty(p_FlowID, oneElementID, "info")
	}
	_setFlowProperty(p_FlowID, "allElements", allElements, false)
	allConnections := _getFlowProperty(p_FlowID, "states." p_StateID ".allConnections")
	_setFlowProperty(p_FlowID, "allConnections", allConnections, false)
	Settings := _getFlowProperty(p_FlowID, "states." p_StateID ".Settings")
	_setFlowProperty(p_FlowID, "Settings", Settings, false)
	
	; save current state
	_setFlowProperty(p_FlowID, "currentState", p_StateID)

	; if we have disabled some triggers, because they were changed on this state change, we will reenable them again
	for oneIndex, oneelementID in changedTriggers
	{
		logger("a3", "restoring state: Going to reenable changed trigger " oneelementID, p_FlowID)
		enableOneTrigger(p_FlowID, oneelementID, false)
	}
	
	; After an undo or redo, update information about selected elements and connections
	selectedElements := _getFlowProperty(p_FlowID,  "selectedElements")
	allElementIDs := _getAllElementIds(p_FlowID)
	for forIndex, forElementID in allElementIDs
	{
		if (selectedElements.haskey(forElementID))
		{
			_setElementInfo(p_FlowID, forElementID, "selected", True)
		}
		else
		{
			_setElementInfo(p_FlowID, forElementID, "selected", False)
		}
	}
	allConnectionIDs := _getAllConnectionIds(p_FlowID)
	for forIndex, forConnectionID in allConnectionIDs
	{
		if (selectedElements.haskey(forConnectionID))
		{
			_setConnectionInfo(p_FlowID, forConnectionID, "selected", True)
		}
		else
		{
			_setConnectionInfo(p_FlowID, forConnectionID, "selected", False)
		}
	}
	
	_LeaveCriticalSection()
}

; restores current state. This is used if temporary changes were mande and need to be undone
state_RestoreCurrent(p_FlowID)
{
	_EnterCriticalSection()
	
	; get current state ID
	currentState := _getFlowProperty(p_FlowID, "currentState")

	logger("a2", "going to restore current state " currentState, p_FlowID)

	; restore current state
	states_Restore(p_FlowID, currentState)
	
	_LeaveCriticalSection()
}

; delete all states that are newer than current one.
; this is needed if user performs some undos and then changes anything (and creates a new state)
states_DeleteNewerThanCurrent(p_FlowID)
{
	_EnterCriticalSection()
	
	; get current state ID
	currentState := _getFlowProperty(p_FlowID, "currentState")

	; loop throuth all states and find the current one. Then delete all following states
	found := false
	for stateIndex, stateID in _getAllFlowPropertyKeys(p_FlowID, "states")
	{
		if (found)
		{
			logger("a3", "delete state " stateID " which is newer than current", p_FlowID)

			; we found a state that is newer than the current one. Delete it
			_deleteFlowProperty(p_FlowID, "states." stateID)
		}
		if (stateID = currentState)
		{
			; current state found. All following states will be deleted (if any)
			found := true
		}
	}
	
	_LeaveCriticalSection()
}

; we only keep a limited number of undo steps in order to limit the ram memory use
states_DeleteTooOld(p_FlowID)
{
	_EnterCriticalSection()

	; get all states IDs
	allStateIds := _getAllFlowPropertyKeys(p_FlowID, "states")

	; if we have more states than allowed
	if (allStateIds.count() > MAX_COUNT_OF_STATES)
	{
		; delete all states which are too old
		Loop % allStateIds.count() - MAX_COUNT_OF_STATES
		{
			logger("a3", "delete state " stateID " which is too old", p_FlowID)
			_deleteFlowProperty(p_FlowID, "states." allStateIds[a_index])
		}
	}
	
	_LeaveCriticalSection()
}

; find triggers which are enabled and which will have changes between the defined state and the working copy of the flow 
findEnabledTriggersWhichHaveBeenChanged(p_FlowID, p_StateID)
{
	_EnterCriticalSection()
	
	; initialize return value
	changedTriggers := Object()

	; loop through all elements
	allElementIDs := _getAllElementIds(p_FlowID)
	for oneelementIndex, oneelementID in allElementIDs
	{
		elementType := _getElementProperty(p_FlowID, oneelementID, "type")
		if (elementType = "trigger") ; we only need triggers
		{
			elementEnabled := _getElementInfo(p_FlowID, oneelementID, "enabled")
			if (elementEnabled = true) ; we only need enabled triggers
			{
				; get trigger properties in working copy
				elementClass := _getElementProperty(p_FlowID, oneelementID, "class")
				elementPars := _getElementProperty(p_FlowID, oneelementID, "pars")

				; get trigger properties in defined state
				elementInStateClass := _getFlowProperty(p_FlowID, "states." p_StateID ".allElements." oneelementID ".class")
				elementInStatePars := _getFlowProperty(p_FlowID, "states." p_StateID ".allElements." oneelementID ".pars")

				; find differences in the element parameters
				differenceFound := !ObjFullyCompare_oneDir(elementClass, elementInStatePars)
				
				; also check whether if element class was changed
				if (elementClass != elementInStateClass)
				{
					differenceFound:=true
				}

				; did we find differences?
				if (differenceFound)
				{
					; we found differences. We will return this trigger ID
					changedTriggers.push(oneelementID)
				}
			}
		}
	}
	
	_LeaveCriticalSection()
	
	return changedTriggers
}