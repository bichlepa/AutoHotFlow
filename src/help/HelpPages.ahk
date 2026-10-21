#Requires AutoHotkey v2.0
#Include ..\core\HelpPageId.ahk
#Include ..\core\SettingsModel.ahk
#Include WebView2Loader.ahk

; The headless model of the help (WI-0111, PROTOCOL 4.12): which file shows a page ID, in which language, with which
; viewer. No window here; the only native call is the availability of WebView2 (WebView2Loader, cached). The role (HelpRole)
; and the tests use it.
;
; Files (ARCHITECTURE 8, tools/gen_help.py, E0100): an element page is src\elements\Default\help\<lang>\<Kind>\<Name>.html,
; a general page is assets\help\<lang>\<Name>.html. The generated HTML is committed next to its Markdown source.
class HelpPages {
    static INDEX := "Welcome"
    static FALLBACK := "en"
    ; The program's folder (the folder above src\), from the path of this file.
    static Root() => RegExReplace(A_LineFile, "\\src\\help\\[^\\]+$")

    ; The HTML file of a page ID in a language (no check that it exists).
    static FileOf(id, code) {
        rel := StrReplace(id, "/", "\") ".html"
        if (InStr(id, "/"))
            return HelpPages.Root() "\src\elements\Default\help\" code "\" rel
        return HelpPages.Root() "\assets\help\" code "\" rel
    }

    ; The file that shows a page: the page in the language, else in English. found tells whether the page itself exists
    ; (in one of the languages). When it does not exist, path is the English index, which the window then shows
    ; (PROTOCOL 4.12). Returns Map("path", file, "found", bool, "language", code).
    static Resolve(id, lang := "") {
        if (id = "")
            id := HelpPages.INDEX
        codes := [HelpPages.FALLBACK]
        if (lang != "" && StrLower(lang) != HelpPages.FALLBACK)
            codes := [lang, HelpPages.FALLBACK]
        for code in codes {
            path := HelpPages.FileOf(id, code)
            if (FileExist(path))
                return Map("path", path, "found", true, "language", code)
        }
        return Map("path", HelpPages.FileOf(HelpPages.INDEX, HelpPages.FALLBACK), "found", false
            , "language", HelpPages.FALLBACK)
    }

    ; file:// URL of a file path, for the viewers (spaces are escaped).
    static Url(path) => "file:///" StrReplace(StrReplace(path, "\", "/"), " ", "%20")

    ; The loader DLL of WebView2 (WI-0115): the setup tool (tools/fetch_webview2_loader.py) puts it into assets\bin; S0009
    ; ships it. WebView2Available is the one question the choice of the viewer asks (cached for the process).
    static WebView2Dll() => HelpPages.Root() "\assets\bin\WebView2Loader.dll"
    static WebView2Available() => WebView2Loader.Available(HelpPages.WebView2Dll())

    ; The viewer of a setting (E0099): "classic", "browser" or "webview2". fallback is true when the setting asked for
    ; WebView2 and it is not available: the classic viewer shows the page, and the role logs it.
    static ViewerFor(setting, webview2 := false) {
        if (setting = "browser")
            return Map("viewer", "browser", "fallback", false)
        if (setting = "classic")
            return Map("viewer", "classic", "fallback", false)
        if (setting = "webview2") {
            if (webview2)
                return Map("viewer", "webview2", "fallback", false)
            return Map("viewer", "classic", "fallback", true)
        }
        return Map("viewer", webview2 ? "webview2" : "classic", "fallback", false)     ; auto, and any other value
    }
}
