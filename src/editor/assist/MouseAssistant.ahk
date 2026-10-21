#Requires AutoHotkey v2.0
#Include ..\..\core\GuiLayout.ahk
#Include ..\..\core\Lang.ahk

; The mouse tracker of the element settings (WI-0110, v1 Mouse tracker): a window of the editor process that takes the mouse
; position (x, y in the coordinate mode Screen, Window or Client) and the colour of the pixel under the mouse. The mapping names
; the keys that the element asks for (v1 x_assistant_MouseTracker): xpos, ypos, CoordMode, color, colorGetMethod. A key
; that the mapping lacks has no control.
; The timer (TICK ms) reads the mouse. When the mouse has moved and then rested for STILL ticks, the position (and the colour)
; is taken. Ctrl with a cursor key moves the mouse by one pixel, while this window is the active one (hotkeys with HotIf: they
; are switched off again in Close, and HotIf is reset). OK sends the values (only the ones shown) to onDone; Cancel and Close
; give onDone an empty Map.
class MouseAssistant {
    static TICK := 100
    static STILL := 3
    static MODES := ["Screen", "Window", "Client"]
    static METHODS := ["default", "alt", "slow"]
    static WIDTH := 480
    static MARGIN := 12
    static ROW := 6
    static LINE_H := 20
    static EDIT_H := 24
    static BUTTON_H := 30
    static BUTTON_W := 110
    static NUDGE := [["^Right", 1, 0], ["^Left", -1, 0], ["^Up", 0, -1], ["^Down", 0, 1]]

    ; mapping: Map(key -> parameter id) of the element; initial: Map(key -> the current value) of the form.
    __New(source, mapping, initial, onDone) {
        this.source := source
        this.onDone := onDone
        this.mapping := mapping
        this.wantPos := mapping.Has("xpos") || mapping.Has("ypos")
        this.wantMode := mapping.Has("CoordMode")
        this.wantColor := mapping.Has("color")
        this.wantMethod := mapping.Has("colorGetMethod")
        this.modeIndex := MouseAssistant._IndexIn(MouseAssistant.MODES, initial.Get("CoordMode", ""), 1)
        this.methodIndex := MouseAssistant._IndexIn(MouseAssistant.METHODS, initial.Get("colorGetMethod", ""), 1)
        this.x := initial.Get("xpos", "")
        this.y := initial.Get("ypos", "")
        this.color := initial.Get("color", "")
        this.gui := ""
        this.lay := ""
        this.ctl := Map()
        this.lastX := ""
        this.lastY := ""
        this.moved := false
        this.still := 0
        this.hotOn := false
        this.tickFn := (*) => this.Tick()
        this.activeFn := (*) => this._Active()
    }

    ; The mouse mode the window reads (Screen, Window or Client).
    Mode => MouseAssistant.MODES[this.modeIndex]
    Method => MouseAssistant.METHODS[this.methodIndex]

    ; Builds the window, shows the current values and starts the timer. show false builds it without showing it.
    Open(show := true) {
        m := MouseAssistant.MARGIN
        cw := MouseAssistant.WIDTH - 2 * m
        g := Gui("-DPIScale +AlwaysOnTop -MinimizeBox -MaximizeBox", Lang("Assist_mouse_title"))
        g.OnEvent("Close", (*) => this.Cancel())
        g.OnEvent("Escape", (*) => this.Cancel())
        this.gui := g
        this.lay := GuiLayout.Create(g, MouseAssistant.WIDTH, 100)
        y := this._Text(Lang("Assist_mouse_help"), m, cw)
        if (this.wantMode) {
            y := this._Text(Lang("Assist_coord_title"), y, cw)
            for index, key in ["Assist_coord_screen", "Assist_coord_window", "Assist_coord_client"] {
                r := g.AddRadio(index = 1 ? "Group" : "", Lang(key))
                GuiLayout.Place(this.lay, r, m, y, cw, MouseAssistant.LINE_H)
                r.Value := (index = this.modeIndex) ? 1 : 0
                r.OnEvent("Click", ObjBindMethod(this, "_ModeChosen", index))
                y += MouseAssistant.LINE_H + 2
            }
            y += MouseAssistant.ROW
        }
        if (this.wantPos) {
            y := this._Text(Lang("Assist_coordinates"), y, cw)
            x := m
            for key in ["x", "y"] {
                GuiLayout.Place(this.lay, g.AddText("", Lang("Assist_" key)), x, y + 4, 16, 16)
                ed := g.AddEdit("", "")
                GuiLayout.Place(this.lay, ed, x + 22, y, 120, MouseAssistant.EDIT_H)
                this.ctl[key] := ed
                x += 170
            }
            y += MouseAssistant.EDIT_H + MouseAssistant.ROW
        }
        if (this.wantColor) {
            y := this._Text(Lang("Assist_color"), y, cw)
            ed := g.AddEdit("ReadOnly", "")
            GuiLayout.Place(this.lay, ed, m, y, 120, MouseAssistant.EDIT_H)
            this.ctl["color"] := ed
            pv := g.AddText("Border", "")
            GuiLayout.Place(this.lay, pv, m + 130, y, 60, MouseAssistant.EDIT_H)
            this.ctl["preview"] := pv
            y += MouseAssistant.EDIT_H + MouseAssistant.ROW
        }
        if (this.wantMethod) {
            y := this._Text(Lang("Assist_method"), y, cw)
            for index, key in ["Assist_method_default", "Assist_method_alt", "Assist_method_slow"] {
                r := g.AddRadio(index = 1 ? "Group" : "", Lang(key))
                GuiLayout.Place(this.lay, r, m, y, cw, MouseAssistant.LINE_H)
                r.Value := (index = this.methodIndex) ? 1 : 0
                r.OnEvent("Click", ObjBindMethod(this, "_MethodChosen", index))
                y += MouseAssistant.LINE_H + 2
            }
            y += MouseAssistant.ROW
        }
        bw := MouseAssistant.BUTTON_W
        bh := MouseAssistant.BUTTON_H
        ok := g.AddButton("Default", Lang("OK"))
        GuiLayout.Place(this.lay, ok, MouseAssistant.WIDTH - m - 2 * bw - m, y + m, bw, bh)
        ok.OnEvent("Click", (*) => this.Take())
        cancel := g.AddButton("", Lang("Cancel"))
        GuiLayout.Place(this.lay, cancel, MouseAssistant.WIDTH - m - bw, y + m, bw, bh)
        cancel.OnEvent("Click", (*) => this.Cancel())
        this.lay["h"] := y + m + bh + m
        this._ShowValues()
        if (this.wantPos)
            this._Nudging(true)
        if (show)
            GuiLayout.Show(this.lay)
        this.lastX := ""
        SetTimer(this.tickFn, MouseAssistant.TICK)
    }

    ; One tick: takes the position and the colour when the mouse has moved and rested (the mouse over this window is ignored).
    Tick() {
        if (!IsObject(this.gui))
            return
        pos := this.source.Mouse(this.Mode)
        if (pos["hwnd"] = this.gui.Hwnd)
            return
        if (pos["x"] != this.lastX || pos["y"] != this.lastY) {
            this.lastX := pos["x"]
            this.lastY := pos["y"]
            this.moved := true
            this.still := 0
            return
        }
        if (!this.moved)
            return
        this.still++
        if (this.still < MouseAssistant.STILL)
            return
        this.moved := false
        this.still := 0
        this.x := pos["x"]
        this.y := pos["y"]
        this._ReadColor()
        this._ShowValues()
    }

    ; Moves the mouse by one pixel (the Ctrl cursor keys). The position is taken at the next rest.
    Nudge(dx, dy) {
        MouseMove(dx, dy, 0, "R")
    }

    ; OK: the values that the window shows go to onDone; the window closes.
    Take() {
        if (!IsObject(this.gui))
            return
        values := Map()
        if (this.wantPos) {
            if (this.ctl["x"].Value != "")
                values["xpos"] := this.ctl["x"].Value
            if (this.ctl["y"].Value != "")
                values["ypos"] := this.ctl["y"].Value
        }
        if (this.wantMode)
            values["CoordMode"] := this.Mode
        if (this.wantColor && this.color != "")
            values["color"] := this.color
        if (this.wantMethod)
            values["colorGetMethod"] := this.Method
        this.Close()
        this.onDone.Call(values)
    }

    ; Cancel: nothing is taken; onDone gets an empty Map.
    Cancel() {
        if (!IsObject(this.gui))
            return
        this.Close()
        this.onDone.Call(Map())
    }

    ; Stops the timer, switches the hotkeys off (and resets HotIf) and destroys the window. Idempotent.
    Close() {
        if (!IsObject(this.gui))
            return
        SetTimer(this.tickFn, 0)
        this._Nudging(false)
        GuiLayout.Destroy(this.lay)
        this.gui.Destroy()
        this.gui := ""
        this.lay := ""
        this.ctl := Map()
    }

    ; The Ctrl cursor keys: on with the window active, off again at Close. The criterion is one object for both calls (a
    ; hotkey variant is found by its criterion).
    _Nudging(on) {
        if (on && !this.hotOn) {
            HotIf(this.activeFn)
            for item in MouseAssistant.NUDGE
                Hotkey(item[1], ((dx, dy) => (*) => this.Nudge(dx, dy))(item[2], item[3]), "On")
            this.hotOn := true
            HotIf()
        } else if (!on && this.hotOn) {
            HotIf(this.activeFn)
            for item in MouseAssistant.NUDGE
                Hotkey(item[1], "Off")
            HotIf()
            this.hotOn := false
        }
    }

    ; The hotkeys work while this window is the active one.
    _Active() => (IsObject(this.gui) && WinActive("ahk_id " this.gui.Hwnd)) ? 1 : 0

    _ModeChosen(index, *) {
        this.modeIndex := index
        this.lastX := ""
        this.moved := true
        this.still := 0
        this._ReadColor()
        this._ShowValues()
    }

    _MethodChosen(index, *) {
        this.methodIndex := index
        this._ReadColor()
        this._ShowValues()
    }

    ; The colour at the position taken (none before the first take).
    _ReadColor() {
        if (!this.wantColor || this.x = "")
            return
        try {
            this.color := this.source.Color(this.x, this.y, this.Mode, this.Method)
        } catch as e {
            this.color := ""
            Log.Write("a0", "editor", "assistant: the colour is not read: " e.Message)
        }
    }

    ; Puts the values into the controls.
    _ShowValues() {
        if (!IsObject(this.gui))
            return
        if (this.wantPos) {
            this.ctl["x"].Value := this.x
            this.ctl["y"].Value := this.y
        }
        if (this.wantColor) {
            this.ctl["color"].Value := this.color
            this.ctl["preview"].Opt("+Background" StrReplace(this.color != "" ? this.color : "0x000000", "0x"))
        }
    }

    ; A text row at y (its height from the text, at least one line); returns the y below it.
    _Text(text, y, cw) {
        h := Max(GuiLayout.TextHeight(this.gui, text, cw), MouseAssistant.LINE_H)
        GuiLayout.Place(this.lay, this.gui.AddText("", text), MouseAssistant.MARGIN, y, cw, h)
        return y + h + MouseAssistant.ROW
    }

    static _IndexIn(list, text, default) {
        for index, item in list {
            if (StrLower(item) = StrLower(text))
                return index
        }
        return default
    }
}
