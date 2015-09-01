I wrote this instruction because I thought it might help you with creating new elements.
But now my advise is: If you want to create a new element, copy the mostly similar element and modify it.
If you have questions, don't hesitate to contact me!
	
You can still read my old instruction:


Create a new AHK Script that has the name of the Action. The name must be like a variable name! This name will not be displayed.
Include the file in the main script AutoHotFlow.ahk



You need following functions. The +ElementName+ needs to be replaced by the name of the Action:

getParameters+ElementType++ElementName+()
	The parameters that the Action needs are saved here. They are mainly needed for the Settings window, and also for saving and loading the flows.
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
	
	;Drop down
	parametersToEdit.push({type: "DropDown", id: "Button", default: 1, choices: [lang("Left button"), lang("Right button"), lang("Middle Button"), lang("Wheel up"), lang("Wheel down"), lang("Wheel left"), lang("Wheel right"), lang("4th mouse button (back)"), lang("5th mouse button (forward)")]
	
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



For Actions and Elements you also need following functions:
run+ElementType++ElementName+(ID)
	This is the code that will be executed when it is started.
	It gets the ID of the Action so it can get all the parameters. Therefore this function must be global.
		Example: %ID%title contains the parameter title
	When the action or condition is complete it must use the function:
		MarkThatElementHasFinishedRunning(...)
	If you want to support variables (user can define variables instead of a string) just use the function replaceVariables(String)
		Example: replaceVariables(%ID%par1)
	
	To set a variable use
		v_SetVariable(...)
	To get a variable use
		returnedValue:=v_getVariable(...)
	
	






For Triggers you also need following functions:
	
EnableTrigger+triggername+(ID)
	This is the code for enabling the trigger.
	It must however detect when it should be triggered and be able to start the flow.
	It gets the ID of the Trigger so it can get all the parameters. Therefore this function must be global.
		Example: %ID%title contains the parameter title
	Examples how it can start the flow:
		- Go to the label Start
			Goto, Start
		- An external script 

DisableTrigger+triggername+(ID)
	This is the code for disabling the trigger.
	It must however stop event detection and not trigger anymore.
	It gets the ID of the Trigger so it can get all the parameters. Therefore this function must be global.
	If you use external script as described above, it must be stopped.
		You may use following lines of code:
			DetectHiddenWindows, On
			ControlSetText,Edit1,exit,CommandWindowFor%ID%



An external script may be needed if the process of the element may interfere with the main script or stop everything else (like a MsgBox or Winwait).
	Wite via FileAppend a script in the folder "Generated Scripts"
	Execute the script afterwards.
	
	


