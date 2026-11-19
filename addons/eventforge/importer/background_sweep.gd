@tool
extends RefCounted

## One whole-project read, run on one of the engine's worker threads, with its answer taken back on
## the main thread. The scene indexes use it so a project of ten thousand files is never read while a
## frame waits: the index that was there goes on answering until the new one arrives.
##
## The work is a Callable that touches no shared state (it reads files and returns a value); the answer
## is only ever looked at through `finish()`, after the task has ended. Constructing the object starts
## the work, so `SWEEP.new(work)` is the whole call.

var _task_id: int = -1
var _work: Callable = Callable()
var _answer: Variant = null


func _init(work: Callable = Callable()) -> void:
	_work = work
	if work.is_valid():
		_task_id = WorkerThreadPool.add_task(_run, false, "event sheet scene index")


func _run() -> void:
	_answer = _work.call()


## Whether the work has ended. Never blocks.
func is_done() -> bool:
	return _task_id < 0 or WorkerThreadPool.is_task_completed(_task_id)


## Waits for the work if it has not ended, and returns what it computed.
func finish() -> Variant:
	if _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
	return _answer
