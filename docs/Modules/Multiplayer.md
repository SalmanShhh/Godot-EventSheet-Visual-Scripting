# Multiplayer

**Multiplayer** is the object a sheet talks to when several people are playing the same game over a
network. It opens the game - **Host a game**, **Join a game**, **Leave the game** - and it tells you
what happened to the connection, as seven events: **On player joined**, **On player left**, **On
joined the host**, **On join failed**, **On the host left**, and the two the authentication
handshake adds, **On player authenticating** and **On authentication failed**. After that it has
three things to say. It sends a **message** - a function one peer runs on the others. It answers
**Is host** - whether this copy of the game is the one that decides what is true. And it answers
**Owns this object** - whether this copy is the one allowed to move the thing the sheet is attached
to. The **MyID** expression rounds it out with this peer's own number; **Kick player**, **Stop
accepting players**, **Accept player** and **Reject player** run the lobby and its handshake; and
the scene's own two networking nodes have verbs of their own - a `MultiplayerSpawner` makes one copy
of a scene on everybody at once, and a `MultiplayerSynchronizer` keeps values in step and decides
who is allowed to see them.

Godot calls these `ENetMultiplayerPeer`, `MultiplayerAPI`'s signals, remote procedure calls, `@rpc`
annotations, `multiplayer.is_server()` and `is_multiplayer_authority()`. The rows are those exact
calls in the sheet's words, and nothing else: they compile to plain Godot with no runtime library
behind them, and an existing networked script opened as a sheet reads back as these same rows.

The connection still belongs in ONE place in your project - usually an autoload that hosts, joins and
reacts to the connection's own events - and every sheet after that point uses the messages and the
two guards. That is a convention, not a rule the plugin enforces.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reading a project you already wrote](#reading-a-project-you-already-wrote)
4. [Reference tables](#reference-tables)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Co-op games** - two to four players in the same level, where the host is simply whoever started.
- **A player's own character** - the object each peer is allowed to drive, and only that one.
- **Damage, pickups and scores** - the numbers that must agree, so the host decides and tells.
- **Chat, emotes and pings** - small messages every peer should see immediately.
- **Lobby screens** - who is here, who just left, who is the host.
- **Reading someone else's networked script** - it opens as these rows rather than as annotations.

## Core concepts

- **A message is a function.** Mark a function as a message - right-click its row ▸ **Make It A
  Message…** - and it becomes something other peers can run. Godot spells that `@rpc(...)` above the
  `func`, and the sheet reads it with the function's name in the condition lane - **On message
  take_damage** - with its parameters as chips and its mode words muted beside it.
- **The mode words say who may send it and where it runs.** *from anyone* means anybody may send it
  (the default is that only the object's owner may, which reads *from the owner*); *also here* means
  the sender runs it too, rather than only the others; *reliable* means it is guaranteed to arrive,
  in order, at the cost of waiting for it. A message that names no mode uses Godot's defaults, and
  the row says only what the annotation says.
- **A group can say who runs its events.** **Runs on** - *Everyone*, *The host* or *The owner* - is
  one muted word on the group's head instead of the same condition on every row under it. The
  compiler wraps those events in `multiplayer.is_server()` or `is_multiplayer_authority()`, and
  nested groups inherit until one answers for itself.
- **The scene keeps values in step, and the sheet reads that.** A `MultiplayerSynchronizer` holds
  the list of properties it copies from the owner to everybody else, in the `.tscn` rather than in
  your script. A variable it watches wears a mark on its row, the head carries a *keeps in step*
  band per synchronizer, and **Keep in Step** on the row's own menu writes into the scene.
- **Sending is addressed.** **Send … to everyone** runs the message on every peer. **Send … to the
  host** runs it only on the peer that is hosting (its id is always 1). **Send … to one peer** runs
  it on the one you name. Which you pick is a design decision, not a detail: the usual shape is that
  a player sends what they DID to the host, and the host sends what IS TRUE to everyone.
- **Is host is the guard on everything that decides.** Spawning enemies, rolling loot, awarding a
  point - if two peers did that independently they would disagree. Put those rows under **Is host**
  and let the host tell the others what happened.
- **Owns this object is the guard on everything that acts.** A running game holds one copy of every
  player character on every peer. Only one of those copies is really being driven; the rest are
  showing what the driver did. **Owns this object** is how a movement sheet stays on the right one.
- **MyID is a number, not a name.** The host is always 1; everyone else gets a number when they join.
  It is what you send when a message has to say who it came from.
- **Hosting and joining are one row each, and three lines each.** A game needs a peer, an open
  connection and the scene tree told about it. Those three lines are one decision, so they are one
  row: a reader who splits them has a half-connected game. The peer kind is a dropdown - ENet for
  desktop and mobile, WebSocket when the game runs in a browser, WebRTC for browser peer to peer.
- **Joining is a question, not an answer.** **Join a game** only asks. Whether it worked arrives
  later, as **On joined the host** or **On join failed**, which is why the lobby screen changes there
  and not on the row that asked.
- **Nothing here is magic.** Every row compiles to the call it names, so you can read the emitted
  `.gd`, hand it to somebody who has never used a sheet, and it is ordinary Godot networking code.
- **Two windows are one button.** **Play as host + client** on the toolbar sets Godot's own Run
  Multiple Instances to two copies, tags one `host` and the other `client`, and plays the scene, so
  **Started as** can send one copy to Host a game and the other to Join a game.
- **A networked project you already wrote opens as these rows, unchanged.** Opening a `.gd` as a
  sheet and saving it untouched reproduces the file byte for byte, so every reading below is a
  recogniser that also re-emits the spelling it matched.

## Reading a project you already wrote

| What you wrote | Reads as |
| --- | --- |
| `peer.create_server(PORT, 4)` then `multiplayer.multiplayer_peer = peer`, with `peer` declared at the top of the file | **Host a game on port PORT for up to 4 players** |
| `var peer := ENetMultiplayerPeer.new()` / `peer.create_server(PORT, MAX)` / `multiplayer.multiplayer_peer = peer` | the same row, with the local peer |
| the `create_client(address, PORT)` twin of either | **Join a game at address port PORT** |
| `multiplayer.multiplayer_peer = null`, `peer.close()`, or the `get_tree().get_multiplayer()` spelling | **Leave the game** |
| `WebSocketMultiplayerPeer` / `WebRTCMultiplayerPeer` in the constructor | the same rows, with that peer kind |
| `multiplayer.peer_connected.connect(_on_x)` and its six siblings | the seven events, with your connect line re-emitted as you wrote it |
| `@rpc(...)` above a function, in any order or subset of the options | that function's **message** row and its words, with the annotation as its echo |
| `rpc("f", 10)`, `rpc(&"f", 10)`, `rpc_id(1, &"f", 10)`, `rpc_id(peer, "f", 5)`, `$Other.rpc(&"f")` | the **Send** rows, each keeping your own quoting |
| `multiplayer.multiplayer_peer.disconnect_peer(id)`, `refuse_new_connections = true`, `multiplayer.server_relay = false` | **Kick player**, **Stop accepting players**, **Relay messages between players off** |
| `multiplayer.complete_auth(id)`, `multiplayer.send_auth(id, bytes)` | **Accept player**, **Send auth** |
| `$Spawner.spawn(id)`, `spawner.spawn({...})` | **Spawn**, with the spawner in the object column |
| the four lines of an automatic spawn - instantiate, name, place, `add_child(copy, true)` under the spawner's `spawn_path` | one **Spawn a scene** row |
| `$Spawner.spawned.connect(...)`, `despawned`, `$Sync.synchronized.connect(...)` | **On spawned** / **On despawned** / **On synchronized**, on that node |
| `set_visibility_for(id, true)` / `(id, false)`, `public_visibility = true`, `add_visibility_filter(f)` | **Show to player** / **Hide from player** / **Show to everyone** / **Ask f who may see it** |
| `set_multiplayer_authority(str(name).to_int())`, `(name.to_int())`, `(id, true)` | read as who owns this object |
| `if not is_multiplayer_authority(): return`, and the `if is_multiplayer_authority():` that wraps a whole body (and the `multiplayer.is_server()` pair) | read as who runs this function; the early return keeps its `return` |
| `## @ace_group(name="Scoring", runs_on="host")` and the guard the group wraps its events in | the group's **Runs on** word, with the guard off the rows |

And the honest other half. A `create_server` given channel or bandwidth limits, `peer.host.compress`,
`put_packet` / `get_packet`, and the `var error = peer.create_client(...)` spelling that checks what
the call answered all stay the code they are, because no row can say them without losing something.
They still read line by line, and the head's **reads as** band counts them out loud.

## Reference tables

Ships as is the template the row compiles to, so you can see exactly what lands in your `.gd`.

### Multiplayer: opening and closing the game

| Name | What it does | Ships as |
|------|--------------|----------|
| Host A Game | Opens this game to other players and makes this peer the host | `var __peer := {peer_kind}.new()` then `__peer.create_server({port}, {max_players})` then `multiplayer.multiplayer_peer = __peer` |
| Join A Game | Asks a host to let this peer in | the same three lines with `create_client({address}, {port})` |
| Leave The Game | Drops this peer's connection and puts the game back to single player | `multiplayer.multiplayer_peer = null` |
| Spawn | Makes one copy of a scene on the host and on every peer at once | `{target}.spawn({data})` |

### Multiplayer: what the connection tells you

| Name | What it does | Ships as |
|------|--------------|----------|
| On Player Joined | Another peer connected, and its id is the event's chip | `multiplayer.peer_connected.connect(…)` |
| On Player Left | A peer disconnected, however it went | `multiplayer.peer_disconnected.connect(…)` |
| On Joined The Host | This peer was accepted by the host | `multiplayer.connected_to_server.connect(…)` |
| On Join Failed | The host never answered, or refused | `multiplayer.connection_failed.connect(…)` |
| On The Host Left | The host went away and the game is over for this peer | `multiplayer.server_disconnected.connect(…)` |
| On Player Authenticating | A peer is still proving who it is, on the host, before it counts as joined | `multiplayer.peer_authenticating.connect(…)` |
| On Authentication Failed | A peer never proved who it was, and was dropped | `multiplayer.peer_authentication_failed.connect(…)` |

### Multiplayer: running the lobby

| Name | What it does | Ships as |
|------|--------------|----------|
| Kick Player | Drops one player's connection, from the host | `multiplayer.multiplayer_peer.disconnect_peer({id})` |
| Stop Accepting Players | Closes the lobby without ending the game | `multiplayer.multiplayer_peer.refuse_new_connections = true` |
| Relay Messages Between Players | Whether the host forwards a client's message on to the other clients | `multiplayer.server_relay = {on}` |
| Accept Player | Finishes the handshake for one peer, so it counts as joined | `multiplayer.complete_auth({id})` |
| Reject Player | Turns away a peer that did not prove who it is | `multiplayer.multiplayer_peer.disconnect_peer({id})` |
| Send Auth | Sends the bytes one side of the handshake wants the other to check | `multiplayer.send_auth({id}, {data})` |
| Give To Player | Hands one object to one player, who may then move it | `{target}.set_multiplayer_authority({id})` |

### Multiplayer: the scene's own two nodes

| Name | What it does | Ships as |
|------|--------------|----------|
| Spawn A Scene | Makes one copy of a scene from the spawner's list, on every peer at once | `load({scene}).instantiate()`, its `name` and `position`, then `{target}.get_node({target}.spawn_path).add_child(…, true)` |
| Despawn | Takes this copy out of the game everywhere, from the peer that owns it | `queue_free()` |
| Show To Player | Lets one player see what this synchronizer keeps in step | `set_visibility_for({id}, true)` |
| Hide From Player | Stops sending one player anything this synchronizer keeps in step | `set_visibility_for({id}, false)` |
| Show To Everyone | Puts the synchronizer back to being seen by every player | `public_visibility = true` |
| Ask A Function Who May See It | Hands the who-may-see-it question to a function of this sheet | `add_visibility_filter({filter})` |
| On Spawned | This spawner has just made a copy, on every peer | `{target}.spawned.connect(…)` |
| On Despawned | This spawner is taking a copy away | `{target}.despawned.connect(…)` |
| On Synchronized | New values have just arrived for what this synchronizer keeps in step | `{target}.synchronized.connect(…)` |

### Multiplayer: sending messages

| Name | What it does | Ships as |
|------|--------------|----------|
| Send Message To Everyone | Runs a message on every peer in the game, including this one when the message says so | `{message}.rpc({args})` |
| Send Message To The Host | Runs a message on the host only - the peer that decides what is true | `{message}.rpc_id(1{, args})` |
| Send Message To One Peer | Runs a message on one named peer only | `{message}.rpc_id({peer}{, args})` |

### Multiplayer: asking who this is

| Name | What it does | Ships as |
|------|--------------|----------|
| Is Host | True on the peer that is hosting the game | `multiplayer.is_server()` |
| Owns This Object | True when this peer is the one allowed to move and change this object | `is_multiplayer_authority()` |
| Is Connected | True once this peer is really in a game, hosting one or accepted by a host | `multiplayer.multiplayer_peer != null and …get_connection_status() == …CONNECTION_CONNECTED` |
| Started As | True when this build carries the named export tag, so one project can host itself or join itself | `OS.has_feature({tag})` |
| My ID | This peer's own id - the host is always 1 | `multiplayer.get_unique_id()` |
| Players | The ids of every OTHER peer in the game, as a list | `multiplayer.get_peers()` |
| Player Count | How many other peers are in the game | `multiplayer.get_peers().size()` |
| Sender | Inside a message, the id of the peer that sent it | `multiplayer.get_remote_sender_id()` |
| Owner Of | The id of the peer that owns an object | `{target}.get_multiplayer_authority()` |

## Use cases

**1. A damage message.** Mark `take_damage(amount)` as a message with *from anyone*,
*also here* and *reliable*. A bullet that hits sends **Send Take Damage to everyone** with
`amount = 10`, and every copy of that character loses the same health at the same moment.

**2. Host-authoritative damage.** The stricter version of the same thing: the bullet sends **Send
Take Damage to the host**, the host subtracts the health, and the host sends the new value to
everyone. A player who edits their own game can now lie about firing, but not about the result.

**3. Only drive your own character.** Put the whole movement block under **Owns this object**. Every
peer runs the sheet on every character; only one of them gets past that condition.

**4. Spawn enemies once.** Wrap the spawner in **Is host**. Without it, four players in a level means
four times as many enemies, each peer convinced its own set is real.

**5. Roll loot on the host.** The chance roll goes under **Is host**, and the result is sent to
everyone as a message. Two peers rolling separately would show two different swords.

**6. A chat line.** A message taking one text parameter, sent with **Send … to everyone**, appended
to a label on arrival. Mark it *from any peer* or only the host will be able to talk.

**7. A map ping.** The same shape with a position instead of text - the marker appears for everybody
at the point one player clicked.

**8. Say who you are on join.** On start of layout, send your name to the host with **Send … to the
host**, carrying **Multiplayer.MyID** so the host knows which peer the name belongs to.

**9. A lobby list.** The host keeps the list, and every change is sent to everyone as one message
carrying the whole list. Sending the state rather than the change is slower and far easier to get
right.

**10. A private reply.** The host answers one player's request with **Send … to one peer**, using the
id that came with the request. Nobody else sees the answer.

**11. Start the match together.** The host sends a start message to everyone rather than each peer
deciding for itself, so the countdown really is the same countdown.

**12. Correct a cheater quietly.** The host notices a position that is impossible, and sends the
right one back with **Send … to one peer**. The other players never see the correction.

**13. Emotes.** A message taking an emote number, *from any peer*, *runs here too*, sent with **Send
… to everyone**. The sender sees their own emote because the message says it runs here too.

**14. A shared timer.** The host owns the clock and sends the remaining seconds to everyone once a
second. Every peer counting down on its own drifts apart within a minute.

**15. Debug who is who.** Print **Multiplayer.MyID** and **Is host** on start of layout. Half the
confusion in a first networked build is not knowing which window you are looking at.

**16. Doors and switches.** The interaction is sent to the host, the host opens the door, and the
door state is sent to everyone - the same three steps as damage, and worth learning once.

**17. A Host button and a Join button.** Two rows on a menu: **Host a game on port 7777 for up to 4
players** under one button, **Join a game at the typed address port 7777** under the other. Nothing
else changes about the menu, and the game is now networked.

**18. A lobby that says who is here.** **On player joined** adds a name to the list, **On player
left** removes it. The list itself lives on the host and is sent to everyone as one message whenever
it changes.

**19. Back to the menu when the host quits.** **On the host left** changes the scene. Without it the
remaining players stand in a world nobody is answering for, which looks exactly like a freeze.

**20. Spawn each player's character on the host.** **On player joined** with **Is host** under it,
and a **Spawn** row on the MultiplayerSpawner carrying the new peer's id. The spawner makes the same
copy on every peer, and the id is how its spawn function knows who it belongs to.

**21. Say why the join failed.** **On join failed** puts a line on the menu. The address was wrong,
the port was wrong, or nobody was hosting - all three arrive here and nowhere else.

**22. A health bar that agrees.** Right-click `hp` ▸ **Keep in Step ▸ On change**. The value now
rides the scene's `MultiplayerSynchronizer` from the peer that owns the character to everybody else,
with no row saying so and nothing written into the script.

**23. Spawn each player's character from the spawner's list.** **On player joined** with **Spawn a
scene** under it: the scene from the spawner's own list, named after the new peer's id, placed at a
spawn point. The spawner sends the copy to every peer, and the name is what lets that player own it.

**24. A hand of cards only its owner sees.** **Hide from player** on the hand's synchronizer for
everybody else, **Show to player** for its owner. A hidden node is not sent at all, so the values
are not in the other players' packets to be read out of.

**25. Score on the host, in one word.** Group the scoring events and set **Runs on ▸ The host**
instead of repeating **Is host** on every row. The head says who runs them, and the compiler writes
the one test around the group.

**26. Kick a player who will not behave.** **Kick player** with the id, from the host. A client that
wants somebody kicked sends the host a message and lets the host decide, because only the host may
drop a connection.

**27. Test both halves in one click.** **Play as host + client** starts two copies, tagged `host`
and `client`; an **On ready** event asking **Started as host** hosts in one window and joins in the
other, and each live value then wears one chip per window.

### Other use cases

**A ready check.** Each player sends a "ready" message to the host; the host counts them and sends "everyone is ready" back to everyone, which is the whole lobby handshake in three rows.

**Reconnect state.** When a peer rejoins, the host sends it the current world state with **Send … to one peer**, so a dropped player catches up without restarting the match.

**Voice-line cooldowns.** Mark the message *unreliable* and let the occasional shout go missing - a dropped taunt costs nothing, and reliable delivery costs latency on everything behind it.

**A spectator.** Nothing owns the spectator camera, so its sheet has no **Owns this object** guard at all and simply follows whichever player it was told to watch.

**Turn-based games.** The host sends "it is peer 3's turn" to everyone, and every sheet compares it against **Multiplayer.MyID** to decide whether the controls are live.

## Tips and common mistakes

- **A message that never arrives is usually a missing mode.** By default only the object's owner may
  send a message. If a player's own action does nothing on the other peers, the function needs
  *from anyone*.
- **A message that runs everywhere except on the sender needs *also here*.** This is the single most
  common surprise: Godot's default is that `rpc()` runs on the others, not on you.
- **A message nothing marked is a call that quietly never travels.** It compiles, it runs locally,
  and nobody else hears it. The Project Doctor says so under the row, and offers to mark it.
- **Do not put a decision behind a send.** Rolling the dice and then telling everybody the number is
  right; telling everybody to roll their own dice is not, and it looks fine until two peers disagree.
- **Peer 1 is the host, always.** That is what makes **Send … to the host** a fixed row rather than
  one taking an id.
- **Every peer runs your sheet.** A row with no **Is host** or **Owns this object** guard runs once
  per peer, per object. Most bugs in a first networked build are one missing guard.
- **`is_multiplayer_authority()` is per node.** It answers about the object the sheet is on, not
  about the peer in general, which is exactly why the row reads **Owns this object**.
- **Set the connection up in one place.** Hosting, joining and reacting to the seven events belongs
  in one autoload, not in every sheet. The messages and the two guards are what every sheet after
  that point uses.
- **A spawner will not replicate a scene it does not list.** The copy then appears on the peer that
  made it and nowhere else. Picking a path the *Auto spawn list* does not hold adds it, as one step
  of the scene's own undo, which is why the Scene field's help strip says so while you type.
- **A value the host changes that nothing keeps in step stays on the host.** No error, no warning:
  the other players simply go on showing the old number. Either keep it in step or send it as a
  message, and the Doctor's second finding is exactly this question asked for you.
- **A port is a number both sides must agree on.** Anything from 1024 to 65535 is yours to pick.
  127.0.0.1 is this same machine, which is how you test with two windows; a home network needs the
  host's local address, and the open internet needs port forwarding or a relay.
- **Max players does not count the host.** Four means the host plus four others, because that is what
  `create_server`'s second argument means.
- **A browser build cannot open a raw socket.** ENet does not work there. Pick WebSocket for both
  sides, and remember that a desktop host with ENet cannot accept a browser client.
- **Test with two windows before you test with two machines.** **Play as host + client** does it in
  one click; almost every mistake above shows up immediately, and none of them need a network to
  reproduce.
