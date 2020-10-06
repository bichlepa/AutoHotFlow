; evaluate some code which comes as a string
var_evaluateScript(environment, p_script, useCommonFunctions)
{
	; step 1: tokenize the code
	tokens := tokenizer(p_script)

	; step 2: parse the tokens
	parsedCode := class_parser.parse(tokens)

	; step 3: evaluate the pared code
	class_evaluator.evaluate(parsedCode, environment, useCommonFunctions)
}



class class_evaluator
{
	; evaluate some code which is already tokenized and parsed
	; useCommonFunctions: if false we will use functions "var_get" and "var_set", if true, we will use "var_get_common" and "var_set_common"
	evaluate(parsedCode, environment, useCommonFunctions)
	{
		; save the parameters
		this.parsedCode := parsedCode
		this.environment := environment
		this.useCommonFunctions := useCommonFunctions

		; start evaluation
		res := this.evalnext(parsedCode)
		return res
	}
	
	; evaluate the current part of the pared expression
	evalnext(exp)
	{
		; decide what to do depending on the expression type
		if (exp.type = "num" or exp.type = "str")
		{
			; we have a number or string. We don't need to change anything on that. Return it.
			return exp.value
		}
		if (exp.type = "var")
		{
			; we have a variable

			; the path of the variable may consist of multiple parts
			path := object()
			for oneindex, onepath in exp.path
			{
				; evaluate the current part of the path
				path.push(this.evalnext(onepath))
			}

			; create the dotted format of the path
			pathDotted := ""
			for oneindex, onepath in path
			{
				if (a_index != 1)
					pathDotted .= "."
				pathDotted .= onepath
			}

			; get the variable value
			; %empty% is here because the file may be included by threads which do not include the module with one of those functions
			if (this.useCommonFunctions)
				varValue := var_get_common%empty%(this.environment, pathDotted)
			else
				varValue := var_get%empty%(this.environment, pathDotted)
			return varValue
		}
		if (exp.type = "func")
		{
			; todo: do we need this?
			path := object()
			for oneindex, onepath in exp.path
			{
				path.push(this.evalnext(onepath))
			}
			return path
		}
		if (exp.type = "assign")
		{
			; we have an assign operation.
			if (exp.left.type != "var")
			{
				; we have no a variable on left side of the assign operation. Error.
				this.croak("Expected variable on left side of the operator.", exp)
				return
			}
			else
			{
				; we have a variable on left side
				
				; the path of the variable may consist of multiple parts
				path := object()
				for oneindex, onepath in exp.left.path
				{
					; evaluate the current part of the path
					path.push(this.evalnext(onepath))
				}

				; create the dotted format of the path
				pathDotted := ""
				for oneindex, onepath in path
				{
					if (a_index != 1)
						pathDotted .= "."
					pathDotted .= onepath
				}
				
				; get the variable value
				; %empty% is here because the file may be included by threads which do not include the module with one of those functions
				if (this.useCommonFunctions)
					value:=var_get_common%empty%(this.environment, pathDotted)
				Else
					value:=var_get%empty%(this.environment ,pathDotted)
				
				; calculate the result of the assign operator
				value := this.assign(exp.operator, value, this.evalnext(exp.right))

				; set the variable value
				; %empty% is here because the file may be included by threads which do not include the module with one of those functions
				if (this.useCommonFunctions)
					return var_set_common%empty%(this.environment,pathDotted, value)
				Else
					return var_set%empty%(this.environment,pathDotted, value)
			}
		}
		if (exp.type = "binary")
		{
			; we have a binary operator.
			; evaluate the left side and the right side of the expression and then apply the operator
			return this.apply(exp.operator, this.evalnext(exp.left), this.evalnext(exp.right))
		}
		if (exp.type = "if")
		{
			; we have an if condition

			; evaluate the condition
			cond := this.evalnext(exp.cond)

			; check the evaluation result
			if (cond)
			{
				; the condition is true. Evaluate the "then" part of code
				return this.evalnext(exp.then)
			}
			else if (exp.else)
			{
				; the condition is false and there is an else keyword. Evaluate the "else" part of code
				return this.evalnext(exp.else)
			}
			else
			{
				; the condition is false and there is no else keyword. Nothing left to evaluate. Return false (todo: why false?)
				return false
			}
		}
		if (exp.type = "prog")
		{
			; we have some executable code.
			val := false
			; Start evaluate the code
			for oneIndex, oneProgExp in exp.prog
			{
				val := this.evalnext(oneProgExp)
			}

			; TODO: why do we return anything?
			return val
		}
		if (exp.type = "call")
		{
			; we have a function call
			
			; the path of the function name may consist of multiple parts
			path:=object()
			for oneindex, onepath in exp.path
			{
				path.push(this.evalnext(onepath))
			}
			
			; evaluate the arguments
			args := Object()
			for oneIndex, oneArgsExp in exp.args
			{
				args.push(this.evalnext(oneArgsExp))
			}

			; call the function
			return this.callfunc(path,args*)
		}
		
		; if we get here, the parsed code contains something that we don't know yet. This is then an implementation error.
		this.croak("Unexpected error during evaluation", exp)
	}
	
	; call a function
	callfunc(path, args*)
	{
		if (path.maxindex() >1)
		{
			; we can't call functions which path has multiple parts
			this.croak("cannot call functions inside an object", path)
		}
		
		funcname := path[1]
		if (funcname = "print")
		{
			; todo: log a message
			return
		}
		if (funcname = "round")
		{
			; round a number
			return round(args[1], args[2])
		}
		if (funcname = "object")
		{
			; create an empty object
			return object()
		}
		
		this.croak("unknown function " funcname " called with pars: `n " strobj(args))
	}
	
	; apply a binary operator
	; op: opereator
	; a: first operand (left side)
	; b: second operand (right side)
	apply(op, a, b)
	{
		if (op = "+")
			return a + b
		if (op = "-")
			return a - b
		if (op = "*")
			return a * b
		if (op = "/")
			return a / b
		if (op = "//")
			return a // b
		if (op = "&&")
			return a && b
		if (op = "||")
			return a && b
		if (op = "!")
			return !b
		if (op = "<")
			return a < b
		if (op = ">")
			return a > b
		if (op = "<=")
			return a <= b
		if (op = ">=")
			return a >= b
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
	
	; apply an assign operator
	; op: opereator
	; a: first operand (left side)
	; b: second operand (right side)
	assign(op, a, b)
	{
		if (op = ":=")
			return b
		if (op = ".=")
			return a . b
		if (op = "+=")
			return a + b
		if (op = "-=")
			return a - b
		if (op = "*=")
			return a * b
		if (op = "/=")
			return a / b
		
		this.croak("Error: Can't apply assign "  op)
	}
	
	; creates an error message on evaluation error
	croak(description, token = "")
	{
		wholelinehighlighted := substr(token.wholeline,1,this.token.col-1) " -> " token.value " <- " substr(token.wholeline, token.col + strlen(token.value))
		error := {description: description, line: token.line, col: token.col, pos: token.pos, wholeline: token.wholeline, value: token.value, wholelinehighlighted: wholelinehighlighted}
		token.errors.push(error)
		errors.push(error)
	}
}
