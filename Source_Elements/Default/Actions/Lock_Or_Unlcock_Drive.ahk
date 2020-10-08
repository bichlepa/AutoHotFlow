;Always add this element class name to the global list
x_RegisterElementClass("Action_Lock_Or_Unlock_Drive")

;Element type of the element
Element_getElementType_Action_Lock_Or_Unlock_Drive()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Lock_Or_Unlock_Drive()
{
	return lang("Lock_Or_Unlock_Drive")
}

;Category of the element
Element_getCategory_Action_Lock_Or_Unlock_Drive()
{
	return lang("Drive")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Lock_Or_Unlock_Drive()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Lock_Or_Unlock_Drive()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Lock_Or_Unlock_Drive()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Lock_Or_Unlock_Drive()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Lock_Or_Unlock_Drive(Environment)
{
	static listOfdrives
	parametersToEdit:=Object()
	
	
	listOfdrives:=Object()
	driveget, tempdrives,list,CDROM
	
	loop,parse,tempdrives
	{
		if a_index=1
			defaultdrive:=A_LoopField ":"
		listOfdrives.push(A_LoopField ":")
	}
	
	
	parametersToEdit.push({type: "Label", label: lang("Action")})
	parametersToEdit.push({type: "Radio", id: "WhatDo", default: 1, choices: [lang("Lock drive"), lang("Unlock drive")], result: "enum", enum: ["Lock", "Unlock"]})
	
	parametersToEdit.push({type: "Label", label: lang("Drive letter")})
	parametersToEdit.push({type: "ComboBox", id: "DriveLetter", content: "string", default: defaultdrive, choices: listOfdrives, result: "name"})
	
	parametersToEdit.updateOnEdit:=true
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Lock_Or_Unlock_Drive(Environment, ElementParameters)
{
	return lang("Lock_Or_Unlock_Drive") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Lock_Or_Unlock_Drive(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Lock_Or_Unlock_Drive(Environment, ElementParameters)
{
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}


	x_SetVariable(Environment,Varname,VarValue) ;Example
	MsgBox Hello World
	x_finish(Environment,"normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Lock_Or_Unlock_Drive(Environment, ElementParameters)
{
}






