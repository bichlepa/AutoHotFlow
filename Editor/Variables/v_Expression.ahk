
/* Evaluation of an Expression
*/
EvaluateExpression(p_Thread,ExpressionString)
{
	logger("f3","Evaluating expression " ExpressionString)
	
	ExpressionString:=A_Space replaceVariables(p_Thread,ExpressionString) A_Space
	
	StringReplace,ExpressionString,ExpressionString,>=,≥,all
	StringReplace,ExpressionString,ExpressionString,<=,≤,all
	StringReplace,ExpressionString,ExpressionString,!=,≠,all
	StringReplace,ExpressionString,ExpressionString,<>,≠,all
	StringReplace,ExpressionString,ExpressionString,==,≡,all
	StringReplace,ExpressionString,ExpressionString,% " or ",∨,all
	StringReplace,ExpressionString,ExpressionString,||,∨,all
	StringReplace,ExpressionString,ExpressionString,% " and ", ∧,all
	StringReplace,ExpressionString,ExpressionString,&&,∧,all
	StringReplace,ExpressionString,ExpressionString,% " not ",% " ¬",all
	StringReplace,ExpressionString,ExpressionString,% "!",% "¬",all
	return v_EvaluateExpressionRecurse(p_Thread,ExpressionString)
}

/* Evaluation of an Expression
Thanks to Sunshine for the easy to understand instruction. See http://www.sunshine2k.de/coding/java/SimpleParser/SimpleParser.html
If anybody knows how to implement more operands and make this more flexible, or even support scripts, please contribute!
*/
v_EvaluateExpressionRecurse(p_Thread,ExpressionString)
{
	;MsgBox %ExpressionString%
	
	
	ExpressionString:=trim(ExpressionString)
	
	if (substr(ExpressionString,1,1)="-" or substr(ExpressionString,1,1)="+")
		ExpressionString:="0" ExpressionString
	
	
	if (v_SearchForFirstOperand(ExpressionString,FoundOpreand,leftSubstring,rightSubstring))
	{
		;MsgBox %  leftSubstring FoundOpreand rightSubstring 
		if ( FoundOpreand != "¬")
			resleft:= v_EvaluateExpressionRecurse(p_Thread,leftSubstring)
		resright:=v_EvaluateExpressionRecurse(p_Thread,rightSubstring)
		;MsgBox %FoundOpreand% %resleft% %resright%
		if FoundOpreand = +
			return resleft + resright
		else if FoundOpreand = -
			return resleft - resright
		else if FoundOpreand = *
			return resleft * resright
		else if FoundOpreand = /
			return resleft / resright
		else if FoundOpreand = ≠
			return resleft != resright
		else if FoundOpreand = ≡
			return resleft == resright
		else if FoundOpreand = =
			return resleft = resright
		else if FoundOpreand = ≤
			return resleft <= resright
		else if FoundOpreand = ≥
			return resleft >= resright
		else if FoundOpreand = <
			return resleft < resright
		else if FoundOpreand = >
			return resleft > resright
		else if FoundOpreand = ∨
			return resleft || resright
		else if FoundOpreand = ∧
			return resleft && resright
		else if FoundOpreand = ¬
		{
			return not resright
		}
		else
			return
	}
	
	if (substr(ExpressionString,1,1) = "(")
	{
		StringRight,tempchar,ExpressionString,1
		if (tempchar = ")")
		{
			StringTrimLeft,ExpressionString,ExpressionString,1
			StringTrimRight,ExpressionString,ExpressionString,1
			return (v_EvaluateExpressionRecurse(p_Thread,ExpressionString))
		}
		   
		else
		{
			MsgBox Bracket Error
			return
		}
	}
	
	if ExpressionString is number
		return ExpressionString
	
	return Variable_Get(p_Thread,ExpressionString,"asIs")
	
	
}

v_SearchForFirstOperand(String,ByRef ResFoundoperand,Byref ResLeftString, Byref ResRightString)
{
	BracketCount=0
	firstplus=
	firstminus=
	;MsgBox %String%
	loop, parse, String
	{
		
		if (a_Loopfield="(")
		{
			BracketCount++
		}
		else if (a_Loopfield=")")
		{
			BracketCount--
		}
		else if (BracketCount=0)
		{
			if (a_Loopfield="∨")
			{
				firstor:=A_Index
			}
			if (a_Loopfield="∧")
			{
				firstand:=A_Index
			}
			if (a_Loopfield="¬")
			{
				
				firstnot:=A_Index
			}
			if (a_Loopfield="=")
			{
				firstequal:=A_Index
				firstequaletc:=A_Index
			}
			if (a_Loopfield="≡")
			{
				firstequalequal:=A_Index
				firstequaletc:=A_Index
			}
			if (a_Loopfield="≠")
			{
				firstenotequal:=A_Index
				firstequaletc:=A_Index
			}
			if (a_Loopfield=">" )
			{
				firstgreater:=A_Index
				firstgreatersmaller:=A_Index
			}
			if (a_Loopfield="<" )
			{
				firstsmaller:=A_Index
				firstgreatersmaller:=A_Index
			}
			if (a_Loopfield="≥" )
			{
				firstgreaterequal:=A_Index
				firstgreatersmaller:=A_Index
			}
			if (a_Loopfield="≤" )
			{
				firstsmallerequal:=A_Index
				firstgreatersmaller:=A_Index
			}
			if (a_Loopfield="+")
			{
				firstplus:=A_Index
				firstplusminus:=A_Index
			}
			if (a_Loopfield="+" )
			{
				firstplus:=A_Index
				firstplusminus:=A_Index
			}
			if (a_Loopfield="-" )
			{
				firstminus:=A_Index
				firstplusminus:=A_Index
			}
			if (a_Loopfield="*" )
			{
				firstMult:=A_Index
				firstplusMultDiv:=A_Index
			}
			if (a_Loopfield="/")
			{
				firstDiv:=A_Index
				firstplusMultDiv:=A_Index
			}
		}
		
		
	}
	
	if (firstor!="" )
	{
		
		ResFoundoperand:="∨"
		StringLeft,ResLeftString,String,% firstor -1
		StringTrimLeft,ResRightString,String,% firstor
		
		return true
	}
	if (firstand!="")
	{
		
		ResFoundoperand:="∧"
		StringLeft,ResLeftString,String,% firstand -1
		StringTrimLeft,ResRightString,String,% firstand
		
		return true
	}
	if (firstnot!="")
	{
		
		ResFoundoperand:="¬"
		StringLeft,ResLeftString,String,% firstnot -1
		StringTrimLeft,ResRightString,String,% firstnot
		
		return true
	}
	if (firstgreater!="" and (firstgreater =firstgreatersmaller))
	{
		
		ResFoundoperand:=">"
		StringLeft,ResLeftString,String,% firstgreater -1
		StringTrimLeft,ResRightString,String,% firstgreater
		
		return true
	}
	if (firstsmaller!="" and (firstsmaller =firstgreatersmaller))
	{
		
		ResFoundoperand:="<"
		StringLeft,ResLeftString,String,% firstsmaller -1
		StringTrimLeft,ResRightString,String,% firstsmaller
		
		return true
	}
	if (firstgreaterequal!="" and (firstgreaterequal =firstgreatersmaller))
	{
		
		ResFoundoperand:="≥"
		StringLeft,ResLeftString,String,% firstgreaterequal -1
		StringTrimLeft,ResRightString,String,% firstgreaterequal
		
		return true
	}
	if (firstsmallerequal!="" and (firstsmallerequal =firstgreatersmaller))
	{
		
		ResFoundoperand:="≤"
		StringLeft,ResLeftString,String,% firstsmallerequal -1
		StringTrimLeft,ResRightString,String,% firstsmallerequal
		
		return true
	}
	if (firstequal!="" and (firstequal =firstequaletc))
	{
		
		ResFoundoperand:="="
		StringLeft,ResLeftString,String,% firstequal -1
		StringTrimLeft,ResRightString,String,% firstequal
		
		return true
	}
	if (firstequalequal!="" and (firstequalequal =firstequaletc))
	{
		
		ResFoundoperand:="≡"
		StringLeft,ResLeftString,String,% firstequalequal -1
		StringTrimLeft,ResRightString,String,% firstequalequal
		
		return true
	}
	if (firstenotequal!="" and (firstenotequal =firstequaletc))
	{
		
		ResFoundoperand:="≠"
		StringLeft,ResLeftString,String,% firstenotequal -1
		StringTrimLeft,ResRightString,String,% firstenotequal
		
		return true
	}
	if (firstplus!="" and (firstplus =firstplusminus))
	{
		
		ResFoundoperand=+
		StringLeft,ResLeftString,String,% firstplus -1
		StringTrimLeft,ResRightString,String,% firstplus
		
		return true
	}
	if (firstminus!=""  and (firstminus =firstplusminus))
	{
		ResFoundoperand=-
		StringLeft,ResLeftString,String,% firstminus -1
		StringTrimLeft,ResRightString,String,% firstminus
		return true
	}
	if (firstMult!="" and (firstMult = firstplusMultDiv))
	{
		
		ResFoundoperand=*
		StringLeft,ResLeftString,String,% firstMult -1
		StringTrimLeft,ResRightString,String,% firstMult
		
		return true
	}
	if (firstDiv!="" and (firstDiv = firstplusMultDiv))
	{
		ResFoundoperand=/
		StringLeft,ResLeftString,String,% firstDiv -1
		StringTrimLeft,ResRightString,String,% firstDiv
		return true
	}
	
	;MsgBox No operand found in "%String%" firstplus %firstplus% firstminus %firstminus% firstplusminus %firstplusminus%
	return false
	
}
