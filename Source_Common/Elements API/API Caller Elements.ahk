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
x_ExportAllInstanceVars(Environment)
{
}
x_ImportInstanceVars(Environment, p_VarsToImport)
{
}

x_GetListOfFlowNames()
{
	global _flows
	;Search for all flowNames
	choices:=object()
	for oneFlowID, oneFlow in _flows
	{
		choices.push(oneFlow.name)
	}
	return choices
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

x_Par_Disable(Environment,p_ParameterID, p_TrueOrFalse = True)
{
	return ElementSettings.field.enable(p_ParameterID,not p_TrueOrFalse)
}
x_Par_Enable(Environment,p_ParameterID, p_TrueOrFalse = True)
{
	return ElementSettings.field.enable(p_ParameterID,p_TrueOrFalse)
}
x_Par_SetValue(Environment,p_ParameterID, p_Value)
{
	return ElementSettings.field.setvalue(p_Value,p_ParameterID)
}
x_Par_GetValue(Environment,p_ParameterID)
{
	return ElementSettings.field.getvalue(p_ParameterID)
}

x_FlowEnableByName(Environment, p_FlowName)
{
}
x_FlowDisableByName(Environment, p_FlowName)
{
}
x_FlowExistsByName(Environment, p_FlowName)
{	
}

x_FlowExecuteByName(Environment, p_FlowName, p_Variables, p_CallBackFunction ="")
{
}
x_isFlowEnabledByName(Environment, p_FlowName)
{
}
x_isFlowExecutingByName(Environment, p_FlowName)
{
}