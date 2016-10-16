;Copied from https://autohotkey.com/board/topic/84006-ahk-l-containshasvalue-method/
;thanks to trismarck
ObjHasValue(aObj, aValue) {
    for key, val in aObj
        if(val = aValue)
            return, true, ErrorLevel := 0
    return, false, errorlevel := 1
}