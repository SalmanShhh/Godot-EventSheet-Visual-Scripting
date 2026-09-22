# Top-Down Shooter Tutorial

Many people who made games in Construct 3 started with the same one: a player that faces the mouse, bullets, monsters that take a few hits, an explosion and a score. This page builds that game in Godot EventSheets, one row at a time, with the GDScript each row becomes written beside it. The finished game ships as the **Top-Down Shooter** showcase (`demo/showcase/top_down_shooter/`), and the Welcome window's **Build a top-down shooter (10 steps)** button walks the same ten steps beside your sheet, ticking each one off when the row lands.

The only new idea is step 6. Everything else is a habit you already have.

## Table of Contents

1. [What you are building](#what-you-are-building)
2. [The ten steps](#the-ten-steps)
3. [The two small sheets that go with it](#the-two-small-sheets-that-go-with-it)
4. [Picking, and why it is a For each here](#picking-and-why-it-is-a-for-each-here)

## What you are building

Four scenes, each with its own sheet:

| Scene | What it is | Its sheet does |
|---|---|---|
| `top_down_shooter.tscn` | the game: a Player and a score label | aims, fires, spawns monsters, blows up the ones with no health, shows the score |
| `bullet.tscn` | an Area2D with the Bullet behavior | faces the mouse when fired, hurts a monster it touches |
| `monster.tscn` | an Area2D, a **family** called ShooterMonster | walks toward the player |
| `explosion.tscn` | a particle burst | tidies itself away |

## The ten steps

**1. The player faces the mouse.** An event with no condition runs every tick.

```
Event: (every tick)
  Action: Player -> Set rotation to Player's direction to the mouse
```

```gdscript
func _process(delta: float) -> void:
	$Player.rotation = $Player.global_position.direction_to(get_global_mouse_position()).angle()
```

**2. Click fires.** A click is an input event, asked once per press.

```
Event: On Input
  Condition: On Mouse Button Pressed (event) -> MOUSE_BUTTON_LEFT
```

**3. A bullet appears at the player.** Create object is Spawn Scene At: the scene is the object type.

```
  Action: System -> Spawn Scene At "bullet.tscn" at Player.position
```

```gdscript
func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		var __spawn_bullet = load("res://demo/showcase/top_down_shooter/bullet.tscn").instantiate()
		__spawn_bullet.position = $Player.position
		add_child(__spawn_bullet)
```

**4. Monsters keep coming.** Every X seconds keeps its own clock.

```
Event: (every tick)
  Condition: Every 1.2 seconds
  Action: System -> Spawn Scene At "monster.tscn" at a random point on the top or bottom edge
```

**5. Keep a score.** A sheet variable belongs to the object the sheet is on - here, the game.

```gdscript
@export var score: int = 0
```

**6. A monster with no health explodes.** Press C, type `ShooterMonster health <= 0`, and pick the line the Ghost Row offers: **For each ShooterMonster where health ≤ 0**.

```
Event: (every tick)
  Condition: Shooter Monster -> Pick where shooter_monster's health ≤ 0
```

```gdscript
	for shooter_monster in get_tree().get_nodes_in_group("family_shooter_monster"):
		if not (shooter_monster.health <= 0):
			continue
```

**7. Boom, and a point.** The actions under the For each run once per monster it picked.

```
  Action: System -> Spawn Scene At "explosion.tscn" at shooter_monster.position
  Action: System -> Add 1 to score
  Action: shooter_monster -> Free Node
```

**8. Show the score.**

```
Event: (every tick)
  Action: Hud -> Set Text (formatted) "Score %d" with score
```

**9. Read what you wrote.** Menu ▸ View ▸ GDScript Panel shows every line above; clicking a line jumps to its row.

**10. Play the finished game.** Open the Start page's **Top-Down Shooter** and press the play button. Arrows move, clicking fires.

## The two small sheets that go with it

The bullet faces the mouse when it is fired, and hurts the monster it touches:

```
Event: On Ready
  Action: Bullet -> Set rotation to its direction to the mouse
  Action: System -> Wait 1.5 seconds
  Action: Bullet -> Queue Free
Event: On Area Entered (area)
  Condition: area is in group "family_shooter_monster"
  Action: System -> Add -1 to area.health
  Action: Bullet -> Queue Free
```

The monster joins its family and walks toward the player:

```
Event: On Ready
  Action: Monster -> Add to group "family_shooter_monster"
Event: (every tick)
  Action: Monster -> Set position to position.move_toward(the player's position, speed * delta)
```

## Picking, and why it is a For each here

In Construct 3 a condition on an object type picks the instances that pass it, and the actions below apply to those. A Godot script belongs to one node, so on the game's sheet "ShooterMonster health ≤ 0" has nothing to pick from - until it is said as a loop over every monster. The Ghost Row offers that loop the moment you type a condition on a family, and the row reads as the pick you meant. Nothing is hidden: the loop is a row you can read, and the file is the GDScript above.
