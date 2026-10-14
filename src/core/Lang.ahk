#Requires AutoHotkey v2.0
#Include LangTable.ahk

; The translated text of key, with %1%, %2%, ... replaced by the arguments (v1 lang() and x_lang(), E28). A key that
; has no text gives the key itself. Rules and files: LangTable. Every role can use it.
Lang(key, args*) => LangTable.Get(key, args*)
