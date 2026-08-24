# Multiplayer with Godot's Built-in Tools

Playing together over a network, as rows. Nothing here is a networking layer: every row on the
**Multiplayer** object compiles to exactly the Godot call it names - `ENetMultiplayerPeer`,
`MultiplayerAPI`'s own signals, `set_multiplayer_authority`, `OS.has_feature` - so the script a
sheet writes is the script the Godot documentation would have you write by hand, and a project that
already wrote those lines opens on the same rows.

This page covers hosting and joining, the events the connection fires, the lobby and the
handshake, who is allowed to run what, and the fields the dialogs explain while you fill them in.

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

Seven, one per `MultiplayerAPI` signal, connected in `_ready` exactly as a hand-written script
connects them. **Add event ▸ Multiplayer** sorts them onto three shelves:

- **Players** - *On player joined*, *On player left*, *On player authenticating*, *On
  authentication failed*. Each hands you that player's id as a chip every row beneath can use.
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

```gdscript
extends CharacterBody2D

var hp: int = 100


@rpc("authority", "call_local", "reliable")
func take_damage(amount: int) -> void:
	hp -= amount
```

<!-- caption: A message, and the row it reads as: message take_damage(amount)  from the owner · also here · reliable -->

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

## Slotting into a project you already wrote

Everything above is also a READING. A networked project written before this plugin existed opens on
these rows without a byte changing, because the importer recognises the spellings people actually
publish - the three-line host and join blocks, `peer.close()`, the `get_tree().get_multiplayer()`
spelling, `multiplayer.<signal>.connect(...)` for every one of the seven signals, `$Spawner.spawn(id)`
and the message sends. Each recogniser stores the spelling it matched on the row and re-emits that,
so the file that opened is the file that saves.

What no row can say stays code, on purpose and visibly: a `create_server` with channel and bandwidth
limits, ENet compression, packets put on the wire by hand. Those lines keep their script block, and
the per-script count in the Project Doctor reports honestly how much of a script arrived as rows.
