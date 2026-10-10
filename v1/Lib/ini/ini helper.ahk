; written by Paul Bichler
; license: WTFPL

; reads ini content from string
; returns a 2-dimensional array
importIni(fileContent)
{
    iniContent := []

	StringReplace, fileContent, fileContent, `r, `n, all

	loop, parse, fileContent, `n, % a_space a_tab
	{
		oneLine := A_LoopField
		if not oneLine
			continue
		
		if (substr(oneLine, 1, 1) = "[" and substr(oneLine, 0, 1) = "]")
		{
			currentSection := substr(oneLine, 2, -1)
			iniContent[currentSection] := []
			continue
		}

		onePos := instr(oneLine, "=")
		if (not onePos)
		{
			return "Line " a_index " has no euqal sign: " oneLine
		}
		oneKey := trim(substr(oneLine, 1, onePos - 1))
		oneValue := trim(substr(oneLine, onePos + 1))

		if (currentSection = "" and not iniContent[currentSection])
			iniContent[currentSection] := []
		
		iniContent[currentSection][oneKey] := oneValue
	}
    return iniContent
}

; writes ini content to string
exportIni(iniContent)
{
	fileContent := []

	for oneSection, oneSectionContent in iniContent
	{
		fileContent .= "[" oneSection "]`n"
		for oneKey, oneValue in oneSectionContent
		{
			fileContent .= oneKey "=" oneValue "`n"
		}
	}

	return fileContent
}