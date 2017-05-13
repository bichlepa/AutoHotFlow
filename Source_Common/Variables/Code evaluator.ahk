var_evaluateScript(env, p_script, func_GetVariable, func_SetVariable)
{
	tokens:=tokenizer(p_script)
	parsedCode:=class_parser.parse(tokens)
	class_evaluator.evaluate(parsedCode,env,func_GetVariable, func_SetVariable)
}



class class_evaluator
{
	evaluate(parsedCode,env,func_GetVariable, func_SetVariable)
	{
		this.parsedCode:=parsedCode
		this.env:=env
		this.func_GetVariable:=func_GetVariable
		this.func_SetVariable:=func_SetVariable
		
		this.evalnext(parsedCode)
	} 
	
	evalnext(exp)
	{
		
		if (exp.type = "num" or exp.type = "str")
		{
			return exp.value
		}
		if (exp.type = "var")
		{
			path:=object()
			for oneindex, onepath in exp.path
			{
				;~ MsgBox % strobj(onepath)
				path.push(this.evalnext(onepath))
			}
			func_GetVariable:=this.func_GetVariable
			;~ d(path, func_GetVariable)
			varValue:=%func_GetVariable%(this.env,path)
			;~ d(path, varValue)
			;~ d(path, func_GetVariable)
			return varValue
		}
		if (exp.type = "func")
		{
			path:=object()
			for oneindex, onepath in exp.path
			{
				path.push(this.evalnext(onepath))
			}
			return path
		}
		if (exp.type = "assign")
		{
			if (exp.left.type != "var")
			{
				this.croak("Cannot assign to this", exp.left)
				return
			}
			else
			{
				path:=object()
				for oneindex, onepath in exp.left.path
				{
					path.push(this.evalnext(onepath))
				}
				func_GetVariable:=this.func_GetVariable
				func_setVariable:=this.func_setVariable
				value:=%func_GetVariable%(this.env,path)
				value:=this.assign(exp.operator, value, this.evalnext(exp.right))
				return %func_setVariable%(this.env,path) ;TODO
				
			}
		}
		if (exp.type = "binary")
		{
			return this.apply(exp.operator, this.evalnext(exp.left), this.evalnext(exp.right))
		}
		if (exp.type = "if")
		{
			cond:=this.evalnext(exp.cond)
			if (cond != false)
				return this.evalnext(exp.then)
			else if (exp.else)
				return this.evalnext(exp.else)
			else 
				return false
		}
		if (exp.type = "prog")
		{
			val := false
			for oneIndex, oneProgExp in exp.prog
			{
				val:=this.evalnext(oneProgExp)
			}
			return val
		}
		if (exp.type = "call")
		{
			args:=Object()
			
			path:=object()
			for oneindex, onepath in exp.path
			{
				path.push(this.evalnext(onepath))
			}
			
			for oneIndex, oneArgsExp in exp.args
			{
				
				d(oneArgsExp)
				args.push(this.evalnext(oneArgsExp))
			}
			;~ d(exp.args)
			;~ d(args)
			return this.callfunc(path,args*)
		}
		
		this.croak("Unexpected error during evaluation", exp)
	}
	
	
	callfunc(path, args*)
	{
		if (path.maxindex() >1)
		{
			this.croak("cannot call functions inside an object", path)
		}
		funcname:=path[1]
		if (funcname = "print")
		{
			MsgBox % args[1]
			return
		}
		if (funcname = "round")
		{
			return round(args[1], args[2])
		}
		if (funcname = "object")
		{
			return object()
		}
		
		this.croak("unknown function " funcname " called with pars: `n strobj(args)")
		
	}

	num(x)
	{
		;~ if x is not number
			;~ MsgBox % "Error: Expected number but got " x
		return x
	}
	div(x)
	{
		;~ if (this.num(x) = 0)
			;~ MsgBox % "Error: Divide by zero"
		return x
	}
	
	apply(op,a,b)
	{
		if (op = "+")
			return this.num(a) + this.num(b)
		if (op = "-")
			return this.num(a) - this.num(b)
		if (op = "*")
			return this.num(a) * this.num(b)
		if (op = "/")
			return this.num(a) / this.div(b)
		if (op = "//")
			return this.num(a) // this.div(b)
		if (op = "&&")
			return a && b
		if (op = "||")
			return a && b
		if (op = "!")
			return !b
		if (op = "<")
			return this.num(a) < this.num(b)
		if (op = ">")
			return this.num(a) > this.num(b)
		if (op = "<=")
			return this.num(a) <= this.num(b)
		if (op = ">=")
			return this.num(a) >= this.num(b)
		if (op = "==")
			return a == b
		if (op = "=")
			return a = b
		if (op = "!=")
			return a != b
		if (op = ".")
			return a . b
		
		this.croak("Error: Can't apply operator "  op)
	}
	
	assign(op,a,b)
	{
		;~ MsgBox % op " - " a " - " b
		if (op = ":=")
			return b
		if (op = ".=")
			return a b
		if (op = "+=")
			return this.num(a) + this.num(b)
		if (op = "-=")
			return this.num(a) - this.num(b)
		if (op = "*=")
			return this.num(a) * this.num(b)
		if (op = "/=")
			return this.num(a) / this.num(b)
		
		this.croak("Error: Can't apply assign "  op)
	}
	
	
	croak(description, token = "")
	{
		wholelinehighlighted:=substr(this.token.wholeline,1,this.token.col-1) " -> " this.token.value " <- " substr(this.token.wholeline, this.token.col + strlen(this.token.value))
		error:={description: description, line: this.token.line, col: this.token.col, pos: this.token.pos, wholeline: this.token.wholeline, value: this.token.value, wholelinehighlighted: wholelinehighlighted}
		this.token.errors.push(error)
		this.errors.push(error)
		MsgBox % strobj(error)
	}
}
