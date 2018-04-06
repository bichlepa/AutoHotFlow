
import_and_export_gui()
{
	global
	local oneFlowID, oneFlow, import_and_export_choices, import_and_export_choices_string
	IfWinExist, ahk_id %ImportExportHWND%
	{
		gui,importexport:show
		return
	}
	
	gui, importexport:default
	gui,+hwndImportExportHWND
	gui, font,s15
	gui, add, text,x10 y10,% lang("Import flows")
	gui, font,s12
	gui, add, text,x10 Y+10,% lang("To import flows, you can drop an .ahf file in this window or press that button to use the file selector")
	gui, add, button,x10 Y+10 w200 h30 gimportFlowsSelectFile,% lang("Select file")
	gui, font,s15
	gui, add, text,x10 Y+50,% lang("Export flows")
	gui, font,s12
	gui, add, listbox,x10 Y+10 w400 h400 vexportFlowsListViewFlowsSelection multi sort
	gui, add, button,x10 Y+10 w200 h30 gexportFlowsExportNow,% lang("Export now")
	
	;Search for all flowNames
	import_and_export_choices:=object()
	for oneFlowID, oneFlow in _flows
	{
		import_and_export_choices.push(oneFlow.name)
		guicontrol,,exportFlowsListViewFlowsSelection,% oneFlow.name
	}
	
	
	gui,show,,% lang("Import and export flows")
}


exportFlowsExportNow()
{
	global
	gui, submit, nohide
	if exportFlowsListViewFlowsSelection=
	{
		MsgBox % lang("please first select at least one flow")
		return
	}
	
	FileSelectFile,filepathexport,S18,,% lang("Export AutoHotFlow flows"), % lang("AutoHotFlow file") " (*.ahf)"
	if (substr(filepathexport,-3) != ".ahf")
		filepathexport.=".ahf"
	filedelete,%filepathexport%
	loop,parse,exportFlowsListViewFlowsSelection,|
	{
		filepathflow:=_flows[FlowIDbyName(A_LoopField)].file
		7z_compress(filepathexport, "-tzip", filepathflow)
	}
	
}

importFlowsSelectFile()
{
	FileSelectFile, filepath, ,,% lang("Import AutoHotFlow flows"), % lang("AutoHotFlow file") " (*.ahf)"
	importExportGui_import(filepath)
}

importexportGuiDropFiles()
{
	importExportGui_import(A_GuiEvent)
}

importExportGui_import(filepathZip)
{
	if (substr(filepathZip,-3) != ".ahf")
	{
		MsgBox % lang("Error. This is not an AutoHotFlow file")
		return
	}
	filepathextractfolder:=_WorkingDir "\tempimportflows"
	FileRemoveDir, % filepathextractfolder, 1
	7z_extract(filepathZip, "-tzip", filepathextractfolder)
	
	loop, %filepathextractfolder%\*.ini
	{
		
		;check whether there are flows with same name. Ask user if he wants to import them anyway
		IniRead, newflowname, %a_loopfilefullpath% , general, name
		if (flowIDbyName(newflowname))
		{
			MsgBox, 67, % lang("Import Flows"), % lang("A flow with name ""%1%"" already exists.", newflowname) " " lang("Do you want to import it anyway?")
			IfMsgBox,no
			{
				continue
			}
			IfMsgBox,cancel
			{
				break
			}
		}
		
		;copy the flow to the flows folder. If a file with same name exists, rename first
		ThisFlowFilename:=A_LoopFileName
		Loop
		{
			newFlowFullPath:=_WorkingDir "\saved flows\" ThisFlowFilename
			if fileexist(newFlowFullPath)
			{
				random,randomnumber,0,1000
				
				ThisFlowFilename:= substr(ThisFlowFilename,1,strlen(ThisFlowFilename)-4) "_" randomnumber ".ini"
			}
			else
				break
		}
		newFlowFullPath:=_WorkingDir "\saved flows\" ThisFlowFilename
		filecopy, %a_loopfilefullpath%,%newFlowFullPath%
		if errorlevel
		{
			MsgBox, importing flow %newflowname% unexpectedly failed
			continue
		}
		
		;show flow in the manager
		InitFlow(newFlowFullPath)
	}
	
	FileRemoveDir, % filepathextractfolder, 1
}

importexportguiclose()
{
	global
	gui, importexport:destroy
	
}