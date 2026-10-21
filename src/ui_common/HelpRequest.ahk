#Requires AutoHotkey v2.0
#Include ..\core\Log.ahk
#Include ..\core\HelpPageId.ahk

; Opens the help window on a page (WI-0111, PROTOCOL 4.12): the menu Help of the manager and the editor, and the Help button of an
; element's settings send cmd.help.show {page} to the supervisor, which shows the page in the help role. The sender does not wait
; for the window: the answer is logged when it says the page was not shown. A request that cannot be sent is logged too.
; Shared by the UI roles (ui_common), so that no role includes another role's folder.
class HelpRequest {
    static TIMEOUT_MS := 5000

    ; page: a page ID (HelpPageId), "" for the index. peer: the Peer of the role (it sends the request to the supervisor).
    static Open(peer, page := "") {
        if (!HelpPageId.IdOk(page)) {
            Log.Write("a0", "editor", "help: '" page "' is not a help page ID")
            return
        }
        try {
            peer.Request("supervisor", "cmd.help.show", Map("page", page)
                , (ans) => HelpRequest._OnAnswer(page, ans), HelpRequest.TIMEOUT_MS)
        } catch as e {
            Log.Write("a0", "editor", "help page '" page "' not requested: " e.Message)
        }
    }

    static _OnAnswer(page, ans) {
        if (!(IsObject(ans) && ans.payload.Get("ok", false)))
            Log.Write("a0", "editor", "help page '" page "' not shown: " (IsObject(ans) ? ans.type : "no answer"))
    }
}
