

Var_EvaluateExpression(environment,ExpressionString,  func_GetVariable, func_SetVariable)
{
	;~ MsgBox %testExpr%
	tokens:=tokenizer(ExpressionString)
	parsedCode:=class_parser.parse(tokens, "expression")
	
	;~ FileDelete,result.txt
	;~ FileAppend,% ExpressionString "`n`n" ,result.txt,utf-8
	;~ FileAppend,% strobj(parsedCode) "`n`n",result.txt,utf-8
	;~ MsgBox % strobj(parsedCode)
	
	
	if (parsedCode.errors.MaxIndex())
	{
		;~ d(parsedCode.errors)
		;~ MsgBox % "Do not execute because there are errors:`n" parsedCode.errorsString
		;generate readable string
		string:=""
		for oneindex, oneerror in parsedCode.errors
		{
			if (a_index!=1)
				string.="`n`n"
			string.=lang("line %1%, col %2%`n", oneerror.linenr, oneerror.colnr) 
			string.=oneerror.line "`n"
			string.=oneerror.description
		}
		
		return {error: string}
	}
	else
	{
		result:=class_evaluator.evaluate(parsedCode, environment, func_GetVariable, func_SetVariable)
		;~ MsgBox %result%
		
		;~ MsgBox % "result = " result "`n`n" strobj(env)
		return {result: result}
	}
	
}