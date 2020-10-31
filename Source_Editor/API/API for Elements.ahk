;This file provides functions which can be accessed by the code inside the elements.


x_RegisterElementClass(p_class)
{
	return xx_RegisterElementClass(p_class)
}

x_GetVariable(Environment, p_Varname, p_hidden = False)
{
	return xx_GetVariable(Environment, p_Varname, p_hidden)
}
x_getVariableType(Environment, p_Varname, p_hidden = False)
{
	return xx_getVariableType(Environment, p_Varname, p_hidden)
}
x_SetVariable(Environment, p_Varname, p_Value, p_destination="", p_hidden = False)
{
	return xx_SetVariable(Environment, p_Varname, p_Value, p_destination, p_hidden)
}
x_DeleteVariable(Environment, p_Varname, p_hidden = False)
{
	return xx_DeleteVariable(Environment, p_Varname, p_hidden)
}

x_GetVariableLocation(Environment, p_Varname, p_hidden = False)
{
	return xx_GetVariableLocation(Environment, p_Varname, p_hidden)
}

x_replaceVariables(Environment, p_String, p_pars ="")
{
	return xx_replaceVariables(Environment, p_String, p_pars) 
}
x_EvaluateExpression(Environment, p_String)
{
	return xx_EvaluateExpression(Environment, p_String)
}
x_CheckVariableName(p_VarName)
{
	return xx_CheckVariableName(p_VarName)
}

x_AutoEvaluateParameters(Environment, ElementParameters, p_skipList = "")
{
	return xx_AutoEvaluateParameters(Environment, ElementParameters, p_skipList)
}
x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, p_ParametersToEvaluate)
{
	return xx_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, p_ParametersToEvaluate)
}
x_AutoEvaluateOneParameter(EvaluatedParameters, Environment, ElementParameters, oneParID, onePar = "")
{
	return xx_AutoEvaluateOneParameter(EvaluatedParameters, Environment, ElementParameters, oneParID, onePar)
}

x_GetListOfAllVars(Environment)
{
	return xx_GetListOfAllVars(Environment)
}

x_GetListOfLoopVars(Environment)
{
	return xx_GetListOfLoopVars(Environment)
}
x_GetListOfThreadVars(Environment)
{
	return xx_GetListOfThreadVars(Environment)
}
x_GetListOfInstanceVars(Environment)
{
	return xx_GetListOfInstanceVars(Environment)
}
x_GetListOfStaticVars(Environment)
{
	return xx_GetListOfStaticVars(Environment)
}
x_GetListOfGlobalVars(Environment)
{
	return xx_GetListOfGlobalVars(Environment)
}
x_ExportAllInstanceVars(Environment)
{
	return xx_ExportAllInstanceVars(Environment)
}
x_ImportInstanceVars(Environment, p_VarsToImport)
{
	return xx_ImportInstanceVars(Environment, p_VarsToImport)
}

x_finish(Environment, p_Result, p_Message = "")
{
	return xx_finish(Environment, p_Result, p_Message)
}
x_getEntryPoint(Environment)
{
	return xx_getEntryPoint(Environment)
}
x_InstanceStop(Environment)
{
	return xx_InstanceStop(Environment)
}
x_GetMyUniqueExecutionID(Environment)
{
	return xx_GetMyUniqueExecutionID(Environment)
}
x_GetMyEnvironmentFromExecutionID(p_ExecutionID)
{
	return xx_GetMyEnvironmentFromExecutionID(p_ExecutionID)
}
x_SetExecutionValue(Environment, p_name, p_Value)
{
	return xx_SetExecutionValue(Environment, p_name, p_Value)
}
x_GetExecutionValue(Environment, p_name)
{
	return xx_GetExecutionValue(Environment, p_name)
}
x_SetTriggerValue(Environment, p_name, p_Value)
{
	return xx_SetTriggerValue(Environment, p_name, p_Value)
}
x_GetTriggerValue(Environment, p_name)
{
	return xx_GetTriggerValue(Environment, p_name)
}
x_NewFunctionObject(Environment, p_ToCallFunction, params*)
{
	return xx_NewFunctionObject(Environment, p_ToCallFunction, params*)
}
x_GetThreadCountInCurrentInstance(Environment)
{
	return xx_GetThreadCountInCurrentInstance(Environment)
}
x_ExecuteInNewAHKThread(Environment, p_functionObject, p_Code, p_VarsToImport, p_VarsToExport)
{
	return xx_ExecuteInNewAHKThread(Environment, p_functionObject, p_Code, p_VarsToImport, p_VarsToExport)
}
x_ExecuteInNewAHKThread_stop(Environment)
{
	return xx_ExecuteInNewAHKThread_stop(Environment)
}

x_trigger(Environment, params = "")
{
	return xx_trigger(Environment, params)
}
x_enabled(Environment, Result, Message = "")
{
	return xx_enabled(Environment, Result, Message)
}
x_disabled(Environment, Result, Message = "")
{
	return xx_disabled(Environment, Result, Message)
}

x_GetMyFlowID(Environment)
{
	return xx_GetMyFlowID(Environment)
}
x_GetMyFlowName(Environment)
{
	return xx_GetMyFlowName(Environment)
}

x_GetMyElementID(Environment)
{
	return xx_GetMyElementID(Environment)
}

x_getFlowIDByName(p_FlowName)
{
	return xx_getFlowIDByName(p_FlowName)
}



x_FlowExistsByName(p_FlowName)
{
	return xx_FlowExistsByName(p_FlowName)
}

x_FlowExists(p_FlowID)
{
	return xx_FlowExists(p_FlowID)
}


x_isFlowEnabled(p_FlowID)
{
	return xx_isFlowEnabled(p_FlowID)
}



x_isFlowExecuting(p_FlowID)
{
	return xx_isFlowExecuting(p_FlowID)
}


x_FlowEnable(p_FlowID)
{
	return xx_FlowEnable(p_FlowID)

}


x_FlowDisable(p_FlowID)
{
	return xx_FlowDisable(p_FlowID)
	
}

x_FlowStop(p_FlowID)
{
	return xx_FlowStop(p_FlowID)
}


x_GetListOfFlowNames()
{
	return xx_GetListOfFlowNames()
}

x_GetListOfFlowIDs()
{
	return xx_GetListOfFlowIDs()
}


x_getAllElementIDsOfType(p_FlowID, p_Type)
{
	return xx_getAllElementIDsOfType(p_FlowID, p_Type)
}

x_getAllElementIDsOfClass(p_FlowID, p_Class)
{
	return xx_getAllElementIDsOfClass(p_FlowID, p_Class)
}

x_getElementPars(p_FlowID, p_ElementID)
{
	return xx_getElementPars(p_FlowID, p_ElementID)
}
x_getElementName(p_FlowID, p_ElementID)
{
	return xx_getElementName(p_FlowID, p_ElementID)
}
x_getElementClass(p_FlowID, p_ElementID)
{
	return xx_getElementClass(p_FlowID, p_ElementID)
}

x_getMyElementPars(Environment)
{
	return xx_getMyElementPars(Environment)
}


x_ManualTriggerExist(p_FlowID, p_TriggerName = "")
{
	return xx_ManualTriggerExist(p_FlowID, p_TriggerName)
}

x_isManualTriggerEnabled(p_FlowID, p_TriggerName="")
{
	return xx_isManualTriggerEnabled(p_FlowID, p_TriggerName)
}

x_ManualTriggerEnable(p_FlowID, p_TriggerName="")
{
	return xx_ManualTriggerEnable(p_FlowID, p_TriggerName)
}

x_ManualTriggerDisable(p_FlowID, p_TriggerName="")
{
	return xx_ManualTriggerDisable(p_FlowID, p_TriggerName)
}

x_ManualTriggerExecute(p_FlowID, p_TriggerName = "", p_Variables ="", p_CallBackFunction ="")
{
	return xx_ManualTriggerExecute(p_FlowID, p_TriggerName, p_Variables, p_CallBackFunction)
}

; only in editor
; disable the gui elements for a parameter in the gui
x_Par_Disable(p_ParameterID, p_TrueOrFalse = True)
{
	return ElementSettings.field.enable(p_ParameterID,not p_TrueOrFalse)
}
; enable the edit elements for a parameter in the gui
x_Par_Enable(p_ParameterID, p_TrueOrFalse = True)
{
	return ElementSettings.field.enable(p_ParameterID,p_TrueOrFalse)
}
; set a parameter value in the gui
x_Par_SetValue(p_ParameterID, p_Value)
{
	return ElementSettings.field.setvalue(p_Value,p_ParameterID)
}
; get a parameter value from the gui
x_Par_GetValue(p_ParameterID)
{
	return ElementSettings.field.getvalue(p_ParameterID)
}
; set choices of a dropdown for a parameter in the gui
x_Par_SetChoices(p_ParameterID, p_Choices)
{
	return ElementSettings.field.setChoices(p_Choices,p_ParameterID)
}
; set a label value in the gui
x_Par_SetLabel(p_ParameterID, p_Label)
{
	return ElementSettings.field.setLabel(p_Label,p_ParameterID)
}
; returns whether the call of the element function "Element_CheckSettings_...()" is performed the first time after opening the element parametration gui
x_FirstCallOfCheckSettings(Environment)
{
	return _getElementProperty(Environment.FlowID, Environment.ElementID, "FirstCallOfCheckSettings")
}


x_lang(key, params*)
{
	return xx_lang(key, params*)
}
x_randomPhrase()
{
	return xx_randomPhrase()
}
x_ConvertObjToString(p_Value)
{
	return xx_ConvertObjToString(p_Value)
}
x_ConvertStringToObj(p_Value)
{
	return xx_ConvertStringToObj(p_Value)
}



x_log(Environment, LoggingText, loglevel = 2)
{
	return xx_log(Environment, LoggingText, loglevel)
}

x_GetFullPath(Environment, p_Path)
{
	return xx_GetFullPath(Environment, p_Path)
}

x_GetWorkingDir(Environment)
{
	return xx_GetWorkingDir(Environment)
}




x_EvaluateScript(Environment, p_script)
{
	return xx_EvaluateScript(Environment, p_script)
}


x_TriggerInNewAHKThread(Environment, p_Code, p_VarsToImport, p_VarsToExport)
{
	return xx_TriggerInNewAHKThread(Environment, p_Code, p_VarsToImport, p_VarsToExport)
}


x_TriggerInNewAHKThread_GetExportedValues(Environment)
{
	return xx_TriggerInNewAHKThread_GetExportedValues(Environment)
}


x_TriggerInNewAHKThread_Stop(Environment)
{
	return xx_TriggerInNewAHKThread_Stop(Environment)
}

; only in editor
; opens the assistant for easy retrieving of window parameter
x_assistant_windowParameter(neededInfo)
{
	assistant_GetWindowInformation(neededInfo)
}

; opens the assistant for easy retrieving of mouse coordinates
x_assistant_MouseTracker(neededInfo)
{
	assistant_MouseTracker(neededInfo)
}

; opens the assistant for easy choose of a color
x_assistant_ChooseColor(neededInfo)
{
	assistant_ChooseColor(neededInfo)
}


x_GetAhfPath()
{
	return xx_GetAhfPath()
}

x_isWindowsStartup()
{
	return xx_isWindowsStartup()
}
