#Requires AutoHotkey v2.0

class ExpressionEvaluator {
    static Evaluate(exprString, variablesMap := Map()) {
        if exprString is Number || exprString is Integer || exprString is Float
            return exprString

        exprString := Trim(String(exprString))
        if (exprString == "")
            return ""

        ; Variable substitution %var%
        if IsObject(variablesMap) {
            for key, val in variablesMap {
                exprString := StrReplace(exprString, "%" . key . "%", String(val))
                if (exprString == key)
                    return val
            }
        }

        if IsNumber(exprString)
            return Number(exprString)

        ; String concatenation or simple binary operations
        if RegExMatch(exprString, "^\s*([0-9.]+)\s*([\+\-\*\/])\s*([0-9.]+)\s*$", &m) {
            left := Number(m[1])
            op := m[2]
            right := Number(m[3])
            switch op {
                case "+": return left + right
                case "-": return left - right
                case "*": return left * right
                case "/": return right != 0 ? left / right : 0
            }
        }

        ; Comparison operations
        if RegExMatch(exprString, '^\s*"?([^"]*)"?\s*(==|=|!=|>=|<=|>|<)\s*"?([^"]*)"?\s*$', &mComp) {
            left := mComp[1]
            op := mComp[2]
            right := mComp[3]
            switch op {
                case "==", "=": return left = right
                case "!=": return left != right
                case ">": return Number(left) > Number(right)
                case "<": return Number(left) < Number(right)
                case ">=": return Number(left) >= Number(right)
                case "<=": return Number(left) <= Number(right)
            }
        }

        return exprString
    }
}
