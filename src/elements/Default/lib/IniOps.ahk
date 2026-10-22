#Requires AutoHotkey v2.0
#Include ..\..\..\core\Errors.ahk
#Include ..\..\..\core\Lang.ahk
#Include ..\lib\FileOps.ahk

; The shared checks of the ini elements of the package Default (WI-0121): Read from ini, Write to ini and Delete from ini.
; The texts are those of v1 (the same checks in the same order). Pure except for FileOps.Attr, which reads the file system;
; the elements that call IniRead, IniWrite and IniDelete are workers (ARCHITECTURE 2.3).
;
; Encoding (verified in the AutoHotkey v2 help, IniWrite): a new file is written as UTF-16 with a byte order mark, as v1 did;
; an existing file keeps its encoding; IniRead reads ANSI and UTF-16 files as the system does. The elements do not choose
; an encoding, so a file that v1 wrote is read and written the same way.
class IniOps {
    ; The file must exist and be a file, not a folder (v1: "File '%1%' does not exist." and "is a folder.").
    static CheckFile(path) {
        attr := FileOps.Attr(path)
        if (attr = "")
            throw ElementError(Lang("%1% '%2%' does not exist.", Lang("File"), path))
        if (FileOps.IsFolder(attr))
            throw ElementError(Lang("%1% '%2%' is a folder.", Lang("File"), path))
    }

    ; The file must not be a folder (Write to ini creates a missing file, as v1).
    static CheckNotFolder(path) {
        if (FileOps.IsFolder(FileOps.Attr(path)))
            throw ElementError(Lang("%1% '%2%' is a folder.", Lang("File"), path))
    }

    ; A section or key name that is empty is an exception: "<label> is not specified." (v1 texts).
    static Require(value, label) {
        if (value = "")
            throw ElementError(Lang("%1% is not specified.", label))
    }

    ; The key=value lines of a section text (IniRead of a section) as a Map. Lines without "=" are skipped.
    static Pairs(text) {
        m := Map()
        m.CaseSense := "Off"
        for line in StrSplit(text, "`n", "`r") {
            pos := InStr(line, "=")
            if (pos > 0)
                m[SubStr(line, 1, pos - 1)] := SubStr(line, pos + 1)
        }
        return m
    }
}
