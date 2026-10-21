#Requires AutoHotkey v2.0
; Unit tests for src/editor/NewElementCatalog.ahk (WI-0099, REQ-EDT-050, REQ-USE-010, REQ-USE-020): the kind of a class, the
; list by category filtered by the user's level (with the class the element has kept), the mark of an experimental class,
; the default values (parameters, name, package), the element that a new one makes (height of a loop, the default trigger),
; and the position under the pointer. The real classes come from the Default package; the list rules use test classes.
#Warn All, StdOut
#SingleInstance Off
#Include lib\Assert.ahk
#Include ..\..\src\editor\NewElementCatalog.ahk
#Include ..\..\src\elements\Default\_includes_editor.ahk

; Test classes of the list rules. Their names carry the kind (Action_, Condition_), the classes are not in any package.
class Action_TestBeginnerZeta extends AhfElement {
    static Level := "Beginner"
    static Stability := "Stable"
    static Name() => "Zeta"
    static Category() => "List"
}

class Action_TestExperimentalAlpha extends AhfElement {
    static Level := "Beginner"
    static Stability := "Experimental"
    static Name() => "Alpha"
    static Category() => "List|Variable"
}

class Action_TestAdvanced extends AhfElement {
    static Level := "Advanced"
    static Stability := "Stable"
    static Name() => "Advanced action"
    static Category() => "Variable"
}

class Action_TestProgrammer extends AhfElement {
    static Level := "Programmer"
    static Stability := "Stable"
    static Name() => "Programmer action"
    static Category() => "Variable"
}

class Condition_TestBeginner extends AhfElement {
    static Level := "Beginner"
    static Stability := "Stable"
    static Name() => "Condition"
    static Category() => "Flow control"
}

; A class whose GenerateName throws (the default name is the display name then).
class Action_TestNoName extends AhfElement {
    static Level := "Beginner"
    static Stability := "Stable"
    static Name() => "No name"
    static Category() => "List"
    static GenerateName(ctx, params) => params.Missing
}

; A class whose Parameters need the editor's context (they fail with an empty one): no defaults, the display name.
class Action_TestNeedsContext extends AhfElement {
    static Level := "Beginner"
    static Stability := "Stable"
    static Name() => "Needs context"
    static Category() => "List"
    static Parameters(ctx) => [{type: "edit", id: "Value", default: ctx.Value}]
}

; The labels of a group list, as "category: label, label" (the order is the one of the list).
GroupText(groups) {
    text := ""
    for group in groups {
        items := []
        for item in group[2]
            items.Push(item[2])
        text .= (text = "" ? "" : "; ") group[1] ": " JoinWith(items, ", ")
    }
    return text
}

JoinWith(arr, sep) {
    out := ""
    for item in arr
        out .= (A_Index = 1 ? "" : sep) item
    return out
}

; The qualified IDs of a group list, in order.
IdsOf(groups) {
    ids := []
    for group in groups {
        for item in group[2]
            ids.Push(item[1])
    }
    return ids
}

ListClasses() => [Action_TestBeginnerZeta, Action_TestExperimentalAlpha, Action_TestAdvanced, Action_TestProgrammer
    , Condition_TestBeginner, Action_TestNoName]

KindOfRealClasses() {
    Assert.Equal(NewElementCatalog.KindOf("Default.Action_Sleep"), "action")
    Assert.Equal(NewElementCatalog.KindOf("Default.Condition_Expression"), "condition")
    Assert.Equal(NewElementCatalog.KindOf("Default.Loop_SimpleLoop"), "loop")
    Assert.Equal(NewElementCatalog.KindOf("Default.Trigger_Manual"), "trigger")
    Assert.Equal(NewElementCatalog.KindOf("Default.Do_nothing"), "", "a name without a kind prefix has no kind")
}

LevelsAreShownUpToTheUsersLevel() {
    Assert.True(NewElementCatalog.Shown("Beginner", "Beginner"))
    Assert.True(!NewElementCatalog.Shown("Advanced", "Beginner"), "Beginner hides Advanced")
    Assert.True(!NewElementCatalog.Shown("Programmer", "Beginner"), "Beginner hides Programmer")
    Assert.True(NewElementCatalog.Shown("Advanced", "Advanced"))
    Assert.True(NewElementCatalog.Shown("Beginner", "Advanced"), "Advanced shows Beginner")
    Assert.True(!NewElementCatalog.Shown("Programmer", "Advanced"), "Advanced hides Programmer")
    Assert.True(NewElementCatalog.Shown("Programmer", "Programmer"), "Programmer shows everything")
    Assert.True(NewElementCatalog.Shown("Advanced", "Programmer"))
    Assert.True(NewElementCatalog.Shown("Beginner", "unknown"), "an unknown user level counts as Beginner")
    Assert.True(!NewElementCatalog.Shown("Advanced", "unknown"))
}

ListIsGroupedByCategoryAndFilteredByLevel() {
    groups := NewElementCatalog.Groups("action", "Beginner", "", ListClasses())
    Assert.Equal(GroupText(groups), "List: Alpha (experimental), No name, Zeta; Variable: Alpha (experimental)"
        , "Beginner: the Beginner actions, the experimental one marked, each under its categories, sorted by label")
    groups := NewElementCatalog.Groups("action", "Advanced", "", ListClasses())
    Assert.Equal(GroupText(groups), "List: Alpha (experimental), No name, Zeta; Variable: Advanced action, Alpha (experimental)"
        , "Advanced adds the Advanced actions")
    groups := NewElementCatalog.Groups("action", "Programmer", "", ListClasses())
    Assert.True(InStr(GroupText(groups), "Programmer action") > 0, "Programmer shows the Programmer actions")
}

TheKindDecidesWhichClassesAreListed() {
    groups := NewElementCatalog.Groups("condition", "Beginner", "", ListClasses())
    Assert.Equal(GroupText(groups), "Flow control: Condition", "only the conditions")
    Assert.Equal(NewElementCatalog.Groups("loop", "Programmer", "", ListClasses()).Length, 0, "no loop in the list: none")
}

TheClassOfTheElementIsAlwaysShown() {
    hidden := ElementRegistry.IdOf(Action_TestProgrammer)
    Assert.True(!ArrayHas(IdsOf(NewElementCatalog.Groups("action", "Beginner", "", ListClasses())), hidden))
    shown := NewElementCatalog.Groups("action", "Beginner", hidden, ListClasses())
    Assert.True(ArrayHas(IdsOf(shown), hidden), "the class the element has is shown whatever the level")
}

ArrayHas(arr, value) {
    for item in arr {
        if (item = value)
            return true
    }
    return false
}

ExperimentalClassesAreMarked() {
    groups := NewElementCatalog.Groups("action", "Beginner", "", ListClasses())
    for group in groups {
        for item in group[2] {
            if (item[1] = ElementRegistry.IdOf(Action_TestExperimentalAlpha))
                Assert.True(InStr(item[2], "(experimental)") > 0, "the label carries the mark")
            else
                Assert.True(InStr(item[2], "(experimental)") = 0, "a stable class has no mark")
        }
    }
}

CategoriesOfAClassAreSplitAtThePipe() {
    Assert.Equal(JoinWith(NewElementCatalog.CategoriesOf(Action_TestExperimentalAlpha), ","), "List,Variable")
    Assert.Equal(JoinWith(NewElementCatalog.CategoriesOf(Action_TestBeginnerZeta), ","), "List")
}

DefaultsOfARealClass() {
    d := NewElementCatalog.Defaults("Default.Action_Sleep")
    Assert.Equal(d["pars"].Get("Duration", ""), 2, "the default of Duration")
    Assert.Equal(d["pars"].Get("Unit", ""), 2, "the default of Unit (the index of Minutes/Seconds as v1 stores it)")
    Assert.Equal(d["name"], "Sleep: 2 s", "the name from GenerateName")
    Assert.Equal(d["package"], "Default")
    Assert.Equal(d["packageVersion"], "1.2.1", "the version of the package as the registry has it")
    Assert.Equal(d["class"], "Action_Sleep")
    Assert.Equal(d["kind"], "action")
    t := NewElementCatalog.Defaults("Default.Trigger_Manual")
    Assert.Equal(t["pars"].Get("ID", "missing"), "", "a text parameter gets its default")
}

DefaultNameFallsBackToTheDisplayName() {
    d := NewElementCatalog.Defaults(ElementRegistry.IdOf(Action_TestNoName), Action_TestNoName)
    Assert.Equal(d["name"], "No name", "GenerateName throws: the display name")
    d := NewElementCatalog.Defaults(ElementRegistry.IdOf(Action_TestNeedsContext), Action_TestNeedsContext)
    Assert.Equal(d["pars"].Count, 0, "Parameters that fail with an empty context give no defaults")
    Assert.Equal(d["name"], "Needs context")
}

NewElementCarriesTheDefaultsAndThePosition() {
    el := NewElementCatalog.NewElement("action", "Default.Action_Sleep", 420, 455, "element0000000042", false)
    Assert.Equal(el["ID"], "element0000000042")
    Assert.Equal(el["type"], "action")
    Assert.Equal(el["class"], "Action_Sleep")
    Assert.Equal(el["package"], "Default")
    Assert.Equal(el["packageVersion"], "1.2.1")
    Assert.Equal(el["x"], 420)
    Assert.Equal(el["y"], 455)
    Assert.Equal(el["StandardName"], 1)
    Assert.True(el["pars"].Has("Duration"), "the parameters carry their defaults")
    Assert.True(!el.Has("HeightOfVerticalBar"), "an action has no bar")
    Assert.True(!el.Has("DefaultTrigger"))
}

NewLoopGetsTheDefaultHeightOfItsBar() {
    el := NewElementCatalog.NewElement("loop", "Default.Loop_SimpleLoop", 0, 0, "element0000000043", false)
    Assert.Equal(el["HeightOfVerticalBar"], 150, "v1 Element_SetType: 150")
    Assert.Equal(el["type"], "loop")
}

FirstManualTriggerIsTheDefault() {
    first := NewElementCatalog.NewElement("trigger", "Default.Trigger_Manual", 0, 0, "element0000000044", false)
    Assert.Equal(first["DefaultTrigger"], 1, "the first manual trigger of the flow is the default")
    second := NewElementCatalog.NewElement("trigger", "Default.Trigger_Manual", 0, 0, "element0000000045", true)
    Assert.True(!second.Has("DefaultTrigger"), "a flow with a manual trigger gets no other default")
    hotkey := NewElementCatalog.NewElement("trigger", "Default.Trigger_Hotkey", 0, 0, "element0000000046", false)
    Assert.True(!hotkey.Has("DefaultTrigger"), "only the manual trigger takes the default")
}

NewElementOfAnotherKindIsRefused() {
    Assert.Throws(() => NewElementCatalog.NewElement("loop", "Default.Action_Sleep", 0, 0, "element0000000047", false)
        , AhfError)
}

HasManualTriggerLooksAtTheFlow() {
    root := Map("allElements", Map("element0000000001", Map("type", "trigger", "class", "Trigger_Manual")))
    Assert.True(NewElementCatalog.HasManualTrigger(root))
    root := Map("allElements", Map("element0000000001", Map("type", "trigger", "class", "Trigger_Hotkey")))
    Assert.True(!NewElementCatalog.HasManualTrigger(root))
    Assert.True(!NewElementCatalog.HasManualTrigger(""), "no flow loaded: no trigger")
}

OriginCentresTheElementOnTheSnappedGrid() {
    o := NewElementCatalog.Origin(500, 500)
    Assert.Equal(o[1], 420, "500 - 70 = 430, snapped to the grid of 35")
    Assert.Equal(o[2], 455, "500 - 52.5 = 447.5, snapped to 455")
}

TestRun.Case("Editor add: the kind of a class comes from its name", KindOfRealClasses)
TestRun.Case("Editor add: a level is shown up to the user's level", LevelsAreShownUpToTheUsersLevel)
TestRun.Case("Editor add: the list is grouped by category and filtered by the level", ListIsGroupedByCategoryAndFilteredByLevel)
TestRun.Case("Editor add: the kind decides which classes are listed", TheKindDecidesWhichClassesAreListed)
TestRun.Case("Editor add: the class the element has is shown whatever the level", TheClassOfTheElementIsAlwaysShown)
TestRun.Case("Editor add: an experimental class is marked", ExperimentalClassesAreMarked)
TestRun.Case("Editor add: a class names several categories with pipes", CategoriesOfAClassAreSplitAtThePipe)
TestRun.Case("Editor add: the defaults of a real class", DefaultsOfARealClass)
TestRun.Case("Editor add: the default name falls back to the display name", DefaultNameFallsBackToTheDisplayName)
TestRun.Case("Editor add: a new element carries the defaults and the position", NewElementCarriesTheDefaultsAndThePosition)
TestRun.Case("Editor add: a new loop gets the default height of its bar", NewLoopGetsTheDefaultHeightOfItsBar)
TestRun.Case("Editor add: the first manual trigger is the default trigger", FirstManualTriggerIsTheDefault)
TestRun.Case("Editor add: an element of another kind than the class is refused", NewElementOfAnotherKindIsRefused)
TestRun.Case("Editor add: a flow with a manual trigger is found", HasManualTriggerLooksAtTheFlow)
TestRun.Case("Editor add: the origin centres the element and snaps it to the grid", OriginCentresTheElementOnTheSnappedGrid)
TestRun.Finish()
