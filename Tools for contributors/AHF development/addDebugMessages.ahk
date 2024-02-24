#SingleInstance, Force
SendMode Input
SetWorkingDir, %A_ScriptDir%/../..

MsgBox, %A_WorkingDir%

folders := ["source_common", "source_draw", "source_editor", "source_elements", "source_execution", "source_main", "source_manager"]

BracketDepth := 0
for folderIndex, folderName in folders
{
    loop, files, %folderName%\*.ahk, r
    {
        MsgBox, "file: " %A_LoopFileFullPath% 
        FileRead, fileContent, *t %A_LoopFileFullPath%
        fileContentModified := ""

        fileLinePos := 1
        loop, parse, fileContent, `n
        {
            fileLine := a_loopfield
            fileLineLength := strlen(fileLine)
            fileLinePos += fileLineLength + 1
            fileLineTrimmed := trim(fileLine, " `t")
            fileLineIndex := a_index
            skipLineAppend := false
            if regexmatch("asdf" fileLineTrimmed "asdf", "asdf(\w*)\((.*)\)\s*;?.*asdf", matches)
            {
                possibleFunction := {name: matches1, pars: matches2, line: fileLine, lineIndex: fileLineIndex}
                functionName := matches1
                functionPars := matches2
                functionWholeLine := fileLine
                functionLineIndex := a_index
                if not (functionName = "if")
                {
                    ;MsgBox, % "file: " A_LoopFileFullPath "`nline index: " fileLineIndex "`nline content: " fileLine "`nfunctionName: " functionName "`nfunctionPars: " functionPars

                    lastFound := "function"
                }
            }
            else if (fileLineTrimmed = "{")
            {
                BracketDepth += 1
                if (lastFound = "function")
                {
                    function := possibleFunction
                    ;MsgBox, % "function start found`nfile: " A_LoopFileFullPath "`nline index: " fileLineIndex "`nfunction line index: " function.lineindex "`nline content: " function.line "`nfunctionName: " function.name "`nfunctionPars: " function.pars
                    functionBracketDepth := BracketDepth
                    
                    ; add debug log
                    logLine := "`n	log(a_tickcount "" enter function " function.name """)"
                    fileContentModified .= fileLine "`n"
                    fileContentModified .= logLine "`n"
                    skipLineAppend := true
                }
                lastFound := ""
            }
            Else if (fileLineTrimmed = "}")
            {
                if (BracketDepth = functionBracketDepth)
                {
                    ;MsgBox, % "function end found`nfile: " A_LoopFileFullPath "`nline index: " fileLineIndex "`nfunction line index: " function.lineindex "`nline content: " function.line "`nfunctionName: " function.name "`nfunctionPars: " function.pars
                    
                    ; add debug log
                    logLine := "`n	log(a_tickcount "" leave function " function.name """)"
                    fileContentModified .= logLine "`n"
                }
                BracketDepth -= 1
                lastFound := ""
            }
            Else
            {
                lastFound := ""
            }

            if not skipLineAppend
                fileContentModified .= fileLine "`n"
        }

        filedelete, %A_LoopFileFullPath% 
        FileAppend, %fileContentModified%, %A_LoopFileFullPath% 
        exitapp
    }

}