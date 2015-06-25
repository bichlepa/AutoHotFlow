iniAllLoops.="Loop_through_files|" ;Add this loop to list of all loops on initialisation

runLoopLoop_through_files(InstanceID,ThreadID,ElementID,ElementIDInInstance,HeadOrTail)
{
	global
	local tempPath
	local operateon
	local recurse
	local tempError
	local tempFound
	local tempFiles
	local tempOneFile
	local OutNameNoExt
	local OutDrive
	if HeadOrTail=Head ;Initialize loop
	{
		if %ElementID%OperateOnWhat=1
			operateOn=0
		else if %ElementID%OperateOnWhat=2
			operateOn=1
		else if %ElementID%OperateOnWhat=3
			operateOn=2
		
		if %ElementID%Recurse=0
			recurse=0
		else if %ElementID%Recurse=1
			recurse=1
		
		
		tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
		if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
			tempPath:=SettingWorkingDir "\" tempPath
		
		tempError:=false
		tempFiles:=Object()
		tempFound:=false
		
		Loop,%tempPath%,%operateOn%,%recurse%
		{
			;~ MsgBox %a_loopfilefullpath%
			if a_loopfilefullpath= ;If the file pattern isn't a file pattern, but maybe a number
			{
				tempError:=true
				break
			}
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
			
			tempFiles.Insert(tempOneFile)
		}
		
		if tempError
		{
			
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
		}
		else if tempFound
		{
			v_SetVariable(InstanceID,ThreadID,"A_LoopCurrentList",tempFiles,,c_SetLoopVar)
			v_SetVariable(InstanceID,ThreadID,"A_Index",1,,c_SetLoopVar)
			
			tempOneFile:=tempFiles[1]
			tempFiles.remove(1)
			v_SetVariable(InstanceID,ThreadID,"A_LoopFileName",tempOneFile["A_LoopFileName"],,c_SetLoopVar)
			v_SetVariable(InstanceID,ThreadID,"A_LoopFileExt",tempOneFile["A_LoopFileExt"],,c_SetLoopVar)
			v_SetVariable(InstanceID,ThreadID,"A_LoopFileFullPath",tempOneFile["A_LoopFileFullPath"],,c_SetLoopVar)
			v_SetVariable(InstanceID,ThreadID,"A_LoopFileLongPath",tempOneFile["A_LoopFileLongPath"],,c_SetLoopVar)
			v_SetVariable(InstanceID,ThreadID,"A_LoopFileShortPath",tempOneFile["A_LoopFileShortPath"],,c_SetLoopVar)
			v_SetVariable(InstanceID,ThreadID,"A_LoopFileShortName",tempOneFile["A_LoopFileShortName"],,c_SetLoopVar)
			v_SetVariable(InstanceID,ThreadID,"A_LoopFileDir",tempOneFile["A_LoopFileDir"],,c_SetLoopVar)
			v_SetVariable(InstanceID,ThreadID,"A_LoopFileTimeModified",tempOneFile["A_LoopFileTimeModified"],,c_SetLoopVar)
			v_SetVariable(InstanceID,ThreadID,"A_LoopFileTimeCreated",tempOneFile["A_LoopFileTimeCreated"],,c_SetLoopVar)
			v_SetVariable(InstanceID,ThreadID,"A_LoopFileTimeAccessed",tempOneFile["A_LoopFileTimeAccessed"],,c_SetLoopVar)
			v_SetVariable(InstanceID,ThreadID,"A_LoopFileAttrib",tempOneFile["A_LoopFileAttrib"],,c_SetLoopVar)
			v_SetVariable(InstanceID,ThreadID,"A_LoopFileSize",tempOneFile["A_LoopFileSize"],,c_SetLoopVar)
			v_SetVariable(InstanceID,ThreadID,"A_LoopFileSizeKB",tempOneFile["A_LoopFileSizeKB"],,c_SetLoopVar)
			v_SetVariable(InstanceID,ThreadID,"A_LoopFileSizeMB",tempOneFile["A_LoopFileSizeMB"],,c_SetLoopVar)
			v_SetVariable(InstanceID,ThreadID,"A_LoopFileNameNoExt",tempOneFile["A_LoopFileNameNoExt"],,c_SetLoopVar)
			
			
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normalHead")
		}
		else
		{
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normalTail")
		}
	}
	else if HeadOrTail=tail ;Continue loop
	{
		tempindex:=v_GetVariable(InstanceID,ThreadID,"A_Index")
		tempindex++
		v_SetVariable(InstanceID,ThreadID,"A_Index",tempindex,,c_SetLoopVar)
		
		tempFiles:=v_GetVariable(InstanceID,ThreadID,"A_LoopCurrentList")
		
		tempOneFile:=tempFiles[1]
		tempFiles.remove(1)
		v_SetVariable(InstanceID,ThreadID,"A_LoopFileName",tempOneFile["A_LoopFileName"],,c_SetLoopVar)
		v_SetVariable(InstanceID,ThreadID,"A_LoopFileExt",tempOneFile["A_LoopFileExt"],,c_SetLoopVar)
		v_SetVariable(InstanceID,ThreadID,"A_LoopFileFullPath",tempOneFile["A_LoopFileFullPath"],,c_SetLoopVar)
		v_SetVariable(InstanceID,ThreadID,"A_LoopFileLongPath",tempOneFile["A_LoopFileLongPath"],,c_SetLoopVar)
		v_SetVariable(InstanceID,ThreadID,"A_LoopFileShortPath",tempOneFile["A_LoopFileShortPath"],,c_SetLoopVar)
		v_SetVariable(InstanceID,ThreadID,"A_LoopFileShortName",tempOneFile["A_LoopFileShortName"],,c_SetLoopVar)
		v_SetVariable(InstanceID,ThreadID,"A_LoopFileDir",tempOneFile["A_LoopFileDir"],,c_SetLoopVar)
		v_SetVariable(InstanceID,ThreadID,"A_LoopFileTimeModified",tempOneFile["A_LoopFileTimeModified"],,c_SetLoopVar)
		v_SetVariable(InstanceID,ThreadID,"A_LoopFileTimeCreated",tempOneFile["A_LoopFileTimeCreated"],,c_SetLoopVar)
		v_SetVariable(InstanceID,ThreadID,"A_LoopFileTimeAccessed",tempOneFile["A_LoopFileTimeAccessed"],,c_SetLoopVar)
		v_SetVariable(InstanceID,ThreadID,"A_LoopFileAttrib",tempOneFile["A_LoopFileAttrib"],,c_SetLoopVar)
		v_SetVariable(InstanceID,ThreadID,"A_LoopFileSize",tempOneFile["A_LoopFileSize"],,c_SetLoopVar)
		v_SetVariable(InstanceID,ThreadID,"A_LoopFileSizeKB",tempOneFile["A_LoopFileSizeKB"],,c_SetLoopVar)
		v_SetVariable(InstanceID,ThreadID,"A_LoopFileSizeMB",tempOneFile["A_LoopFileSizeMB"],,c_SetLoopVar)
		v_SetVariable(InstanceID,ThreadID,"A_LoopFileNameNoExt",tempOneFile["A_LoopFileNameNoExt"],,c_SetLoopVar)
		
		if isobject(tempOneFile)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normalHead")
		else
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normalTail")
	}
	else if HeadOrTail=break ;Break loop
	{
		
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normalTail")
		
	}
	else
		MsgBox Internal Error. Loop should be executed but there is no information about the connection lead into head or tail.

	

	return
}
getNameLoopLoop_through_files()
{
	return lang("Loop_through_files")
}
getCategoryLoopLoop_through_files()
{
	return lang("Files")
}

getParametersLoopLoop_through_files()
{
	global
	
	parametersToEdit:=["Label|" lang("File pattern"),"File||file|" lang("Select a file") "|","Label|" lang("Options"),"Radio|1|OperateOnWhat|" lang("Operate on files") ";" lang("Operate on files and folders") ";" lang("Operate on folders"),"Checkbox|0|Recurse|" lang("Recurse subfolders into")]
	return parametersToEdit
}

GenerateNameLoopLoop_through_files(ID)
{
	global
	;MsgBox % %ID%text_to_show
	return lang("Loop_through_files") ": " GUISettingsOfElement%id%file 
	
}


