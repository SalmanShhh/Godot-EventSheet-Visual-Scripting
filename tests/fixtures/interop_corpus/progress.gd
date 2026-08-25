extends Node

## Fires after the experience bar rolls over into a new level.
signal leveled_up(new_level)
signal quest_completed(quest_id, reward)

var level = 1
var experience = 0


## Grants experience, and levels up when due.
func grant_xp(amount):
	experience += amount
	while experience >= 100:
		experience -= 100
		level += 1
		leveled_up.emit(level)


## Marks a quest done and pays out its reward.
func complete_quest(quest_id, reward):
	grant_xp(reward)
	quest_completed.emit(quest_id, reward)


func reset():
	level = 1
	experience = 0
