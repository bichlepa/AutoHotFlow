;This file provides functions which can be accessed while executing the elements.



x_replaceVariables(Environment, String)
{
}
x_EvaluateExpression(Environment, String)
{
}
x_CheckVariableName(VarName)
{
}
x_GetVariable(Environment, Varname, p_hidden = False)
{
}
x_getVariableType(Environment, Varname, p_hidden = False)
{
}
x_SetVariable(Environment, p_Varname, p_Value, p_destination="", p_hidden = False)
{
}
x_DeleteVariable(Environment, Varname, p_hidden = False)
{
}

x_GetVariableLocation(Environment, Varname, p_hidden = False)
{
}


x_finish(Environment, Result, Message = "")
{
}
x_log(Environment, LoggingText, loglevel = 2)
{
}
x_NewUniqueExecutionID(Environment)
{
}
x_GetMyUniqueExecutionID(Environment)
{
}
x_DeleteMyUniqueExecutionID(Environment)
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
x_GetMyElementID(Environment)
{
}
x_GetMyFlowID(Environment)
{
}
x_GetMyFlowName(Environment)
{
}
x_GetAllMyFlowTriggerNames(Environment)
{
}
x_GetAllMyFlowManualTriggerNames(Environment)
{
}
x_GetAllManualTriggerNamesOfFlowByName(p_FlowName)
{
}
x_getAllElementsOfClass(Environment, p_Class)
{
}

x_GetListOfFlowNames()
{
}


x_ExecuteInNewThread(Environment, p_uniqueID, p_functionObject, p_Code, p_VarsToImport, p_VarsToExport)
{
	
}
x_trigger(Environment, triggerVars="")
{
	
}
x_getEntryPoint(Environment)
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
}
x_Par_Enable(Environment,p_ParameterID, p_TrueOrFalse = True)
{
}
x_Par_SetValue(Environment,p_ParameterID, p_Value)
{
}
x_Par_GetValue(Environment,p_ParameterID)
{
}
x_Par_SetChoices(Environment,p_ParameterID, p_Choices)
{
}
x_FlowEnableByName(Environment, p_FlowName)
{
}
x_FlowDisableByName(Environment, p_FlowName)
{
}
x_FlowStopByName(Environment, p_FlowName)
{
}
x_FlowExecuteByName(Environment, p_FlowName, p_TriggerName = "", p_Variables ="", p_CallBackFunction ="")
{
}
x_FlowExistsByName(Environment, p_FlowName)
{	
}
x_isFlowEnabledByName(Environment, p_FlowName)
{
}
x_isFlowExecutingByName(Environment, p_FlowName)
{
}
x_InstanceStop(Environment)
{
}
x_GetThreadCountInCurrentInstance(Environment)
{
}
x_randomPhrase()
{
	return randomPhrase()
}
x_ConvertObjToString(p_Value)
{
	if IsObject(p_Value)
		return strobj(p_Value)
}
x_ConvertStringToObj(p_Value)
{
	if not IsObject(p_Value)
		return strobj(p_Value)
}
x_ConvertStringToObjOrObjToString(p_Value)
{
	return strobj(p_Value)
}
x_GetAllMyFlowManualTriggers(Environment)
{
}

x_GetFullPath(Environment, p_Path)
{
}

x_ExecuteInNewThread_finishedExecution(p_uniqueID)
{
}


x_GetAllManualTriggersOfFlowByName(p_FlowName)
{
}


x_isTriggerEnabledByName(Environment, p_FlowName, p_TriggerName="")
{
}


x_TriggerEnableByName(Environment, p_FlowName, p_TriggerName="")
{
}


x_TriggerDisableByName(Environment, p_FlowName, p_TriggerName="")
{
}
