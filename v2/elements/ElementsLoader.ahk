#Requires AutoHotkey v2.0
#Include Actions/Action_Message_Box.ahk
#Include Actions/Action_Sleep.ahk
#Include Conditions/Condition_File_Exists.ahk
#Include Loops/Loop_SimpleLoop.ahk
#Include Triggers/Trigger_Hotkey.ahk

class ElementsLoader {
    static RegisterAll(engine) {
        engine.RegisterElementClass("Action_Message_Box", Action_Message_Box)
        engine.RegisterElementClass("Action_Sleep", Action_Sleep)
        engine.RegisterElementClass("Condition_File_Exists", Condition_File_Exists)
        engine.RegisterElementClass("Loop_SimpleLoop", Loop_SimpleLoop)
        engine.RegisterElementClass("Trigger_Hotkey", Trigger_Hotkey)
    }
}
