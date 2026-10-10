#Requires AutoHotkey v2.0

class JSON {
    static stringify(obj) {
        if IsObject(obj) {
            if obj is Array {
                res := "["
                for idx, val in obj {
                    res .= (idx > 1 ? "," : "") . JSON.stringify(val)
                }
                return res . "]"
            } else if obj is Map {
                res := "{"
                first := true
                for key, val in obj {
                    res .= (first ? "" : ",") . '"' . key . '":' . JSON.stringify(val)
                    first := false
                }
                return res . "}"
            } else {
                res := "{"
                first := true
                for prop in obj.OwnProps() {
                    val := obj.%prop%
                    res .= (first ? "" : ",") . '"' . prop . '":' . JSON.stringify(val)
                    first := false
                }
                return res . "}"
            }
        } else if IsNumber(obj) {
            return String(obj)
        } else {
            str := String(obj)
            str := StrReplace(str, "\", "\\")
            str := StrReplace(str, '"', '\"')
            str := StrReplace(str, "`n", "\n")
            str := StrReplace(str, "`r", "\r")
            str := StrReplace(str, "`t", "\t")
            return '"' . str . '"'
        }
    }

    static parse(str) {
        msg := Map()
        if RegExMatch(str, 's)"action"\s*:\s*"([^"]+)"', &mAction)
            msg["action"] := mAction[1]
        if RegExMatch(str, 's)"type"\s*:\s*"([^"]+)"', &mType)
            msg["type"] := mType[1]
        if RegExMatch(str, 's)"from"\s*:\s*"([^"]+)"', &mFrom)
            msg["from"] := mFrom[1]
        if RegExMatch(str, 's)"to"\s*:\s*"([^"]+)"', &mTo)
            msg["to"] := mTo[1]
        if RegExMatch(str, 's)"id"\s*:\s*"([^"]+)"', &mId)
            msg["id"] := mId[1]
        if RegExMatch(str, 's)"correlation_id"\s*:\s*"([^"]+)"', &mCorr)
            msg["correlation_id"] := mCorr[1]

        msg["payload"] := Map()
        if RegExMatch(str, 's)"flow_id"\s*:\s*"([^"]+)"', &mFlow)
            msg["payload"]["flow_id"] := mFlow[1]
        if RegExMatch(str, 's)"instance_id"\s*:\s*"([^"]+)"', &mInst)
            msg["payload"]["instance_id"] := mInst[1]
        if RegExMatch(str, 's)"element_id"\s*:\s*"([^"]+)"', &mElem)
            msg["payload"]["element_id"] := mElem[1]
        if RegExMatch(str, 's)"status"\s*:\s*"([^"]+)"', &mStat)
            msg["payload"]["status"] := mStat[1]
        if RegExMatch(str, 's)"trigger_key"\s*:\s*"([^"]+)"', &mTrig)
            msg["payload"]["trigger_key"] := mTrig[1]
        if RegExMatch(str, 's)"filepath"\s*:\s*"([^"]+)"', &mPath)
            msg["payload"]["filepath"] := mPath[1]

        return msg
    }
}

class NamedPipeIPC {
    static PipePrefix := "\\.\pipe\AutoHotFlow_v2_"

    __New(processName, messageHandler) {
        this.processName := processName
        this.messageHandler := messageHandler
        this.counter := 0
        this.pendingRequests := Map()
    }

    generateId() {
        this.counter++
        return this.processName . "-" . this.counter
    }

    createMessage(type, to, action, payload := Map(), correlationId := "") {
        msg := Map()
        msg["id"] := this.generateId()
        msg["type"] := type
        msg["from"] := this.processName
        msg["to"] := to
        msg["action"] := action
        msg["correlation_id"] := correlationId
        msg["payload"] := payload
        return msg
    }

    serialize(msgMap) {
        return JSON.stringify(msgMap) . "`n"
    }

    receiveRaw(rawString) {
        rawString := Trim(rawString, "`r`n ")
        if (rawString == "")
            return

        msgMap := JSON.parse(rawString)
        if (msgMap.Has("correlation_id") && msgMap["correlation_id"] != "" && this.pendingRequests.Has(msgMap["correlation_id"])) {
            cb := this.pendingRequests[msgMap["correlation_id"]]
            this.pendingRequests.Delete(msgMap["correlation_id"])
            cb(msgMap)
            return
        }

        if (this.messageHandler) {
            (this.messageHandler)(msgMap)
        }
    }
}
