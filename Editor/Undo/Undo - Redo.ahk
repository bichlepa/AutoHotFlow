
globalstatesCounter:=0
states:=new stateClass()
currentState=[]
savedState=
currentStateID=
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
		found:=false
		for id, state in this
		{
			if (id=currentStateID and found)
			{
				;~ currentStateID:=previousID
				currentState:=previousState
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
		assignnext:=false
		for id, state in this
		{
			if (assignnext=true)
			{
				;~ currentStateID:=id
				currentState:=state
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
		global states
		global globalstatesCounter, currentStateID, currentState
		
		states.deleteNewerStatesThanCurrent()
		globalstatesCounter++
		this.ID:="state" . format("{1:010u}",globalstatesCounter)
		states[this.ID]:=this
		states.crop()
		;~ currentStateID:=this.id
		currentState:=this
		this.update()
	}
	
	update()
	{
		global
		this.allElements:=ObjFullyClone(allElements)
		this.allConnections:=ObjFullyClone(allConnections)
		this.allTriggers:=ObjFullyClone(allTriggers)
		this.flowSettings:=ObjFullyClone(share.flowSettings)
		currentStateID:=this.id
		share.currentStateID:=this.id
	}
	
	restore()
	{
		global allElements, allConnections,allTriggers, share
		
		
		loop 3
		{
		
			if a_index=1
				listname:="allElements"
			else if a_index=2
				listname:="allConnections"
			else if a_index=3
				listname:="allTriggers"
			
			existingelements:=[]	
			for forID, forElement in this[listname]
			{
				existingelements[forID]:=forID
				existingPars:=[]
				
				if (not %listname%.HasKey(forID))
				{
					%listname%[forID]:=CriticalObject()
				}
				
				for forPar, forValue in forElement
				{
					existingPars[forPar]:=forPar
					if not (forPar="marked" or forPar="ID" or forpar ="running")
					{
						if isobject(forValue)
						{
							%listname%[forID][forPar]:=ObjFullyClone(forValue)
						}
						else
						{
							%listname%[forID][forPar]:=forValue
						}
					}
				}
				for forPar, forValue in %listname%[forID]
				{
					if (not existingPars.HasKey(forPar))
					{
						%listname%[forID].delete(forPar)
					}
				}
			}
		
			for forID, forElement in %listname%
			{
				if (not (existingelements.HasKey(forID)))
				{
					;~ MsgBox % "should delete " forID
					%listname%.delete(forID)
				}
			}
		}
		
		for forPar, forValue in this.flowSettings
		{
			existingPars[forPar]:=forPar
			if not (forPar="notDefined_")
			{
				if isobject(forValue)
				{
					share.flowSettings[forPar]:=ObjFullyClone(forValue)
				}
				else
				{
					share.flowSettings[forPar]:=forValue
				}
			}
		}
		for forPar, forValue in share.flowSettings
		{
			if (not existingPars.HasKey(forPar))
			{
				share.flowSettings.delete(forPar)
			}
		}
		currentStateID:=this.id
		share.currentStateID:=this.id
		/* simple method, but cannot be used anymore because of multithreading
		allElements:=ObjFullyClone(this.allElements)
		allConnections:=ObjFullyClone(this.allConnections)
		allTriggers:=ObjFullyClone(this.allTriggers)
		share.flowSettings:=ObjFullyClone(this.flowSettings)
		*/
		element.unmarkall()
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