"""WI-0124: end-to-end tests of the sound and speech elements of the package Default: Play sound, Stop sound, Beep, Get volume,
Set volume and Speech output. The sound and speech calls go through SystemOps (E0103): the test provider records each call
with its arguments and answers from a script, so no sound is played, nothing is spoken and the volume is not changed.
Get volume only reads the volume (no seam, ELEMENT-API-V2 3.3a): that test reads the real volume and checks its range.

The sound files of the tests are empty files of the test folder (the provider does not play them).
"""

import os
from pathlib import Path

import pytest

from support.coreflows import run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)
from support.system import SystemScript, error, value

VOICE = "Test Voice Anna"


@pytest.fixture
def system(flows):
    """The script of the system provider: no answers, so every call returns the empty value and is only recorded."""
    script = SystemScript(flows.datadir)
    script.script({})
    return script


def element_flow(name, cls, probe=None, **pars):
    """trigger -> the element -> (probe of a variable)."""
    fb = FlowBuilder(name)
    el = fb.action(cls, **pars)
    parts = [fb.trigger(), el]
    if probe:
        parts.append(fb.probe(probe))
    fb.chain(*parts)
    return fb


def calls(system, function):
    return [c for c in system.requests() if c["function"] == function]


def message_of(run):
    assert run.exceptions, run.steps
    return run.exceptions[0]


def sound_file(tmp_path: Path, name="ping.wav") -> str:
    path = tmp_path / name
    path.write_bytes(b"")
    return str(path)


# --- Play sound -------------------------------------------------------------------------------------------------------
def test_play_a_sound_file_without_waiting(flows, system, tmp_path):
    path = sound_file(tmp_path)
    runs = run_all(flows, [element_flow("play_file", "Action_Play_Sound", WhichSound="SoundFile", soundfile=path,
                                        WaitUntilFinished=0)])
    assert not runs[0].exceptions, runs[0].steps
    found = calls(system, "SoundPlay")
    assert found and found[-1]["args"] == [path, 0], system.requests()


def test_play_a_sound_file_and_wait_until_it_has_finished(flows, system, tmp_path):
    path = sound_file(tmp_path)
    runs = run_all(flows, [element_flow("play_wait", "Action_Play_Sound", WhichSound="SoundFile", soundfile=path,
                                        WaitUntilFinished=1)])
    assert not runs[0].exceptions, runs[0].steps
    assert calls(system, "SoundPlay")[-1]["args"] == [path, 1]


def test_play_a_system_sound_uses_the_media_folder_of_windows(flows, system):
    name = "tada.wav"
    full = os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "media", name)
    if not os.path.isfile(full):
        pytest.skip("the system sound %s is not installed on this machine" % full)
    runs = run_all(flows, [element_flow("play_system", "Action_Play_Sound", WhichSound="SystemSound",
                                        systemSound=name, WaitUntilFinished=0)])
    assert not runs[0].exceptions, runs[0].steps
    assert calls(system, "SoundPlay")[-1]["args"][0].lower() == full.lower()


def test_play_a_missing_sound_file_is_an_exception(flows, system, tmp_path):
    missing = str(tmp_path / "missing.wav")
    runs = run_all(flows, [element_flow("play_missing", "Action_Play_Sound", WhichSound="SoundFile", soundfile=missing)])
    assert "Sound could not be played" in message_of(runs[0])
    assert not calls(system, "SoundPlay")


def test_a_failing_sound_call_is_an_exception(flows, system, tmp_path):
    system.script({"SoundPlay": [error("device busy")]})
    runs = run_all(flows, [element_flow("play_fails", "Action_Play_Sound", WhichSound="SoundFile",
                                        soundfile=sound_file(tmp_path))])
    assert "Sound could not be played" in message_of(runs[0])


# --- Stop sound -------------------------------------------------------------------------------------------------------
def test_stop_sound_calls_the_seam(flows, system):
    runs = run_all(flows, [element_flow("stop", "Action_Stop_Sound")])
    assert not runs[0].exceptions, runs[0].steps
    assert calls(system, "SoundStop"), system.requests()


def test_a_failing_stop_is_an_exception(flows, system):
    system.script({"SoundStop": [error("no sound")]})
    runs = run_all(flows, [element_flow("stop_fails", "Action_Stop_Sound")])
    assert "Sound could not be stopped" in message_of(runs[0])


# --- Beep -------------------------------------------------------------------------------------------------------------
def test_beep_sends_frequency_and_duration(flows, system):
    runs = run_all(flows, [element_flow("beep", "Action_Beep", frequency="440", duration="200")])
    assert not runs[0].exceptions, runs[0].steps
    assert calls(system, "SoundBeep")[-1]["args"] == [440, 200]


def test_beep_with_a_frequency_out_of_range_is_an_exception(flows, system):
    runs = run_all(flows, [element_flow("beep_low", "Action_Beep", frequency="20", duration="100")])
    assert "37 to 32767" in message_of(runs[0])
    assert not calls(system, "SoundBeep")


def test_beep_with_an_expression_that_is_no_number_is_an_exception(flows, system):
    runs = run_all(flows, [element_flow("beep_bad", "Action_Beep", frequency="440", duration="1 +")])
    assert runs[0].exceptions, runs[0].steps
    assert not calls(system, "SoundBeep")


# --- Get volume -------------------------------------------------------------------------------------------------------
def test_get_volume_stores_the_master_volume_in_the_variable(flows):
    runs = run_all(flows, [element_flow("get_volume", "Action_Get_Volume", probe="Volume", Varname="Volume")])
    if runs[0].exceptions:
        pytest.skip("no sound device answers on this machine: %s" % runs[0].exceptions[0])
    assert 0.0 <= float(runs[0].seen["Volume"].text) <= 100.0


# --- Set volume -------------------------------------------------------------------------------------------------------
@pytest.mark.parametrize("mute, expected", [("On", 1), ("Off", 0), ("Toggle", -1)])
def test_set_volume_mute_states(flows, system, mute, expected):
    runs = run_all(flows, [element_flow("mute_" + mute, "Action_Set_Volume", Action="Mute", Mute=mute)])
    assert not runs[0].exceptions, runs[0].steps
    assert calls(system, "SoundSetMute")[-1]["args"] == [expected], system.requests()


def test_set_volume_absolute_sets_the_volume(flows, system):
    runs = run_all(flows, [element_flow("absolute", "Action_Set_Volume", Action="Absolute", volume="30")])
    assert not runs[0].exceptions, runs[0].steps
    assert float(calls(system, "SoundSetVolume")[-1]["args"][0]) == 30


def test_set_volume_relative_up_sends_a_plus_sign(flows, system):
    runs = run_all(flows, [element_flow("up", "Action_Set_Volume", Action="Relative", volumeRelative="10")])
    assert not runs[0].exceptions, runs[0].steps
    assert calls(system, "SoundSetVolume")[-1]["args"] == ["+10"]


def test_set_volume_relative_down_sends_the_negative_amount(flows, system):
    runs = run_all(flows, [element_flow("down", "Action_Set_Volume", Action="Relative", volumeRelative="-5")])
    assert not runs[0].exceptions, runs[0].steps
    assert float(calls(system, "SoundSetVolume")[-1]["args"][0]) == -5


def test_a_failing_volume_call_is_an_exception(flows, system):
    system.script({"SoundSetVolume": [error("no device")]})
    runs = run_all(flows, [element_flow("volume_fails", "Action_Set_Volume", Action="Absolute", volume="30")])
    assert "Volume could not be set" in message_of(runs[0])


# --- Speech output ----------------------------------------------------------------------------------------------------
def speech_flow(name, **pars):
    return element_flow(name, "Action_Speech_output", **pars)


def test_speech_output_passes_the_text_voice_and_options(flows, system):
    system.script({"SpeechVoices": [value([VOICE])]})
    runs = run_all(flows, [speech_flow("speech", text="Hello there", TTSEngine=VOICE, speed="2", pitch="-3",
                                       volume="80", WaitUntilPreviousFinished=0, WaitUntilCurrentFinishes=1)])
    assert not runs[0].exceptions, runs[0].steps
    found = calls(system, "SpeakText")
    assert found, system.requests()
    text, voice, rate, volume, pitch, wait, purge = found[-1]["args"]
    # the slider value may arrive as text: the numbers are compared as numbers
    assert (text, voice, wait, purge) == ("Hello there", VOICE, 1, 1), found[-1]["args"]
    assert (float(rate), float(volume), float(pitch)) == (2, 80, -3), found[-1]["args"]


def test_speech_output_waits_for_the_previous_speech_when_asked(flows, system):
    system.script({"SpeechVoices": [value([VOICE])]})
    runs = run_all(flows, [speech_flow("speech_wait_prev", text="Second", TTSEngine=VOICE,
                                       WaitUntilPreviousFinished=1, WaitUntilCurrentFinishes=1)])
    assert not runs[0].exceptions, runs[0].steps
    names = [c["function"] for c in system.requests() if c["function"] in ("SpeechWait", "SpeakText")]
    assert names == ["SpeechWait", "SpeakText"], system.requests()
    assert calls(system, "SpeakText")[-1]["args"][6] == 0      # no purge: the previous speech was waited for


def test_speech_output_without_waiting_speaks_asynchronously(flows, system):
    runs = run_all(flows, [speech_flow("speech_async", text="Later", TTSEngine="", WaitUntilCurrentFinishes=0)])
    assert not runs[0].exceptions, runs[0].steps
    args = calls(system, "SpeakText")[-1]["args"]
    assert args[1] == "" and args[5] == 0, args
    assert not calls(system, "SpeechWait")


def test_speech_output_with_a_voice_that_is_not_installed_is_an_exception(flows, system):
    runs = run_all(flows, [speech_flow("speech_missing", text="Hi", TTSEngine="Nobody Voice")])
    assert "Could not find TTS engine 'Nobody Voice'" in message_of(runs[0])
    assert not calls(system, "SpeakText")


def test_a_failing_speech_call_is_an_exception(flows, system):
    system.script({"SpeechVoices": [value([VOICE])], "SpeakText": [error("sapi lost")]})
    runs = run_all(flows, [speech_flow("speech_fails", text="Hi", TTSEngine=VOICE)])
    assert "Error on speech output" in message_of(runs[0])
