
; evaluate an expression
; useCommonFunctions: if false we will use functions "var_get" and "var_set", if true, we will use "var_get_common" and "var_set_common"
Var_EvaluateExpression(environment, ExpressionString, useCommonFunctions)
{
	; step 1: tokenize the code
	tokens := tokenizer(ExpressionString)
	
	; step 2: parse the tokenized code
	parsedCode := class_parser.parse(tokens, "expression")
	
	; check for returned error
	if (parsedCode.errors.MaxIndex())
	{
		; there were errors. return a readable string
		;generate readable string
		string := ""
		for oneindex, oneerror in parsedCode.errors
		{
			if (a_index != 1)
				string .= "`n`n"
			string .= lang("line %1%, col %2%`n", oneerror.line, oneerror.col) 
			string .= oneerror.wholeline "`n"
			string .= oneerror.description
		}
		
		return {error: string}
	}
	; there was no error
	; step 3: evaluate the tokenized code
	evaluatedCode := class_evaluator.evaluate(parsedCode, environment, useCommonFunctions)
	if (evaluatedCode.errors.MaxIndex())
	{
		; there were errors. return a readable string
		;generate readable string
		string := ""
		for oneindex, oneerror in evaluatedCode.errors
		{
			if (a_index != 1)
				string .= "`n`n"
			string .= lang("line %1%, col %2%`n", oneerror.line, oneerror.col) 
			string .= oneerror.wholeline "`n"
			string .= oneerror.description
		}
		
		return {error: string}
	}
	; return the evaluated expression
	return {result: evaluatedCode.res}
}