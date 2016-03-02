
;Contains common functions that are needed for execution. They will be available for any element, which are in the subfolders
class ElementExecution
{
	__new(p_Thread)
	{
		;~ d(p_Thread,"njöo")
		;Save some informations
		this.__thread:=&p_Thread
		this.__instance:=&p_Thread.instance
		this.element:=p_Thread.element
		this.par:=p_Element.par.clone() ;Copy all parameters. It might happen that they will be changed by user during execution, which might cause errors
		
		this.running:=false
		this.finished:=false
		this.started:=false
	}
	
	run()
	{
		this.running:=true
		this.started:=true
	}
	
	end(result,ErrorMessage="")
	{
		this.finished:=true
		this.running:=false
		this.result:=result
		this.ErrorMessage:=ErrorMessage
		;~ MsgBox "end"
	}
	instance[] ;Helps to save the instance in a parameter avoiding a circular reference
	{
		get {
			if (NumGet(this.__Instance) == NumGet(&this)) ; safety check or you can use try/catch/finally
				return Object(this.__Instance)
		}
	}
	thread[] ;Helps to save the instance in a parameter avoiding a circular reference
	{
		get {
			if (NumGet(this.__thread) == NumGet(&this)) ; safety check or you can use try/catch/finally
				return Object(this.__thread)
		}
	}
}


