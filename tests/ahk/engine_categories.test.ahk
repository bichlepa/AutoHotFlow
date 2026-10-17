#Requires AutoHotkey v2.0
; Unit tests of the order of the flow list (WI-0071, E0067): FlowOrder, the model of the categories and of the order of
; the flows in each category. The file, the commands and the events: tests/integration/test_categories.py.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\engine\core\FlowOrder.ahk

; Text of the whole order: "name=id,id;name=..." (the uncategorized group is shown as "-").
Shape(order) {
    s := ""
    for entry in order.Entries() {
        name := entry["name"] = "" ? "-" : entry["name"]
        s .= name "="
        for id in entry["flows"]
            s .= id ","
        s .= ";"
    }
    return s
}

; A member list of the table: Map(flowId, category) pairs as given in the order of "id:category".
Members(spec) {
    out := []
    for pair in StrSplit(spec, " ") {
        if (pair = "")
            continue
        parts := StrSplit(pair, ":")
        cat := parts.Length > 1 ? parts[2] : ""
        out.Push(Map("flowId", parts[1], "category", cat))
    }
    return out
}

Names(spec) {
    m := Map()
    for pair in StrSplit(spec, " ") {
        if (pair = "")
            continue
        parts := StrSplit(pair, "=")
        m[parts[1]] := parts[2]
    }
    return m
}

; --- building ------------------------------------------------------------------------------------------------------

FreshOrderIsAlphabeticalWithUncategorizedLast() {
    order := FlowOrder()
    order.Reconcile(Members("f3:beta f1:Alpha f2: f4:Alpha"))
    order.SortAlphabetically(Names("f1=Zed f2=b f3=x f4=Y"))
    Assert.Equal(Shape(order), "Alpha=f4,f1,;beta=f3,;-=f2,;", "categories and flows sorted ignoring case, uncategorized last")
}

ReconcileAppendsAFlowThatIsNotInTheOrder() {
    order := FlowOrder()
    order.Load(FlowOrder.Parse('{"formatVersion":1,"categories":[{"name":"Home","flows":["f1","f2"]},{"name":"","flows":["f3"]}]}'))
    order.Reconcile(Members("f1:Home f2:Home f3: f9:Home"))
    Assert.Equal(Shape(order), "Home=f1,f2,f9,;-=f3,;", "a new flow is appended at the end of its category")
}

ReconcileDropsAnIdThatNoFlowHas() {
    order := FlowOrder()
    order.Load(FlowOrder.Parse('{"formatVersion":1,"categories":[{"name":"Home","flows":["gone","f1"]}]}'))
    order.Reconcile(Members("f1:Home"))
    Assert.Equal(Shape(order), "Home=f1,;-=;", "the stale ID is dropped")
}

MovedFlowLeavesItsCategoryAndKeepsEmptyCategories() {
    order := FlowOrder()
    order.Load(FlowOrder.Parse('{"formatVersion":1,"categories":[{"name":"A","flows":["f1","f2"]},{"name":"B","flows":[]}]}'))
    order.Reconcile(Members("f1:B f2:A"))
    Assert.Equal(Shape(order), "A=f2,;B=f1,;-=;", "a flow whose category changed moves to the end of the new one")
    order.Reconcile(Members("f2:A"))
    Assert.Equal(Shape(order), "A=f2,;B=;-=;", "the empty category B stays")
}

ReconcileKeepsTheOrderOfKnownFlows() {
    order := FlowOrder()
    order.Load(FlowOrder.Parse('{"formatVersion":1,"categories":[{"name":"A","flows":["f2","f1"]}]}'))
    order.Reconcile(Members("f1:A f2:A"))
    Assert.Equal(Shape(order), "A=f2,f1,;-=;", "the order of the file is kept")
}

; --- the file text ---------------------------------------------------------------------------------------------------

ParseReadsTheOrderAndTextRoundTrips() {
    entries := FlowOrder.Parse('{"formatVersion":1,"categories":[{"name":"X","flows":["f1"]},{"name":"","flows":["f2"]}]}')
    order := FlowOrder()
    order.Load(entries)
    again := FlowOrder()
    again.Load(FlowOrder.Parse(order.Text()))
    Assert.Equal(Shape(again), "X=f1,;-=f2,;", "the text of a model is read back as the same model")
}

ParseRefusesEverythingElse() {
    for text in ['{"formatVersion":2,"categories":[]}', '[1]', '{"categories":[]}', '{"formatVersion":1,"categories":{}}'
        , '{"formatVersion":1,"categories":[{"name":"A"},{"name":"A"}]}'
        , '{"formatVersion":1,"categories":[{"name":"A","flows":"f1"}]}'
        , '{"formatVersion":1,"categories":[{"name":{},"flows":[]}]}', '{broken']
        Assert.Throws(() => FlowOrder.Parse(text), , "refused: " text)
}

ParseWithoutCategoriesIsAnEmptyOrder() {
    order := FlowOrder()
    order.Load(FlowOrder.Parse('{"formatVersion":1}'))
    Assert.Equal(Shape(order), "-=;", "only the uncategorized group")
}

; --- changes of the order ------------------------------------------------------------------------------------------

CreateAppendsBeforeUncategorized() {
    order := FlowOrder()
    order.Create("New")
    Assert.Equal(Shape(order), "New=;-=;", "the new category comes before the uncategorized group")
    Assert.Throws(() => order.Create("New"), , "a second category with the same name is refused")
    Assert.Throws(() => order.Create(""), , "the uncategorized group cannot be created")
}

RenameKeepsPlaceAndFlows() {
    order := FlowOrder()
    order.Load(FlowOrder.Parse('{"formatVersion":1,"categories":[{"name":"A","flows":["f1"]},{"name":"B","flows":["f2"]}]}'))
    order.Rename("A", "C")
    Assert.Equal(Shape(order), "C=f1,;B=f2,;-=;", "renamed in place")
    order.Rename("C", "c")
    Assert.Equal(Shape(order), "c=f1,;B=f2,;-=;", "a change of case is a rename")
    Assert.Throws(() => order.Rename("c", "B"), , "a name that another category has is refused")
    Assert.Throws(() => order.Rename("", "X"), , "the uncategorized group cannot be renamed")
}

MoveAllThenRemove() {
    order := FlowOrder()
    order.Load(FlowOrder.Parse('{"formatVersion":1,"categories":[{"name":"A","flows":["f1","f2"]},{"name":"B","flows":["f3"]}]}'))
    Assert.Throws(() => order.Remove("A"), , "a category with flows cannot be removed")
    order.MoveAll("A", "B")
    order.Remove("A")
    Assert.Equal(Shape(order), "B=f3,f1,f2,;-=;", "the flows are appended to the target, then the category goes")
    Assert.Throws(() => order.Remove(""), , "the uncategorized group cannot be removed")
}

SetCategoriesNeedsEveryCategoryOnce() {
    order := FlowOrder()
    order.Load(FlowOrder.Parse('{"formatVersion":1,"categories":[{"name":"A","flows":[]},{"name":"B","flows":[]}]}'))
    order.SetCategories(["B", "A"])
    Assert.Equal(Shape(order), "B=;A=;-=;", "a permutation is taken")
    order.SetCategories(["B", "A", ""])
    Assert.Equal(Shape(order), "B=;A=;-=;", "the uncategorized group may be given last")
    Assert.Throws(() => order.SetCategories(["A"]), , "a missing category is refused")
    Assert.Throws(() => order.SetCategories(["A", "A"]), , "a category twice is refused")
    Assert.Throws(() => order.SetCategories(["", "A", "B"]), , "the uncategorized group must be last")
    Assert.Throws(() => order.SetCategories(["A", "B", "C"]), , "an unknown category is refused")
}

SetFlowsNeedsAPermutationOfTheMembers() {
    order := FlowOrder()
    order.Load(FlowOrder.Parse('{"formatVersion":1,"categories":[{"name":"A","flows":["f1","f2","f3"]}]}'))
    order.SetFlows("A", ["f3", "f1", "f2"])
    Assert.Equal(Shape(order), "A=f3,f1,f2,;-=;", "a permutation is taken")
    Assert.Throws(() => order.SetFlows("A", ["f3", "f1"]), , "a missing flow is refused")
    Assert.Throws(() => order.SetFlows("A", ["f3", "f1", "f9"]), , "a flow of another category is refused")
    Assert.Throws(() => order.SetFlows("A", ["f3", "f3", "f1"]), , "a flow twice is refused")
    Assert.Equal(Shape(order), "A=f3,f1,f2,;-=;", "a refused order changes nothing")
}

SortAlphabeticallyOnce() {
    order := FlowOrder()
    order.Load(FlowOrder.Parse('{"formatVersion":1,"categories":[{"name":"b","flows":["f1","f2"]},{"name":"A","flows":[]}'
        . ',{"name":"","flows":["f3"]}]}'))
    order.SortAlphabetically(Names("f1=zeta f2=Alpha f3=none"))
    Assert.Equal(Shape(order), "A=;b=f2,f1,;-=f3,;", "categories and flows sorted ignoring case, uncategorized last")
}

; --- entry point -----------------------------------------------------------------------------------------------------

TestRun.Init()

TestRun.Case("Categories: a fresh list is alphabetical, uncategorized last", FreshOrderIsAlphabeticalWithUncategorizedLast)
TestRun.Case("Categories: a flow that is not in the order is appended to its category", ReconcileAppendsAFlowThatIsNotInTheOrder)
TestRun.Case("Categories: an ID that no flow has is dropped", ReconcileDropsAnIdThatNoFlowHas)
TestRun.Case("Categories: a moved flow leaves its category, an empty category stays", MovedFlowLeavesItsCategoryAndKeepsEmptyCategories)
TestRun.Case("Categories: the known flows keep the order of the file", ReconcileKeepsTheOrderOfKnownFlows)
TestRun.Case("Categories: the text of the order is read back as the same order", ParseReadsTheOrderAndTextRoundTrips)
TestRun.Case("Categories: other formats are refused (the engine keeps the file as broken)", ParseRefusesEverythingElse)
TestRun.Case("Categories: a file without categories is an empty order", ParseWithoutCategoriesIsAnEmptyOrder)
TestRun.Case("Categories: create appends before the uncategorized group", CreateAppendsBeforeUncategorized)
TestRun.Case("Categories: rename keeps place and flows, a change of case counts", RenameKeepsPlaceAndFlows)
TestRun.Case("Categories: the flows move first, then an empty category is removed", MoveAllThenRemove)
TestRun.Case("Categories: the new order of the categories is a permutation", SetCategoriesNeedsEveryCategoryOnce)
TestRun.Case("Categories: the new order of the flows is a permutation of the members", SetFlowsNeedsAPermutationOfTheMembers)
TestRun.Case("Categories: sort alphabetically once, ignoring case", SortAlphabeticallyOnce)

TestRun.Finish()
