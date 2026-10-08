#Requires AutoHotkey v2.0

class ExpressionEvaluator {
    static Evaluate(exprString, variablesMap) {
        exprString := Trim(exprString)
        if (exprString == "")
            return ""

        ; Check if expression references variable via %var% or direct key
        for key, val in variablesMap {
            exprString := StrReplace(exprString, "%" . key . "%", String(val))
            if (exprString == key)
                return val
        }

        if IsNumber(exprString)
            return Number(exprString)

        return exprString
    }
}
