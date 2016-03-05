
globalstatesCounter:=0
states:=new stateClass()
currentState=[]
savedState=
currentStateID=
share.currentState:=currentState
;~ ;Testing:
;~ loop 12
;~ StateID1:=new state()
;~ StateID2:=new state()

;~ MsgBox % states.count() " - " currentStateID
;~ states.undo()
;~ MsgBox % states.count() " - " currentStateID
;~ states.undo()
;~ MsgBox % states.count() " - " currentStateID
;~ states.redo()
;~ states.redo()
;~ MsgBox % states.count() " - " currentStateID
;~ states[StateID2].delete()
;~ states.delete("state1")
;~ states.delete("state2")
;~ MsgBox % states.count()

class stateClass
{
	static MAXSAVEDSTATES=100
	count() 
	{
		;~ MsgBox % this.MAXSAVEDSTATES
		return NumGet(&this + 4*A_PtrSize)
	}
	
	crop() ;Keep only MAXSAVEDSTATES states in order to save memory
	{
		if (this.count()>this.MAXSAVEDSTATES)
		{
			Loop % this.count() - this.MAXSAVEDSTATES
			{
				for id, state in this
				{
					todelete:=id
					break
				}
				this[todelete].delete()
			}
		}
		
	}
	
	undo() ;Try to find an older state than the current and set it.
	{
		global currentStateID
		global share
		found:=false
		for id, state in this
		{
			if (id=currentStateID and found)
			{
				currentStateID:=previousID
				currentState:=previousState
				share.currentState:=currentState
				break
			}
			found:=true
			previousID:=id
			previousState:=state
		}
		currentState.restore()
	}
	
	redo() ;Try to find a newer state than the current and set it. This is only possible after user has done a redo and did not changed anything yet.
	{
		global currentStateID
		global share
		assignnext:=false
		for id, state in this
		{
			if (assignnext=true)
			{
				currentStateID:=id
				currentState:=state
				share.currentState:=currentState
				break
			}
			if (id=currentStateID)
			{
				assignnext:=true
			}
			
		}
		currentState.restore()
	}
	
	deleteNewerStatesThanCurrent() ;delete all statuses which are newer than the current one. It is needed if user has done a redo and the changed something.
	{
		global currentStateID
		currentnumber:=substr(currentStateID,StrLen("state")+1)
		statesToRemove:=[]
		for id, state in this
		{
			
			ForNumber:=substr(id,StrLen("state")+1)
			if (ForNumber>currentnumber)
			{
				statesToRemove.push(id)
			}
		}
		for index, id in statesToRemove
		{
			this.delete(id)
		}
	}
}

class state
{
	__new()
	{
		global states, share
		global globalstatesCounter, currentStateID, currentState
		
		states.deleteNewerStatesThanCurrent()
		globalstatesCounter++
		this.ID:="state" . format("{1:010u}",globalstatesCounter)
		states[this.ID]:=this
		states.crop()
		currentStateID:=this.id
		currentState:=this
		share.currentState:=currentState
		this.update()
	}
	
	update()
	{
		global
		this.allElements:=ObjFullyClone(allElements)
		this.allConnections:=ObjFullyClone(allConnections)
		this.allTriggers:=ObjFullyClone(allTriggers)
		this.flowSettings:=ObjFullyClone(flowSettings)
		
	}
	
	restore()
	{
		global
		allElements:=ObjFullyClone(this.allElements)
		allConnections:=ObjFullyClone(this.allConnections)
		allTriggers:=ObjFullyClone(this.allTriggers)
		flowSettings:=ObjFullyClone(this.flowSettings)
		element.unmarkall()
		share.allElements:=allElements
		share.allConnections:=allConnections
		share.allTriggers:=allTriggers
		share.flowSettings:=flowSettings
	}
	
	delete()
	{
		global states
		states.delete(this.id)
	}
	
}





ObjFullyClone(obj) ;Thanks to fincs
{
	nobj := obj.Clone()
	for k,v in nobj
		if IsObject(v)
			nobj[k] := A_ThisFunc.(v)
	return nobj
}