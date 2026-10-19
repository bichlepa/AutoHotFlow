#Requires AutoHotkey v2.0
#Include ..\core\GuiLayout.ahk
#Include ..\core\Lang.ahk
#Include ..\core\Log.ahk
#Include ..\core\AhfVersion.ahk
#Include ..\ui_common\UiWindow.ahk

; The about window of the manager (WI-0078, REQ-MGR-100): the version of AutoHotFlow (AhfVersion) and of AutoHotkey
; (A_AhkVersion), the license and the project site. The site opens in the browser by the button (Run, no wait). The texts
; are registered with UiWindow, so a change of the language changes them at once.
class AboutWindow {
    static WIDTH := 460
    static HEIGHT := 230
    static MARGIN := 12
    static SITE := "https://github.com/bichlepa/AutoHotFlow"
    static LINE_H := 22

    __New() {
        this.win := UiWindow("manager.about", "About_AutoHotFlow", AboutWindow.WIDTH, AboutWindow.HEIGHT)
        this.win.hideOnClose := false
        g := this.win.Gui
        m := AboutWindow.MARGIN
        width := AboutWindow.WIDTH - 2 * m
        y := m
        version := g.AddText("", "")
        this.win.Place(version, m, y, width, AboutWindow.LINE_H)
        this.win.Text(version, "About_version", "Text", AhfVersion.Current)
        y += AboutWindow.LINE_H
        ahk := g.AddText("", "")
        this.win.Place(ahk, m, y, width, AboutWindow.LINE_H)
        this.win.Text(ahk, "About_autohotkey_version", "Text", A_AhkVersion)
        y += AboutWindow.LINE_H + 6
        license := g.AddText("", "")
        this.win.Place(license, m, y, width, 2 * AboutWindow.LINE_H)
        this.win.Text(license, "About_license")
        y += 2 * AboutWindow.LINE_H + 6
        site := g.AddEdit("ReadOnly", AboutWindow.SITE)
        this.win.Place(site, m, y, width, 24)
        y += 24 + m
        open := g.AddButton(, "")
        this.win.Place(open, AboutWindow.WIDTH - m - 180, y, 180, 30)
        this.win.Text(open, "About_open_site")
        open.OnEvent("Click", (*) => AboutWindow.OpenSite())
        this.lines := [version, ahk, license, site]     ; the controls with the texts (the tests read them)
        this.done := false
    }

    Show() {
        this.win.Show()
    }

    Visible => !this.done && this.win.Visible

    ; Closes the window (Close button, Escape, the close box).
    Close() {
        if (this.done)
            return
        this.done := true
        this.win.Close()
    }

    ; Opens the project site in the browser of the user. Run does not wait; a failure is logged.
    static OpenSite() {
        try {
            Run(AboutWindow.SITE)
        } catch as e {
            Log.Write("a0", "manager", "the project site cannot be opened: " e.Message)
        }
    }
}
