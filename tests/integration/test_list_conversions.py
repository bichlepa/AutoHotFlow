"""WI-0119 (REQ-ELM-230): end-to-end tests of Get from list, Convert list to string and Convert string to list of the
package Default. A list is made by Split a string (keys 1, 2, ...) or by Convert string to list (JSON text); the flow
reads the result into `x` with a probe, or the exception of the run is the result. The expected texts are those of
v1 where v1 wrote JSON; YAML is not part of this version (MIGRATION M-0110).
"""

from support.coreflows import run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)


def list_flow(name, element, **pars):
    """trigger -> Split a string (the list `myList` of "a,b,c") -> the element -> probe of `x`."""
    fb = FlowBuilder(name)
    split = fb.action("Action_Split_a_string", Varname="myList", VarValue="a,b,c", Delimiters=",", OmitChars="")
    el = fb.action(element, **pars)
    fb.chain(fb.trigger(), split, el, fb.probe("x"))
    return fb


def json_flow(name, text, element, **pars):
    """trigger -> Convert string to list of the JSON text `text` (the list `myList`) -> the element -> probe of `x`."""
    fb = FlowBuilder(name)
    read = fb.action("Action_Convert_string_to_list", Varname="myList", VarValue=text, expression="String",
                     listToStringOutputFormat="JSON")
    el = fb.action(element, **pars)
    fb.chain(fb.trigger(), read, el, fb.probe("x"))
    return fb


def get(name, **pars):
    return list_flow(name, "Action_Get_From_List", Varname="x", ListName="myList", **pars)


def text_of(run):
    probe = run.seen.get("x") if run.seen else None
    assert probe is not None, run.exceptions
    return probe.text


def test_get_from_list_first_last_and_specified(flows):
    runs = run_all(flows, [
        get("gfl_first", WhichPosition="First"),
        get("gfl_last", WhichPosition="Last"),
        get("gfl_second", WhichPosition="Specified", Position="2"),
        get("gfl_default_stored", WhichPosition=1),          # the stored position of v1 (1 = First)
        get("gfl_missing_key", WhichPosition="Specified", Position="9"),
        get("gfl_text_key", WhichPosition="Specified", Position="keyName"),
    ])
    assert text_of(runs[0]) == "a"
    assert text_of(runs[1]) == "c"
    assert text_of(runs[2]) == "b"
    assert text_of(runs[3]) == "a"
    assert runs[4].exceptions and "does not contain the key" in runs[4].exceptions[0]
    assert runs[5].exceptions                            # no key "keyName" in the list


def test_get_from_list_random_is_one_of_the_values(flows):
    run = run_all(flows, [get("gfl_random", WhichPosition="Random")])[0]
    assert text_of(run) in {"a", "b", "c"}


def test_get_from_list_with_a_text_key(flows):
    run = run_all(flows, [json_flow("gfl_name", '{"name":"Paul","2":"b"}', "Action_Get_From_List",
                                    Varname="x", ListName="myList", WhichPosition="Specified", Position="name")])[0]
    assert text_of(run) == "Paul"


def test_get_from_list_of_a_number_key_written_as_text(flows):
    run = run_all(flows, [json_flow("gfl_numkey", '{"2":"b"}', "Action_Get_From_List",
                                    Varname="x", ListName="myList", WhichPosition="Specified", Position="2")])[0]
    assert text_of(run) == "b"


def test_convert_list_to_compact_json_and_indented(flows):
    runs = run_all(flows, [
        list_flow("clist_compact", "Action_Convert_list_to_string", Varname="x", ListName="myList",
                  listToStringOutputFormat="JSON", compactMode=1),
        list_flow("clist_indent", "Action_Convert_list_to_string", Varname="x", ListName="myList",
                  listToStringOutputFormat="JSON", compactMode=0, indentationLength=2),
    ])
    assert text_of(runs[0]) == '["a","b","c"]'
    assert text_of(runs[1]).splitlines()[1] == '  "a",'


def test_convert_list_with_text_keys_is_an_object_with_sorted_keys(flows):
    run = run_all(flows, [json_flow("clist_object", '{"b":1,"a":"x"}', "Action_Convert_list_to_string",
                                    Varname="x", ListName="myList", listToStringOutputFormat="JSON",
                                    compactMode=1)])[0]
    assert text_of(run) == '{"a":"x","b":1}'


def test_convert_list_to_yaml_is_an_exception(flows):
    fb = list_flow("clist_yaml", "Action_Convert_list_to_string", Varname="x", ListName="myList",
                   listToStringOutputFormat="YAML")
    result = run_all(flows, [fb])[0]
    assert result.exceptions and "YAML" in result.exceptions[0]


def test_convert_string_to_list_reads_a_json_array_and_writes_it_back(flows):
    back = FlowBuilder("clist_roundtrip")
    read = back.action("Action_Convert_string_to_list", Varname="myList", VarValue='[1,"x"]', expression="String",
                       listToStringOutputFormat="JSON")
    write = back.action("Action_Convert_list_to_string", Varname="x", ListName="myList",
                        listToStringOutputFormat="JSON", compactMode=1)
    back.chain(back.trigger(), read, write, back.probe("x"))
    run = run_all(flows, [back])[0]
    assert text_of(run) == '[1,"x"]'


def test_convert_string_to_list_errors_are_exceptions(flows):
    runs = run_all(flows, [
        json_flow("cstr_broken", "[1,", "Action_Get_From_List", Varname="x", ListName="myList",
                  WhichPosition="First"),
        json_flow("cstr_scalar", "5", "Action_Get_From_List", Varname="x", ListName="myList",
                  WhichPosition="First"),
        json_flow("cstr_yaml", "a: 1", "Action_Get_From_List", Varname="x", ListName="myList",
                  WhichPosition="First"),
    ])
    assert runs[0].exceptions and "Error converting string to list" in runs[0].exceptions[0]
    assert runs[1].exceptions and "JSON object or array" in runs[1].exceptions[0]
    assert runs[2].exceptions
