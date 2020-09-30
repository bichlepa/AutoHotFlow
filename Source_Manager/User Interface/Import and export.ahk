; open the gui for exporting and importing of flows
import_and_export_gui()
{
	global
	local oneFlowID, oneFlow

	; If the gui already exists, just show it
	IfWinExist, ahk_id %ImportExportHWND%
	{
		gui,importexport:show
		return
	}
	
	; Create the gui
	gui, importexport:default
	gui,+hwndImportExportHWND
	gui,font,s10 cnavy wbold
	gui, add, text,x10 y10,% lang("Import flows")
	gui,font,s8 cDefault wnorm
	gui, add, text,x10 Y+10,% lang("To import flows, you can drop an .ahf file in this window or press that button to use the file selector")
	gui, add, button,x10 Y+10 w200 h30 gimportFlowsSelectFile,% lang("Select file")
	gui,font,s10 cnavy wbold
	gui, add, text,x10 Y+20,% lang("Export flows")
	gui,font,s8 cDefault wnorm
	gui, add, listbox,x10 Y+10 w400 h400 vexportFlowsListViewFlowsSelection multi sort
	gui, add, button,x10 Y+10 w200 h30 gexportFlowsExportNow,% lang("Export now")
	
	;Search for all flowNames
	for oneFlowIndex, oneFlowID in _getAllFlowIDs()
	{
		guicontrol,,exportFlowsListViewFlowsSelection,% _getFlowProperty(oneFlowID, "name")
	}
	
	; show gui
	gui,show,,% lang("Import and export flows")
}

; user clicked of "export"
exportFlowsExportNow()
{
	global
	; Get user input from gui
	gui, submit, nohide

	; If user did not select anything, stop
	if not exportFlowsListViewFlowsSelection
	{
		MsgBox % lang("please first select at least one flow")
		return
	}
	
	; Let user select the destination
	FileSelectFile,filepathexport,S18,,% lang("Export AutoHotFlow flows"), % lang("AutoHotFlow file") " (*.ahf)"

	; Append .ahf to the file name if it is omitted
	if (substr(filepathexport, -3) != ".ahf")
		filepathexport.=".ahf"
	; Delete file if it already exists
	filedelete,%filepathexport%

	; create a compressed file with the selected flows
	loop,parse,exportFlowsListViewFlowsSelection,|
	{
		filepathflow := _getFlowProperty(_getFlowIdByName(A_LoopField), "file")
		7z_compress(filepathexport, "-tzip", filepathflow)
	}
	
}

; user wants to select a file
importFlowsSelectFile()
{
	; let user select a file
	FileSelectFile, filepath, ,,% lang("Import AutoHotFlow flows"), % lang("AutoHotFlow file") " (*.ahf)"

	; Import the flows from that file
	if (filepath)
	{
		importExportGui_import(filepath)
	}
}

; user dropped a file in the gui
importexportGuiDropFiles()
{
	; Import the flows from that file
	; if user dropped more than one file, only use the first
	loop, parse, A_GuiEvent, "`n"
	{
		importExportGui_import(A_GuiEvent)
		break
	}	
}

importExportGui_import(filepathZip)
{
	; Check the file extension
	if (substr(filepathZip,-3) != ".ahf")
	{
		MsgBox % lang("Error. This is not an AutoHotFlow file")
		return
	}
	; extract the files
	filepathextractfolder:=_WorkingDir "\tempimportflows"
	FileRemoveDir, % filepathextractfolder, 1 ; first delete the directory, if any
	7z_extract(filepathZip, "-tzip", filepathextractfolder)
	
	; check all extracted files
	loop, %filepathextractfolder%\*.json
	{
		
		;check whether there are flows with same name. Ask user if he wants to import them anyway
		; todo: change to json
		IniRead, newflowname, %a_loopfilefullpath% , general, name, %a_space%
		if not newflowname
		{
			MsgBox, % lang("Imported flow in file ""%1%"" is invalid.", newflowname)
		}
		if (_getFlowIdByName(newflowname))
		{
			MsgBox, 67, % lang("Import Flows"), % lang("A flow with name ""%1%"" already exists.", newflowname) " " lang("Do you want to overwrite it?")
			IfMsgBox,no
			{
				MsgBox, 67, % lang("Import Flows"), % lang("Do you want to rename the flow and import it afterwards?")
				IfMsgBox,no
				{
					continue
				}
				IfMsgBox,cancel
				{
					break
				}
				; append a number to the flow name
				Loop
				{
					if (_getFlowIdByName(newflowname))
					{
						StringGetPos, posspace, newflowname, %a_space% R
						tempFlowNumberInName := substr(newflowname ,posspace + 2)
						if tempFlowNumberInName is number
							newflowname := substr(newflowname, 1, posspace) " " tempFlowNumberInName+1
						else
							newflowname := newflowname " " 2
					}
					else
						break
				}
				; rename the flow
				IniWrite, % newflowname, %a_loopfilefullpath% , general, name
			}
			else IfMsgBox,cancel
			{
				break
			}
		}
		
		;copy the flow to the flows folder. If a file with same name exists, rename first
		ThisFlowFilename := A_LoopFileName
		Loop
		{
			newFlowFullPath:=_WorkingDir "\saved flows\" ThisFlowFilename
			if fileexist(newFlowFullPath)
			{
				random,randomnumber,0,1000
				
				ThisFlowFilename:= substr(ThisFlowFilename,1,strlen(ThisFlowFilename)-4) "_" randomnumber ".json"
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
		loadFlow(newFlowFullPath)
		TreeView_manager_Refill()
		TreeView_manager_Select("Flow", newFlowid)
		
	}
	
	; remove the temporary folder
	FileRemoveDir, % filepathextractfolder, 1
}

; User closed the gui
importexportguiclose()
{
	global
	; destroy the gui
	gui, importexport:destroy
}