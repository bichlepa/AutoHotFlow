#Requires AutoHotkey v2.0
#Include ..\core\Log.ahk
#Include HelpViewer.ahk
#Include HelpPages.ahk

; The browser viewer (WI-0111, E0099): the page opens in the default browser of Windows, and the program shows no window of
; its own. Navigate starts the browser with the file URL (Run does not wait). There is no history and no control to resize,
; so Back, Resize and Close do nothing (the browser has its own).
class BrowserViewer extends HelpViewer {
    __New() {
        this.name := "browser"
    }

    Navigate(path) {
        url := HelpPages.Url(path)
        try {
            Run(url)
        } catch as e {
            Log.Write("a0", "help", "the default browser could not open the help page: " e.Message)
        }
    }

    Back() {
    }

    Resize(x, y, w, h) {
    }

    Close() {
    }
}
