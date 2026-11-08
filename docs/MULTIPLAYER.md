# Shared parks

The prototype uses a Godot ENet authority with a maximum of four players. A player can host the current park, or a dedicated Godot process can host it without rendering. Each client has its own camera. Construction, rent, loans, repairs, events and the simulation clock belong to the host/server.

## Optional spending approval

Friends have equal construction and management access by default. The session manager can enable an approval threshold in the session controls; **$0 disables approval**. With a threshold enabled, other players' purchases above it, all loans and all demolition requests wait for manager review. The manager's own actions proceed directly. This is a session permission, not a required in-world supervisor job.

The listening host is session manager. On a dedicated server, the first player to join becomes manager; if that player leaves, another connected player is promoted. Returning to the session does not take the manager role back from the promoted player.

Queued requests do not build objects, reserve locations or spend money. Approval runs the action against the current park again, including current funds and occupancy. If two requests compete for the same money or land, approving the first can make the second fail. Only the manager may approve, decline or change the threshold. Requests expire after two minutes, are capped at four per player/twelve total, and are cleared if their requester leaves. Turning approval off clears outstanding requests; players submit them again to act immediately.

The spending threshold is saved with the park. Transient pending requests and peer identities are not restored from disk.

## Joining a game

Use the session controls in the game to enter a manager name. The host chooses a UDP port (default **27840**) and can set an access code. Friends enter the host's reachable address, the same port and the code. An empty code permits anyone who can reach the address to join, subject to the four-player limit.

For players on the same Wi-Fi/LAN, use the host's local IP address. Internet hosting requires a reachable server: a dedicated host with its UDP port open, or a suitable router forwarding the chosen UDP port to the listening host. A local address such as `192.168.x.x` does not work across the internet. Carrier NAT can prevent phone-hosted internet sessions; a dedicated server avoids making a player's phone the internet host.

This repository does **not** provision cloud hosting, account authentication, matchmaking, NAT traversal or a public invitation service. The access code is a simple private-group gate, not an account system or an encrypted transport. The direct-address flow should be used for prototype playtests with trusted friends. Internet reachability and actual iOS/Android-device behavior must be tested on the deployment network.

## Dedicated server

With Godot 4 installed, run:

```sh
GODOT_BIN=/path/to/godot sh tools/run_server.sh --port=27840 --save-slot=my_park --access-code=your-group-code
```

On macOS the script also finds `/Applications/Godot.app/Contents/MacOS/Godot`. A dedicated server accepts four player clients; a player-hosted game accepts three friends plus the host. It loads the specified save when available, saves periodically, and suspends simulation while no players are connected. A player-hosted park stops being available when its host closes the game. Automatic host migration is not implemented.

Use a unique access code for the group. The `--access-code` argument can be omitted for a local-only test. A production host should provide its own process supervision and UDP firewall configuration; none is silently installed by this project.

## State and saves

Clients send numbered action requests. The server checks membership, session identity, sequence, rate, argument shape, approval policy and the simulation's placement/financial rules, then applies accepted actions serially. Road drags are bounded to 96 finite, integral grid coordinates per atomic path. It replicates approved state and sends a fresh snapshot to a late joiner. Clients cannot upload arbitrary park state, reset the shared park, or write an authority save through the command protocol. Placement previews are temporary shared hints and do not reserve or purchase anything.

The host writes JSON saves in `user://saves/` (Godot's per-user application data folder). Saves are written to a temporary file, flushed, backed up and renamed into place. Loading validates the park state before replacing it; an invalid primary falls back to the backup. A disconnected client remains frozen until it reconnects or explicitly leaves the shared session. Its replica never takes over authority automatically.

## Automated network checks

```sh
python3 tools/test_network.py --godot /path/to/godot
```

The test launches a dedicated server and four real clients over loopback UDP. It checks a concurrent purchase race, consistent state and funds, replay and invalid/admin-command rejection, client save denial, approval queue behavior, non-manager policy/self-approval rejection, revalidation of competing approved purchases, manager promotion, refusal of a fifth player, late rejoin, atomic saving and recovery from a corrupt primary save. It also verifies that a valid backup survives a recovery-save and that the spending policy survives recovery. Test saves use unique temporary directories and do not touch the player's saved park.

Loopback verification does not establish internet reachability, mobile-device performance or resilience to every mobile network interruption. See the implementation/test status in the project handoff for what has actually been run.
