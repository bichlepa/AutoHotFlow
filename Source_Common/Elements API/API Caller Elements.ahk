;This file provides functions which can be accessed while executing the elements.




x_replaceVariables(Environment, String, Type = "normal")
{
}
x_EvaluateExpression(Environment, String)
{
}
x_CheckVariableName(VarName)
{
}
x_GetVariable(Environment, Varname, Type = "normal")
{
}
x_getVariableType(Environment, Varname)
{
}
x_SetVariable(Environment, Varname, Value, Type = "normal", destination="")
{
}
x_DeleteVariable(Environment, Varname)
{
}


x_GetVariableLocation(Environment, Varname)
{
}
x_finish(Environment, Result, Message = "")
{
}

x_NewUniqueExecutionID(Environment)
{
}
x_GetMyUniqueExecutionID(Environment)
{
}
x_DeleteMyUniqueExecutionID(p_ExecutionID)
{
}
x_GetMyEnvironmentFromExecutionID(p_ExecutionID)
{
}
x_SetExecutionValue(p_ExecutionID, p_name, p_Value)
{
}
x_GetExecutionValue(p_ExecutionID, p_name)
{
}

x_NewExecutionFunctionObject(Environment, p_ExecutionID, p_ToCallFunction, params*)
{
	
}
x_GetListOfAllVars(Environment)
{
}
x_GetListOfLoopVars(Environment)
{
}
x_GetListOfThreadVars(Environment)
{
}
x_GetListOfInstanceVars(Environment)
{
}
x_GetListOfStaticVars(Environment)
{
}
x_GetListOfGlobalVars(Environment)
{
}

x_trigger(Environment, triggerVars="")
{
	
}
x_enabled(Environment, Result, Message = "")
{
	
}
x_disabled(Environment, Result, Message = "")
{
	
}

x_Par_Disable(Environment,p_ParToDisable, p_TrueOrFalse = True)
{
	ElementSettings.field.enable(p_ParToDisable,not p_TrueOrFalse)
}
x_Par_Enable(Environment,p_ParToDisable, p_TrueOrFalse = True)
{
	ElementSettings.field.enable(p_ParToDisable,p_TrueOrFalse)
}