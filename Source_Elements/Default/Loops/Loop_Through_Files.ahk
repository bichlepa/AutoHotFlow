;Always add this element class name to the global list
AllElementClasses.push("Loop_Loop_Through_Files")

;Element type of the element
Element_getElementType_Loop_Loop_Through_Files()
{
	return "Loop"
}

;Name of the element
Element_getName_Loop_Loop_Through_Files()
{
	return lang("Loop_Through_Files")
}

;Category of the element
Element_getCategory_Loop_Loop_Through_Files()
{
	return lang("File")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Loop_Loop_Through_Files()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Loop_Loop_Through_Files()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Loop_Loop_Through_Files()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Loop_Loop_Through_Files()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Loop_Loop_Through_Files(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: lang("File pattern")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file")})
	parametersToEdit.push({type: "Label", label: lang("Options")})
	parametersToEdit.push({type: "Radio", id: "OperateOnWhat", default: 1, choices: [lang("Operate on files"), lang("Operate on files and folders"), lang("Operate on folders")], result: "enum", enum: ["Files", "FilesAndFolders", "Folders"]})
	parametersToEdit.push({type: "Checkbox", id: "Recurse", default: 0, label: lang("Recurse subfolders into")})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Loop_Loop_Through_Files(Environment, ElementParameters)
{
	return lang("Loop_Through_Files") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Loop_Loop_Through_Files(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Loop_Loop_Through_Files(Environment, ElementParameters)
{
	entryPoint := x_getEntryPoint(environment)
	
	if (entryPoint = "Head") ;Initialize loop
	{
		EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		
		if (EvaluatedParameters.OperateOnWhat="Files")
			operation:="F"
		else if (EvaluatedParameters.OperateOnWhat="FilesAndFolders")
			operation:="FD"
		else if (EvaluatedParameters.OperateOnWhat="Folders")
			operation:="D"
		
		if (EvaluatedParameters.Recurse)
			recurse:="R"
		
		tempPath:=x_GetFullPath(environment, EvaluatedParameters.file)
		
		tempError:=false
		CurrentList:=Object()
		tempFound:=false
		
		Loop,files,%tempPath%,% operation recurse
		{
			tempFound:=true
			tempOneFile:=Object()
			
			tempOneFile.Insert("A_LoopFileName",A_LoopFileName)
			tempOneFile.Insert("A_LoopFileExt",A_LoopFileExt)
			tempOneFile.Insert("A_LoopFileFullPath",A_LoopFileFullPath)
			tempOneFile.Insert("A_LoopFileLongPath",A_LoopFileLongPath)
			tempOneFile.Insert("A_LoopFileShortPath",A_LoopFileShortPath)
			tempOneFile.Insert("A_LoopFileShortName",A_LoopFileShortName)
			tempOneFile.Insert("A_LoopFileDir",A_LoopFileDir)
			tempOneFile.Insert("A_LoopFileTimeModified",A_LoopFileTimeModified)
			tempOneFile.Insert("A_LoopFileTimeCreated",A_LoopFileTimeCreated)
			tempOneFile.Insert("A_LoopFileTimeAccessed",A_LoopFileTimeAccessed)
			tempOneFile.Insert("A_LoopFileAttrib",A_LoopFileAttrib)
			tempOneFile.Insert("A_LoopFileSize",A_LoopFileSize)
			tempOneFile.Insert("A_LoopFileSizeKB",A_LoopFileSizeKB)
			tempOneFile.Insert("A_LoopFileSizeMB",A_LoopFileSizeMB)
			SplitPath, A_LoopFileLongPath , , , , OutNameNoExt
			tempOneFile.Insert("A_LoopFileNameNoExt",OutNameNoExt)
			
			CurrentList.push(tempOneFile)
		}
		
		if (CurrentList.HasKey(1))
		{
			x_SetVariable(Environment, "A_Index", 1, "loop")
			x_SetVariable(Environment, "A_LoopCurrentList", CurrentList, "loop", true)
			
			tempOneFile:=CurrentList[1]
			for onekey, oneValue in tempOneFile
			{
				x_SetVariable(Environment, onekey, oneValue, "loop")
			}
			
			x_finish(Environment, "head")
		}
		else
		{
			x_finish(Environment, "tail") ;Leave the loop
		}
	}
	else if (entryPoint = "Tail") ;Continue loop
	{
		CurrentList := x_GetVariable(Environment, "A_LoopCurrentList", true)
		index := x_GetVariable(Environment, "A_Index")
		index++
		
		if (CurrentList.haskey(index))
		{
			x_SetVariable(Environment, "A_Index", index, "loop")
			tempOneFile:=CurrentList[index]
			for onekey, oneValue in tempOneFile
			{
				x_SetVariable(Environment, onekey, oneValue, "loop")
			}
			
			x_finish(Environment, "head") ;Continue with next iteration
		}
		else
		{
			x_finish(Environment, "tail") ;Leave the loop
		}
		
	}
	else if (entryPoint = "Break") ;Break loop
	{
		x_finish(Environment, "tail") ;Leave the loop
		
	}
	else
	{
		;This should never happen, but I suggest to keep this code for catching bugs in AHF.
		x_finish(Environment, "exception", lang("No information whether the connection leads into head or tail"))
	}
	
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Loop_Loop_Through_Files(Environment, ElementParameters)
{
}






