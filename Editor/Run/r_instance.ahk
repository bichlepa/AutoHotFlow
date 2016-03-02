

globalinstancecounter=0
globalthreadcounter=0
class cl_instance
{
	static ID:=""
	static IsWaiting:=false
	
	__New(){
		global globalinstancecounter
		global allInstances
		this.vars:=[]
		this.threads:=new ObjectwithCounter()
		this.ID:="instance" . format("{1:010u}",++globalinstancecounter)
		tempThread:=new this.cl_thread(this)
		this.firstThread:=tempThread
		tempThread.set("a_triggertime",a_now,,"thread")
		;~ tempThread.set("a_test","hello a world",,"thread")
		;~ tempThread.set("test","helloworld")
		;~ tempThread.set("test2","helloworld2")
	}
	
	
	delete()
	{
		global allInstances
		allInstances.delete(this.ID)
		
	}
	
	
	stop()
	{
		for forThreadID, forThread in this.threads
		{
			forThread.stop()
		}
	}
	
	stopall()
	{
		global allInstances
		for forInstanceID, forInstance in allInstances
		{
			forInstance.stop()
		}
		
	}
	
	class cl_thread
	{
		__New(p_instance){
			global globalthreadcounter
			this.ID:="thread" . format("{1:010u}",++globalthreadcounter)
			this.vars:=[]
			this.loopvars:=[]
			this.__Instance := &p_instance
			this.instance.threads[this.ID]:=this
			this.element:=""
			this.execution:=""
			;~ MsgBox hi
		}
		
		cloneThread()
		{
			global globalthreadcounter
			tempThread:=ObjFullyClone(this)
			tempThread.id:="thread" . format("{1:010u}",++globalthreadcounter)
			this.instance.threads[tempThread.ID]:=tempThread
			return tempThread
		}
		
		instance[] ;Helps to save the instance in a parameter avoiding a circular reference
		{
			get {
				if (NumGet(this.__Instance) == NumGet(&this)) ; safety check or you can use try/catch/finally
					return Object(this.__Instance)
			}
		}
		
		setVariable(varName,value,type="normal",location="") ;Set a variable
		{
			variable.set(this,varName,value,type,location)
		}
		
		getVariable(name,VariableType="AsIs")
		{
			return variable.get(this,name,VariableType)
		}
		
		replaceVariables(name,VariableType="AsIs")
		{
			return variable.replaceVariables(this,name,VariableType)
		}
		
		delete()
		{
			this.instance.threads.delete(this.ID)
		}
		
		stop()
		{
			this.execution.stop()
		}
	}
	
	
	
   
}


/*
allInstances:=Object()

allInstances.push(tempInstance:=new instance())
tempThread:=tempInstance.threads[1]
tempThread.setVariable("name","fffalkj")

MsgBox % strobj(tempInstance)
;~ MsgBox % strobj(tempInstance.vars)
;~ MsgBox % strobj(tempInstance.threads[1].vars)
MsgBox % tempThread.getVariable("a_test")
MsgBox % tempThread.getVariable("a_now")
MsgBox % tempThread.getVariable("now")
*/
