# Multiplayer with Godot's Built-in Tools

Playing together over a network, as rows. Nothing here is a networking layer: every row on the
**Multiplayer** object compiles to exactly the Godot call it names - `ENetMultiplayerPeer`,
`MultiplayerAPI`'s own signals, `set_multiplayer_authority`, `OS.has_feature` - so the script a
sheet writes is the script the Godot documentation would have you write by hand, and a project that
already wrote those lines opens on the same rows.

This page covers hosting and joining, the events the connection fires, the messages peers send each
other, who is allowed to run what, spawning a scene on every peer, keeping a value in step and
deciding who may see it, the lobby and the handshake, testing the whole thing as two players, the
four mistakes the Project Doctor knows, and what a networked project you already wrote opens as.

## Table of Contents

1. [Host a game, join a game, leave](#host-a-game-join-a-game-leave)
2. [The events the connection fires](#the-events-the-connection-fires)
3. [Who is in the game, and who sent this](#who-is-in-the-game-and-who-sent-this)
4. [Messages: the calls that travel](#messages-the-calls-that-travel)
5. [Who runs what](#who-runs-what)
6. [Objects have owners](#objects-have-owners)
7. [Spawning a scene on every peer](#spawning-a-scene-on-every-peer)
8. [Keeping a value in step](#keeping-a-value-in-step)
9. [Who is allowed to see it](#who-is-allowed-to-see-it)
10. [The lobby and the handshake](#the-lobby-and-the-handshake)
11. [The fields, explained while you fill them in](#the-fields-explained-while-you-fill-them-in)
12. [Testing it as two players](#testing-it-as-two-players)
13. [The four mistakes the Doctor knows](#the-four-mistakes-the-doctor-knows)
14. [Slotting into a project you already wrote](#slotting-into-a-project-you-already-wrote)

## Host a game, join a game, leave

Three actions, on the **Multiplayer** object. Host a game opens this game to other players and makes
this peer the host - the one whose answers everybody else takes as true:

```gdscript
extends Control


func _ready() -> void:
	$HostButton.pressed.connect(_on_host_button_pressed)


func _on_host_button_pressed() -> void:
	var __peer := ENetMultiplayerPeer.new()
	__peer.create_server(7000, 8)
	multiplayer.multiplayer_peer = __peer
```

Join a game is the same three lines with `create_client` and an address instead:

<!-- caption: Join a game at 127.0.0.1 port 7000 - the same three lines, pointed at a host. -->

```gdscript
extends Control


func _ready() -> void:
	$JoinButton.pressed.connect(_on_join_button_pressed)


func _on_join_button_pressed() -> void:
	var __peer := ENetMultiplayerPeer.new()
	__peer.create_client("127.0.0.1", 7000)
	multiplayer.multiplayer_peer = __peer
```

They are one row each rather than three, because they are one decision: a reader who splits them
has a half-connected game. **Leave the game** is the other end of it - it clears
`multiplayer.multiplayer_peer`, which puts the game back to single player. On the host that ends the
game for everybody, because there is nobody left to answer them.

Neither row connects anything by the time it finishes. Hosting means "the door is open" and joining
means "I knocked"; what happened next arrives as an event.

## The events the connection fires

Seven, all off the `multiplayer` property every node has: five that `MultiplayerAPI` declares, and
the two `SceneMultiplayer` adds for the handshake (*On player authenticating*, *On authentication
failed*). Each is connected in `_ready` exactly as a hand-written script connects them.
**Add event ▸ Multiplayer** sorts them onto three shelves:

- **Players** - *On player joined*, *On player left*, *On player authenticating*,
  *On authentication failed*. Each hands you that player's id as a chip every row beneath can use.
- **Connection** - *On joined the host*, *On join failed*, *On the host left*. None of them is about
  a particular player; they say what happened to this peer's own connection.
- **Scenes** - what a `MultiplayerSpawner` or a `MultiplayerSynchronizer` in the scene just did.

The host is the peer that hears **On player joined**, and it is where a new player is given whatever
they need:

```gdscript
extends Node


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_player_joined)


func _on_player_joined(id: int) -> void:
	print("player %d arrived" % id)
```

**On the host left** is the one people forget. Every remaining peer gets it when the host goes away,
and without it a client sits in a game that no longer exists.

## Who is in the game, and who sent this

Four expressions and two conditions answer the questions a networked rule asks:

| Row | What it gives you |
| --- | --- |
| **Players** | The ids of every OTHER peer, as a list (`multiplayer.get_peers()`). |
| **Player count** | How many other peers there are. Add one for this peer when a player reads the number. |
| **My ID** | This peer's own id. The host is always 1. |
| **Sender** | Inside a message, the id of the peer that sent it. It is 0 anywhere else. |
| **Owner of X** | The id of the peer allowed to move an object. |
| **Is connected** | True once this peer is really in a game - false while a join is still being answered. |
| **Is host** | True on the peer that called Host a game. |

**Sender** is the one thing a message cannot lie about, so a host that acts on what a client asked
for should check it before trusting the rest.

## Messages: the calls that travel

A message is an ordinary function with one extra line above it. Godot's `@rpc` annotation is what
makes calling it reach the other peers, and it answers three questions plus a channel. Right-click a
function row and choose **Make It A Message…** to answer them in words (**New Function ▸ Message…**
asks for the name and the parameters first, then the same four):

| Question | The answers | What Godot writes |
| --- | --- | --- |
| **Who may send** | *Anyone* / *Only the owner* | `"any_peer"` / `"authority"` |
| **Where it runs** | *On the others* / *On the others, and here too* | `"call_remote"` / `"call_local"` |
| **Delivery** | *Reliable* / *Fast, may drop* / *Fast, in order* | `"reliable"` / `"unreliable"` / `"unreliable_ordered"` |
| **Channel** | a number, 0 unless something big is in the way | the trailing `0`, `1`, `2`… |

*Only the owner* is the safe answer: a call from anybody else is dropped and logged. Pick *Anyone*
for the things a client has to be able to ask the host for, and check **Sender** before acting on
anything a player could have made up. *and here too* is why the shot you fired lands for you at the
same moment as for everybody else. *Reliable* is for what happens once (a hit, a pickup, a round
starting); the two fast ones are for a value that is replaced several times a second anyway.

The row then reads the annotation back in those words and echoes the line itself at its right edge:

<!-- caption: A message, and the row it reads as: message take_damage(amount)  from the owner · also here · reliable -->

```gdscript
extends CharacterBody2D

var hp: int = 100


@rpc("authority", "call_local", "reliable")
func take_damage(amount: int) -> void:
	hp -= amount
```

Read as an event, the same head says **On message take_damage** - because a message is not a
function this peer calls, it is one that arrives. An option Godot does not take (a typo in the
annotation) reads as no words at all: the row shows the annotation as it stands and an amber note
under it names the string that stopped the reading, so the sheet never guesses at what the file
meant.

### Sending one

**Add action ▸ Multiplayer ▸ Send message** opens one dialog for all three destinations: which
message (the list holds only the functions this sheet marks), a field per parameter of that message,
and **To**.

| To | Who runs it | The line |
| --- | --- | --- |
| **Everyone** | every connected peer, and this one too when the message says *also here* | `take_damage.rpc(10)` |
| **The host** | peer 1 only - how a client asks for something it may not decide by itself | `take_damage.rpc_id(1, 10)` |
| **One player** | the peer whose id you give - the event's own id, or **Sender** | `take_damage.rpc_id(Multiplayer.Sender, 10)` |

The row belongs to the object whose function the message is, so it reads
`Player ▸ Send take_damage(10) to everyone` rather than filing every message under the Multiplayer
object. Naming a function that is not marked as a message says so in amber before the row is
written: that call compiles, and then quietly never travels.

Confirming a message dialog you did not change writes nothing at all - the annotation comes back
verbatim, a partial `@rpc("any_peer")` included - so opening one to read it cannot rewrite the file.

## Who runs what

The commonest multiplayer bug is a rule that runs on every peer when it should run once, or on every
copy of a player when only its owner should move it. The sheet's answer is a group that says who runs
it: **Edit group… ▸ Runs on**, or right-click the head ▸ **Runs On**.

- **Everyone** - the default. Every peer runs these events. Right for anything a player sees or
  hears, and for a game with no networking in it. It writes nothing at all.
- **The host** - only the peer that called Host a game. Right for anything that decides what is
  true; the others learn the result through a message or a value kept in step.
- **The owner** - only the peer that owns this object. Right for what each player controls about
  their own character, so nobody moves anybody else's.

The head shows the answer as one muted word beside the group's name, and the compiler wraps the
group's events in the matching test:

<!-- caption: A group that runs on the owner, and the test the compiler wraps its events in. -->

```gdscript
extends CharacterBody2D
## @ace_group(uid="movement", name="Movement", runs_on="owner")


func _physics_process(delta: float) -> void:
	# @group:movement
	if is_multiplayer_authority():
		move_and_slide()
```

Nested groups inherit until one answers for itself, and then the innermost answer wins - it is the
one the reader put closest to the rows. A group that also has **Can be switched at runtime** asks the
switch first and who-runs-it second.

The answer lives in the group's own `## @ace_group(...)` header, so it rides the file. Opening that
file again puts the word back on the group and takes the guard back off the events, and re-saving
reproduces the file byte for byte. Single player is untouched either way: `multiplayer.is_server()`
is true when no peer is connected at all.

If a project already repeats an **Is host** condition on every event of a group, picking *The host*
for that group folds those conditions into the one word rather than asking the test twice.

## Objects have owners

An object's owner is the peer allowed to move and change it; everybody else has a copy they may only
read. **Owns this object** is the question, **Give X to player** is how it changes, and **Owner of
X** is who it is now. The usual moment to hand one over is the spawn:

```gdscript
extends CharacterBody2D


func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())
```

That is the spelling Godot's own samples use - name the spawned copy after the player's id, and the
copy makes that player its owner. The sheet head reads the line back as a fact about the script, so
you can see who owns an object without going looking for the call.

## Spawning a scene on every peer

A `MultiplayerSpawner` is the node that makes one copy of a scene appear on the host and on every
connected peer at once. You put it in the scene, tell it in the Inspector which scenes it may make
(*Auto spawn list*) and where the copies go (*Spawn path*), and from then on the sheet has a verb on
it: **Spawn**, on the spawner as its object, asking four things - which scene, what to call the
copy, where to put it, and which spawner is watching.

```gdscript
extends Node2D


func _ready() -> void:
	$Spawner.spawned.connect(_on_spawner_spawned)


func welcome(id: int) -> void:
	var player = load("res://player.tscn").instantiate()
	player.name = str(id)
	player.position = Vector2(0, 0)
	$Spawner.get_node($Spawner.spawn_path).add_child(player, true)


func _on_spawner_spawned(node: Node) -> void:
	print(node.name)
```

Those four lines are the whole of Godot's automatic spawning, and the row is exactly them. Make the
copy, name it, place it, and hand it to the node the spawner watches - the spawner sees the child
arrive and sends it to everybody else. The name is set BEFORE the copy joins the tree because the
name travels with it, and naming a player's copy after their peer id is what lets the copy make that
player its owner (see *Objects have owners*, above). Run it on the host: everybody else receives the
copy rather than making one.

The *Scene* field offers the spawner's own list, and it will take a path that is not in the list
yet - the help strip says so while you are typing, and pressing OK adds that scene to the list as
one step of the SCENE's undo, beside the row's own. That matters, because a spawner will not
replicate a scene it does not know: without the list entry the copy appears on the peer that made it
and nowhere else. The *Spawner* field's strip says the spawn limit when the spawner has one - past
that many copies it refuses to make another until one goes.

**Despawn** is the other half, and it is one line: `queue_free()`. Run it on the peer that owns the
copy; the spawner that made it sees it go and removes it everywhere else, so nothing has to be sent
by hand. **On spawned** and **On despawned** are the spawner's own two events, and they run on every
peer - the host included - with the copy as the event's chip, which is where a name is added to a
scoreboard or a camera is pointed at something.

If a spawner builds its copies out of a value instead of from a scene path - a dictionary read by
its `spawn_function` - that is the older **Spawn** row, which writes `$Spawner.spawn(data)` and says
nothing about the list.

## Keeping a value in step

A `MultiplayerSynchronizer` is the node that copies named properties from the peer that owns an
object to every other peer. Which properties, in which mode and how often are the SCENE's facts
rather than the script's: Godot writes them into the `.tscn` from its own Replication panel, and the
sheet reads them instead of keeping a second copy.

That reading reaches you in three places:

- **On the sheet head**, one *keeps in step* band per synchronizer watching this object -
  *PlayerSync · position, hp always · nickname at spawn · every 0.05 s · seen by everyone* - whose
  control opens that scene on that node, because the Replication panel is the other editor of the
  same fact.
- **On the variable row**, a 15px mark after the name: a box with two short bars in it, hovering
  *PlayerSync · on change*.
- **In the row's own menu**: right-click a variable ▸ **Keep in Step ▸** Off / Always / On change /
  At spawn only, and the same dropdown in **Edit variable… ▸ More options**. The write goes into the
  scene as one step of the SCENE's undo history, and the menu offers to add a synchronizer when the
  scene has none yet.

| Mark | Mode | What it does at runtime |
| --- | --- | --- |
| solid | always | sent every tick, whether the value changed or not |
| dotted | on change | sent when the value moves, and not otherwise |
| dashed | at spawn | sent once, with the copy, and never again |

Two things follow from a value being kept in step. It travels from the OWNER outwards, so a peer
that does not own the object may write its copy and have the next packet overwrite it - which is why
editing such a value on the canvas says `set by the owner` beside the field. And every value the
host changes that nothing keeps in step and no message carries stays on the host: that is the second
of the four findings below, and this menu is its one-click fix.

Nothing is written into the `.gd` for any of it. A sheet whose scene has no synchronizer gets no
bands, no marks and no menu entry, and the file round-trips byte for byte either way.

## Who is allowed to see it

A `MultiplayerSynchronizer` copies the properties it lists from the owner to everybody else. By
default everybody receives them, and three rows on the synchronizer change that per player:

```gdscript
extends Node2D


func _ready() -> void:
	$HandSync.synchronized.connect(_on_handsync_synchronized)


func deal_in(id: int) -> void:
	$HandSync.set_visibility_for(id, true)


func fold(id: int) -> void:
	$HandSync.set_visibility_for(id, false)


func showdown() -> void:
	$HandSync.public_visibility = true
	$HandSync.add_visibility_filter(can_see)


func can_see(peer: int) -> bool:
	return peer != 0


func _on_handsync_synchronized() -> void:
	print("a new hand arrived")
```

**Show to player** and **Hide from player** decide one peer at a time; **Show to everyone** puts the
node back to being public, whatever was set per peer before. A hidden node is not deleted on that
peer - it simply stops arriving, which is the point: a value a player was never meant to see is not
in their packets either, so it cannot be read out of them.

When the rule is a rule rather than a list, hand it to a function instead. **Ask X who may see it**
writes `add_visibility_filter`, and the function it names is asked with one peer id and answers true
or false - again as players come and go, so a rule like *same room* or *same team* keeps itself true
with no row saying so. The function's own row in the sheet then leads with the words `visibility
filter`, and says which synchronizer asks it. Nothing is written into the `.gd` to mark it: being a
filter IS the row that hands the function over, so deleting that row makes it an ordinary function
again with nothing to clean up.

**On synchronized** is the synchronizer's own event: it runs on a peer that has just been sent new
values, which is where something has to answer a value that ARRIVED rather than one this peer
changed itself.

## The lobby and the handshake

Once players are arriving, four more rows run the lobby:

- **Kick player** drops one connection (`disconnect_peer`). Only the host may do it; a client that
  wants somebody kicked sends the host a message and lets it decide.
- **Stop accepting players** closes the lobby without ending the game - everybody already in stays,
  nobody else gets in.
- **Relay messages between players** decides whether the host forwards a client's message on to the
  other clients. Off is the safer setting for a game where the host decides what is true.
- **Started as** asks which build this is (`OS.has_feature`), so one project can host itself, join
  itself, or run headless as a dedicated server. `host` and `client` are tags you add to two export
  presets yourself; `dedicated_server` is the one Godot's own server preset sets, and that build is
  run with `--headless`.

The handshake is for a game that wants a password, a token or a version check before a peer counts
as joined. **On player authenticating** runs on the host while the peer is still proving who it is -
before On player joined - and it is answered with **Accept player** (`complete_auth`) or **Reject
player**. **Send auth** is how either side sends the bytes the other checks. A peer that is never
answered simply waits, so every handshake needs one of the two.

<!-- caption: A host that lets everybody in, and closes the lobby when the match starts. -->

```gdscript
extends Node


func _ready() -> void:
	multiplayer.peer_authenticating.connect(_on_player_authenticating)


func start_the_match() -> void:
	multiplayer.multiplayer_peer.refuse_new_connections = true


func _on_player_authenticating(id: int) -> void:
	multiplayer.complete_auth(id)
```

## The fields, explained while you fill them in

The Parameters dialog's help strip describes whichever field has focus, and for the networking rows
it says the things people go and look up:

- **Port** - the door players knock on. 7000 to 65535 are free for games, below 1024 needs admin
  rights, and the joining side must use the same number as the host.
- **Address** - 127.0.0.1 reaches a host on this same machine; on one network it is the host's local
  address; across the internet the host has to forward the port on its router or go through a relay.
- **Players** - how many OTHER peers may connect, so the host plus that many people are in the game.
  Each one costs the host bandwidth every tick, for every value it keeps in step.
- **Using** - ENet is Godot's own default; a browser export can only open WebSocket; WebRTC goes
  browser to browser through a signalling server you run. Both sides must pick the same one.
- **Scene** - the list is the spawner's own, from the Inspector. A path that is not in it yet is
  added when you press OK, because a spawner only replicates scenes it lists.

## Testing it as two players

A networked game needs two copies of itself running before anything about it can be seen. Godot can
already do that - Debug ▸ Run Multiple Instances - and hardly anybody finds it, so the play
button's dropdown carries **Play as host + client**, beside Run Scene. One click sets that dialog to two instances, gives
the first the feature tag `host` and the second the tag `client`, and then plays the scene this sheet
is attached to. Nothing about it is this plugin's: the button writes the editor's own setting, the
dialog shows what it wrote, and unticking **Enable Multiple Instances** there turns it off again.
Anything else you had set per instance, such as launch arguments, is left exactly as it was.

The tags are what let one project host itself and join itself. **Started as** writes
`OS.has_feature`, so an On ready event can ask which copy it is (a file that already asks that
question keeps the older **Platform Has Feature** row it was written with - one line, two ways of
picking it):

<!-- caption: One project, two windows: the copy started with the host tag opens the game, the other joins it. -->

```gdscript
extends Node


func _ready() -> void:
	if OS.has_feature("host"):
		var __peer := ENetMultiplayerPeer.new()
		__peer.create_server(7000, 8)
		multiplayer.multiplayer_peer = __peer
```

Put **Join a game at 127.0.0.1 port 7000** on the Else beneath it and both windows sort themselves
out on launch.

While both are running, a variable row's live value grows one chip per instance, headed by the tag
that copy was started with: `host · now 100   client · now 90`. A lone run is not labelled at all,
because there is nothing to tell apart. Godot's own Debugger ▸ Network tab is where the per-message
send and receive counts live; the editor keeps those to itself, so the sheet does not repeat them.

### As a dedicated server

A dedicated server is the same project running where nobody is playing. Godot's own Dedicated Server
export preset sets the `dedicated_server` feature tag and leaves out what a server has no use for,
and the build is started with `--headless` - no window, no rendering, no audio.

Nothing about the sheet changes for it. **Started as dedicated_server** is the row that tells that
build apart, **Host a game** is the same row it always was, and the peers that join are the same
peers - a server is simply a host with no player on it, still peer 1. What such a build must not do
is anything that expects a screen or a player, so keep the rows that draw, play a sound or read
input out of the events a server runs, and let messages and the values kept in step carry the
result to the peers that do have a screen.

## The four mistakes the Doctor knows

Networking bugs are silent. The game runs, nothing is printed, and the other player sees nothing.
Four of them cost every beginner an evening, and each one is a question the sheet can answer about
itself, so the Project Doctor asks it and the sheet says the answer under the row it is about:

- **Sent but not a message.** A Send row names a function of this sheet that carries no `@rpc`. It
  compiles, and then nothing travels. The note offers **Make X a message…**, which is the Message
  dialog on that function.
- **Changed on the host, seen nowhere.** A variable written inside a group that runs on the host,
  which no synchronizer keeps in step and no message carries. The host's copy changes and everybody
  else goes on showing the old value. The note offers **Keep in step**, which hands the value to a
  synchronizer in the scene - adding one if the scene has none yet.
- **Moved by everyone.** A row that moves an object every peer keeps in step, with nothing saying
  only its owner may. Each peer moves its own copy and the owner's corrections fight them. The note
  offers **Wrap in an owner group**, which puts the event in a group that runs on the owner.
- **Trusting the sender.** A message anyone may send that writes a value every peer keeps in step
  without ever asking **Sender**. A player can send that message themselves, so the value is theirs
  to choose. There is no one-click answer to this one: the note names the message and the value, and
  what to do about it is a decision about your game.

A sheet that says nothing about the network is never judged by any of them, so a single-player
project grows no notes it did not have before.

Tools ▸ Project Doctor gathers the same four into a **Multiplayer** section, over the whole project
rather than the open sheet. It leads with one line - how many scripts touch the network and how much
of what they say about it read as rows - then a line per script with networking the sheet could only
show as code, naming the first such line, then the findings. Double-clicking any of them opens that
script as a sheet; the Adopt offer lives on the block's own row, where the diff can be shown before
anything changes. The section is registered through `EventSheets.register_doctor_check`, the same
public seam a pack uses, so a pack that adds its own networking adds its scripts to this section
rather than starting a second report.

## Slotting into a project you already wrote

Everything above is also a READING. A networked project written before this plugin existed opens on
these rows without a byte changing, because each recogniser stores the spelling it matched ON the
row and re-emits that spelling - so the file that opened is the file that saves, and nothing on disk
changes until you edit a row, and then only that row's lines.

This is the whole table of what is recognised. Where two spellings of one thing are listed together,
both open as the same row and each saves back as itself:

| What you wrote | Reads as |
| --- | --- |
| `var peer := ENetMultiplayerPeer.new()`, `peer.create_server(PORT, MAX)`, `multiplayer.multiplayer_peer = peer` - the three-line form Godot's own documentation uses | **Host a game on port PORT for up to MAX players** |
| the same three lines with `peer` declared at the top of the file instead of beside them | the same row, using that variable |
| the `create_client(address, PORT)` twin of either | **Join a game at address port PORT** |
| `multiplayer.multiplayer_peer = null`, `peer.close()`, or the `get_tree().get_multiplayer()` spelling of the first | **Leave the game** |
| `WebSocketMultiplayerPeer` or `WebRTCMultiplayerPeer` in the constructor | the same rows, with that peer kind |
| `multiplayer.<signal>.connect(...)` for any of the seven signals | the seven events, with the connect line re-emitted exactly as written |
| `@rpc(...)` above a function, in any order or subset of the options, with or without a channel | that function's **message** row and its words, with the annotation itself as the row's echo |
| `f.rpc(10)`, `rpc("f", 10)`, `rpc(&"f", 10)`, `rpc_id(1, &"f", 10)`, `f.rpc_id(peer, 10)`, `$Other.f.rpc(...)` | the three **Send** rows, each keeping your own quoting |
| `multiplayer.multiplayer_peer.disconnect_peer(id)`, `refuse_new_connections = true`, `multiplayer.server_relay = false` | **Kick player**, **Stop accepting players**, **Relay messages between players off** |
| `multiplayer.complete_auth(id)`, `multiplayer.send_auth(id, bytes)` | **Accept player**, **Send auth** |
| `multiplayer.get_peers()`, `.size()`, `multiplayer.get_remote_sender_id()`, `X.get_multiplayer_authority()` | **Players**, **Player count**, **Sender**, **Owner of X** |
| `OS.has_feature("dedicated_server")` | **Platform Has Feature** - the same line **Started as** writes, so a file that already asked keeps the row it was written with |
| `set_multiplayer_authority(str(name).to_int())`, `(name.to_int())` or `(id, true)` in `_enter_tree` or `_ready` | the head's owner band - who owns this object |
| `if not is_multiplayer_authority(): return`, and the `if is_multiplayer_authority():` that wraps a whole body (the `multiplayer.is_server()` pair too) | who runs this function; the early-return form keeps its `return` |
| `## @ace_group(name="Scoring", runs_on="host")` and the guard the group wraps its events in | the group's **Runs on** word, with the guard off the rows |
| the four lines of an automatic spawn - instantiate, name, place, `add_child(copy, true)` under the spawner's `spawn_path` | one **Spawn a scene** row, re-emitting your own variable name, your `load` or `preload`, and whether you passed `true` |
| `$Spawner.spawn(id)`, `spawner.spawn({...})` | **Spawn**, with the spawner in the object column |
| `$Spawner.spawned.connect(...)`, `despawned`, `$Sync.synchronized.connect(...)` | **On spawned** / **On despawned** / **On synchronized**, on that node |
| `set_visibility_for(id, true)` / `(id, false)`, `public_visibility = true`, `add_visibility_filter(f)` | **Show to player** / **Hide from player** / **Show to everyone** / **Ask f who may see it** |

One line deliberately does NOT become a networking row: `queue_free()`. It is what **Despawn**
writes, but it is also the line every project writes to remove any node at all - the networked
meaning is in WHERE it runs, not in the line - so a bare `queue_free()` still reads **Queue free**,
and Despawn is a row you author rather than one a reading hands you.

The wire's own spellings read too. A `create_server` or `create_client` given channel or bandwidth
limits opens as **Host a game (Advanced)** / **Join a game (Advanced)** - the same three lines with
the dials said out loud - `peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)` reads
**Compress network traffic with range coder** with the receiver riding back out as you spelled it,
and `multiplayer.multiplayer_peer.put_packet(bytes)` reads **Send raw bytes** (its `get_packet()`
twin is the **Next raw packet** expression).

What no row can say stays code, on purpose and visibly: the
`var error = peer.create_client(...)` spelling that checks what the call answered, and a
`create_client` that binds its own local port. Those lines keep their script block, and the sheet
counts them out loud rather than rounding up:
*every networking line reads as a row - 9 of 9*, or the number it really is, on the head and again
per script in the Project Doctor's Multiplayer section.
