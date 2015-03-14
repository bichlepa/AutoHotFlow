
Create a new AHK Script that has the name of the Action. The name must be like a variable name! This name will not be displayed.
Include the file in the main script AutoHotFlow.ahk



You need following functions. The +ElementName+ needs to be replaced by the name of the Action:

getParameters+ElementType++ElementName+()
	The parameters that the Action needs are saved here. They are mainly needed for the Settings window, and also for saving and loading the flows.
	It is an object, therefore there are square brackets that contain comma separated entries.
	An entry divided by | and is constructed as following:
		Type of the parameter | Standard value | Name of the Action | Label
			- Type of the parameter:
				Label - It needs only the first two parameters: "Label" | Text of Label
				Text - It needs the first three parameters
				Number - It needs the first three parameters
				Checkbox - It needs the first four parameters: "Checkbox" | Enabled (0 or 1) | Name | Label
				Hotkey - It needs the first three parameters
				NewFile - It needs the first four parameters: "NewFile" | standard value | Name | Label
				Button - It need the first, second, and fourth parameters: "Button" | goto-label || Label
			- Standard value:
				Nothing to say
			- Name of the Action:
				The name must be like a variable name!
			- Label: 
				Nothing to say
			- goto-label:
				To which label the script should jump to when user presses the button.
	The parameter must not have those names:
		FinishedRunning,result,x,y,name,CountOfParts,part1...part5,ClickPriority,to,from,marked
		

getName+ElementType++ElementName+()
	This returns the name of the Action that will be displayed when the user selects a new Action. 

getCategory+ElementType++ElementName+()
	This returns the category of the Action in whitch the Element will be displayed when the user selects a new Action. 


GenerateName+ElementType++ElementName+(ID)
	This functions generates the standard name that will be displayed for the function.
	It gets the ID of the Action so it can get all the parameters. Therefore this function must be global.
	It returns the generated name.



For Actions and Elements you also need following functions:
run+ElementType++ElementName+(ID)
	This is the code that will be executed when it is started.
	It gets the ID of the Action so it can get all the parameters. Therefore this function must be global.
		Example: %ID%title contains the parameter title
	When the action or condition is complete it must set the variable:
		%ID%FinishedRunning=true
	If you want to support variables (user can define variables instead of a string) just use the function replaceVariables(String)
		Example: replaceVariables(%ID%par1)
	
	To set a variable use
		setVariable(VarName,Value)
	To get a variable use
		returnedValue:=getVariable(Varname)
	
	
	The confirmation dialog must write "yes" or "no" in the variable %ID%result before finishing.
		%ID%result=yes






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
	
	Trigger Issues:
		To let the main Script know that it should start the flow, following:
			There is a hidden window with a Edit field if you change it to "run" it will start the flow. You can do it by following lines of code:
				DetectHiddenWindows, On
				ControlSetText,Edit1,Run,CommandFromTriggerWindow
		It is also necessary that the external script can be stopped. For this create a hidden window with a Edit field.
			Following code may be used:
				gui,45:default
				gui,new,,CommandWindowFor%ID%
				gui,add,edit,vcommandFortrigger gCommandForTrigger
				... your event detection code
				return
				CommandForTrigger:
				gui,submit
				if CommandForTrigger=exit
				{
					exitapp
				}
	


