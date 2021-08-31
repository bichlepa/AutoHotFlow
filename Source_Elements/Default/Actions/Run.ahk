;Always add this element class name to the global list
x_RegisterElementClass("Action_Run")

;Element type of the element
Element_getElementType_Action_Run()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Run()
{
	return x_lang("Run")
}

;Category of the element
Element_getCategory_Action_Run()
{
	return x_lang("Process")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Run()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Run()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Run()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Run()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Run(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Command")})
	parametersToEdit.push({type: "Edit", id: "ToRun", content: ["String", "RawString"], contentID: "ToRunContent", contentDefault: "string", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Working directory")})
	parametersToEdit.push({type: "Radio", id: "WhichWorkingDir", default: "Default", result: "enum", choices: [x_lang("Working directory of the flow"), x_lang("Following working directory")], enum: ["Default", "Specified"]})
	parametersToEdit.push({type: "Folder", id: "WorkingDir", label: x_lang("Select a folder")})

	parametersToEdit.push({type: "Label", label: x_lang("Run mode")})
	parametersToEdit.push({type: "Radio", id: "RunMode", default: "Normal", result: "enum", choices: [x_lang("Run normally"), x_lang("Run maximized"), x_lang("Run minimized"), x_lang("Run hidden")], enum: ["Normal", "Max", "Min", "Hide"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Run(Environment, ElementParameters)
{
	return x_lang("Run") " - " ElementParameters.ToRun
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Run(Environment, ElementParameters, staticValues)
{	
	x_Par_Enable("WorkingDir", ElementParameters.WhichWorkingDir = "Specified")
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Run(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters, ["WorkingDir"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	switch (EvaluatedParameters.WhichWorkingDir)
	{
		case "Default":
		WorkingDir := x_GetWorkingDir(Environment)

		case "Specified":
		; evaluate more parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["WorkingDir"])
		if (EvaluatedParameters._error)
		{
			return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		}

		WorkingDir := EvaluatedParameters.WorkingDir
		
		; check whether working dir exists
		if not InStr(FileExist(WorkingDir), "D")
		{
			x_finish(Environment, "exception", x_lang("%1% '%2%' does not exist.", x_lang("Folder"), WorkingDir)) 
			return
		}
	}

	if (EvaluatedParameters.RunMode = "normal")
	{
		EvaluatedParameters.RunMode := ""
	}

	; run command
	run, % EvaluatedParameters.toRun, % WorkingDir, % "UseErrorLevel " EvaluatedParameters.RunMode, StartedProcessID
	
	; check for errors
	if (ErrorLevel)
	{
		x_finish(Environment, "exception", x_lang("Can't run '%1%'", EvaluatedParameters.ToRun))
		return
	}
	
	; set PID as thread variable
	x_setVariable(Environment, "a_pid", StartedProcessID, "thread")

	; finish
	x_finish(Environment,"normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Run(Environment, ElementParameters)
{
}






