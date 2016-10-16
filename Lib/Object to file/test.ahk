#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.

SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

#Include objtostring.ahk

obj:=object()
unterobj:=object()

obj.insert("hallo")
obj.insert("du")

unterobj.insert("unter")
obj.insert(unterobj)

MsgBox, % ObjToStr(obj)	