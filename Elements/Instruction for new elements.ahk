
My first advise is: If you want to create a new element, copy the mostly similar element and modify it.
If you have questions, read the following notes and don't hesitate to contact me (autohotflow@arcor.de)!
	

Create a new AHK Script or copy one element name it. The name must be like a variable name! This name will not be displayed.
Include the file in the main script AutoHotFlow.ahk



You need following functions. The +ElementName+ needs to be replaced by the name of the Element:

getParameters+ElementType++ElementName+()
	The parameters that the Element needs are saved here. They are mainly needed for the Settings window, and also for saving and loading the flows.
	It is an array object, which conatins associative arrays.
	First line is creation of an empty object: parametersToEdit:=Object()
	The other lines add an entry to the object. Each entry is a GUI element.
	Examples: You can add following lines to any element to see all them in the GUI.
	;Labels:
	parametersToEdit.push({type: "Label", label: lang("List variable name")})
	parametersToEdit.push({type: "Label", label: lang("Coordinates") lang("(x,y)"), size: "small"})
	
	;Edits:
	parametersToEdit.push({type: "Edit", id: "Varname", default: "List", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "edit", id: "Position", default: 2, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "edit", id: "Wintitle", content: "String"})
	parametersToEdit.push({type: "Edit", id: "Section", default: "section", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Edit", id: "VarValues", default: "Added Element 1`nAdded Element 2", multiline: true, content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Edit", id: ["Xpos", "Ypos"], default: [10, 20], content: "Expression", WarnIfEmpty: true})
	
	;If an edit can contain either an expression or a String (user should decide), use following two lines:
	parametersToEdit.push({type: "Radio", id: "isExpression", default: 1, choices: [lang("This is a value"), lang("This is a variable name or expression")]})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "New element", content: "StringOrExpression", contentParID: "isExpression", WarnIfEmpty: true})
	
	;Checkbox
	parametersToEdit.push({type: "Checkbox", id: "DelimiterSpace", default: 0, label: lang("Use space as delimiter")})
	;Radio
	parametersToEdit.push({type: "Radio", id: "NumberOfElements", default: 1, choices: [lang("Add one element"), lang("Add multiple elements")]})
	
	;Folder
	parametersToEdit.push({type: "Folder", id: "folder", label: lang("Select a folder")})
	
	;File
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file"), options: 8, filter: lang("Images and icons") " (*.gif; *.jpg; *.bmp; *.ico; *.cur; *.ani; *.png; *.tif; *.exif; *.wmf; *.emf; *.exe; *.dll; *.cpl; *.scr)"})
	
	;Drop down
	parametersToEdit.push({type: "DropDown", id: "Button", default: 1, choices: [lang("Left button"), lang("Right button"), lang("Middle Button"), lang("Wheel up"), lang("Wheel down"), lang("Wheel left"), lang("Wheel right"), lang("4th mouse button (back)"), lang("5th mouse button (forward)")]
	parametersToEdit.push({type: "DropDown", id: "TTSEngine", default: TTSDefaultLanguage, choices: TTSList, result: "name"})
	
	;Slider
	parametersToEdit.push({type: "Slider", id: "speed", default: 2, options: "Range0-100 tooltip"})
	
	The parameter id must not have those names:
		FinishedRunning,result,x,y,name,CountOfParts,part1...part5,ClickPriority,to,from,marked
		

getName+ElementType++ElementName+()
	This returns the name of the Action that will be displayed when the user selects a new Action. 

getCategory+ElementType++ElementName+()
	This returns the category of the Action in which the Element will be displayed when the user selects a new Action. 


GenerateName+ElementType++ElementName+(ID)
	This functions generates the standard name that will be displayed for the function.
	It gets the ID of the Action so it can get all the parameters. Therefore this function must be global.
	It returns the generated name.



For Actions, loops and Conditions you also need following functions:
run+ElementType++ElementName+(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	This is the code that will be executed when it is started.
	
	The function must have global variable access. It is recommendet to make all temporary used variables local.
	;Example:
	global
	local temp
	local filename
	
	To get parameter values use following examples
	;Access a parameter
	%ElementID%title ;"Title" is the parameter ID
		
	;Replace varialbes
	Content:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Content) ;"Content" is the parameter ID
	
	;Evaluate expression
	URL:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%URL) ;"URL" is the parameter ID
	
	
	
		
	Variables which can be edited by user manually (edit field in the GUI) should be proofed. 
	You may use following code.
	
	;Check variable name 
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",varname)) )
		return
	}
	
	;Check whether value is not empty
	if Position=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Position is not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is empty.",lang("Position")))
		return
	}
	
	;Check whether value is a number
	if temp is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Input number " temp " is not a number")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Input number '%1%'",temp)) )
		return
	}
	
	;Check whether the value is a list
	if (!(IsObject(tempObject)))
	{
		if tempObject=
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Waring! Variable '" Varname "' is empty. A new list will be created.")
			tempObject:=Object()
		}
		else
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable '" Varname "' is not empty and does not contain a list.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Variable '%1%' is not empty and does not contain a list.",Varname))
			return
		}
	}
	
	To get a variable's content use following examples:
	;Get a variable
	tempindex:=v_GetVariable(InstanceID,ThreadID,varname)
	;Get a loop variable
	tempindex:=v_GetVariable(InstanceID,ThreadID,"A_Index")
	
	To set a variable use following examples:
	;Set variable with value 5
	v_SetVariable(InstanceID,ThreadID,VarName,5) ;Variable "VarName" contains a variable name
	;Write a list into variable
	v_SetVariable(InstanceID,ThreadID,Varname,tempObject,"list")
	;Write a built in variable, beginning with "a_"
	v_SetVariable(InstanceID,ThreadID,"A_WindowID",tempWinid,,c_SetBuiltInVar)
	;Write a loop variable, beginning with "a_"
	v_SetVariable(InstanceID,ThreadID,"A_Index",1,,c_SetLoopVar)
	
	
	When the action or condition is complete it must use the function:
		MarkThatElementHasFinishedRunning(...)
	Examples:
	;Element finished normally
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	;Condition finished with result Yes
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"yes")
	
	;Element finished with an exception
	logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Position is not specified.") ;Log the error, so user will be able to find the reason
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is empty.",lang("Position"))) ;The last parameter is a message which is shown to the user if the element has no "exception" connection.
	return ;Return if an error occured
}
	






For Triggers you also need following functions:
	
EnableTrigger+triggername+(ElementID)
	This is the code for enabling the trigger.
	It must however detect when it should be triggered and be able to start the flow.
	It gets the ID of the Trigger so it can get all the parameters. Therefore this function must be global.
		Example: %ElementID%title contains the parameter title
	Examples how it can start the flow:
		- Go to the label Start
			Goto, Start
		- An external script 

DisableTrigger+triggername+(ElementID)
	This is the code for disabling the trigger.
	It must however stop event detection and not trigger anymore.
	It gets the ID of the Trigger so it can get all the parameters. Therefore this function must be global.
	If you use external script as described above, it must be stopped.
		You may use following lines of code:
			DetectHiddenWindows, On
			ControlSetText,Edit1,exit,CommandWindowFor%ID%



An external script may be needed if the process of the element may interfere with the main script or stop everything else (like a MsgBox or Winwait).
	Write via FileAppend a script in the folder "Generated Scripts"
	Execute the script afterwards.
	
	


