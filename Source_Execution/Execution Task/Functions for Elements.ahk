
;This file provides functions which can be accessed while executing the elements.



x_replaceVariables(Environment, String, Type = "normal")
{
	global
	return Var_replaceVariables(Environment, String, Type)
}
x_EvaluateExpression(Environment, String)
{
	global
	return Var_EvaluateExpression(Environment, String)
}
x_CheckVariableName(VarName)
{
	return Var_CheckName(VarName)
}
x_GetVariable(Environment, Varname, Type = "normal")
{
	global
	return Var_Get(Environment, Varname, Type)
}
x_SetVariable(Environment, Varname, Value, Type = "normal")
{
	global
	return Var_Set(Environment, Varname, Value, Type)
}
x_finish(Environment, Result, Message = "")
{
	global
	Environment.State:="finished"
	Environment.result:=Result
	Environment.message:=Message
	_flows[Environment.FlowID].allElements[Environment.ElementID].state:="finished"
	_flows[Environment.FlowID].allElements[Environment.ElementID].lastrun:=a_tickcount
	_flows[Environment.FlowID].draw.mustDraw:=true
}
