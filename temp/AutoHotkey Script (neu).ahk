#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.


obj:=object()

obj.gaga:="hi"
obj.gagi:="hlihil"

copie:=obj.clone()
copie.gaga:="io"
MsgBox % obj.gaga " - " copie.gaga