# EventForge - THE GAME MODE WORDS THE VOCABULARY ITSELF WRITES: the two trigger ids, the signal
# they hang off, and the name of the parameter that says which mode.
#
# They live here, beside the other word tables, rather than with the reader that answers questions
# ABOUT a sheet's modes, and the reason is a measured one. The Game State module is built during the
# first sheet tab of a session, along with every other vocabulary module, and a module compiles
# everything it NAMES: naming the reader - which reaches the sheet resource, the group facts and the
# editor's own translation seam - put that whole subtree into the descriptor build, and cost the
# first tab about 150 ms it never needed to pay (about 790 ms in a process with no editor around it,
# such as a headless test run or a doc build). The four words below are frozen strings with no
# dependencies at all, so a module naming this file compiles this file and nothing else.
#
# THERE IS STILL ONE SOURCE OF TRUTH. The reader declares its own constants AS these, so a change
# here is a change everywhere, and no second spelling can drift into existence.
#
# The ids are ace_ids: frozen once shipped, like every other ace_id. Deprecate, never rename.
@tool
class_name EventForgeModeWords
extends RefCounted

## The two triggers of the moment a mode changes. On leaving fires before On entering, always.
const ENTERING_TRIGGER_ID: String = "OnEnteringMode"
const LEAVING_TRIGGER_ID: String = "OnLeavingMode"

## The signal both of them hang off - the one the mode variable's own setter emits.
const CHANGED_SIGNAL: String = "mode_changed"

## The parameter every mode row takes: which mode, as a member of the sheet's own Mode enum.
const MODE_PARAM: String = "mode"
