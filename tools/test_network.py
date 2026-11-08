#!/usr/bin/env python3
"""Exercise real ENet authority, four clients, capacity, reconnection and saves."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time


ROOT = Path(__file__).resolve().parents[1]


def engine_path() -> str:
    configured = os.environ.get("GODOT_BIN")
    if configured:
        return configured
    for candidate in ("godot", "godot4", "/Applications/Godot.app/Contents/MacOS/Godot"):
        found = shutil.which(candidate)
        if found:
            return found
    raise SystemExit("Godot 4 is required. Set GODOT_BIN to its executable.")


def free_udp_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        return int(probe.getsockname()[1])


def wait_for(path: Path, processes: list[subprocess.Popen], timeout: float = 20) -> dict:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        failures = list(path.parent.glob("failure_*.json"))
        if failures:
            raise AssertionError(failures[0].read_text())
        if path.exists():
            return json.loads(path.read_text())
        for process in processes:
            if process.poll() not in (None, 0):
                raise AssertionError(f"Godot process exited with {process.returncode}; see {path.parent}")
        time.sleep(0.05)
    raise AssertionError(f"Timed out waiting for {path.name}; see logs in {path.parent}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=engine_path())
    parser.add_argument("--report", type=Path, help="Optional JSON summary path")
    args = parser.parse_args()
    directory = Path(tempfile.mkdtemp(prefix="trailer-park-network-"))
    port = free_udp_port()
    slot = "network_" + directory.name.rsplit("-", 1)[-1]
    processes: list[subprocess.Popen] = []
    logs = []

    def start(role: str, index: int = 0, action_at: float = 0.0) -> subprocess.Popen:
        log = (directory / f"{role}_{index}.log").open("w")
        logs.append(log)
        command = [args.godot, "--headless", "--max-fps", "30", "--path", str(ROOT), "--script", "res://tests/network_peer.gd", "--",
                   f"--test-role={role}", f"--test-index={index}", f"--test-dir={directory}", f"--port={port}",
                   f"--save-slot={slot}", "--no-autosave", "--access-code=coop-test"]
        if role == "server":
            command.append("--server")
        else:
            names = ["  ", "Zoë García", "Avery\x1bSmith\n", "M" * 80, "Overflow"]
            command.extend(["--join=127.0.0.1", f"--name={names[index]}", f"--action-at={action_at}"])
        process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        processes.append(process)
        return process

    try:
        server = start("server")
        assert wait_for(directory / "server.ready", processes)["ready"], "Dedicated server did not start"
        action_at = time.time() + 5.0
        clients = [start("client", i, action_at) for i in range(4)]
        client_results = [wait_for(directory / f"client_{i}.json", processes) for i in range(4)]

        baseline = client_results[0]["state"]
        assert all(result["players"] == 4 for result in client_results), "Not all clients saw four players"
        assert all(result["state"] == baseline for result in client_results), "Peers disagree on park state"
        trees = [building for building in baseline["buildings"] if building["kind"] == "tree"]
        assert len(trees) == 1, f"Concurrent duplicate purchases created {len(trees)} trees"
        assert baseline["cash"] == 0, f"Concurrent spending changed cash incorrectly: {baseline['cash']}"
        assert all(result["client_save_denied"] for result in client_results), "A client wrote an authority save"
        rejection_messages = [result["message"] for result in client_results[0]["results"] if not result["ok"]]
        assert any("already processed" in message for message in rejection_messages), "Replay protection was not exercised"
        assert sum("not valid" in message for message in rejection_messages) >= 3, "Invalid/admin/batched-road commands were not rejected"
        assert any("control characters" in message for message in rejection_messages), "A park name with control characters was accepted"
        for result in client_results:
            names = {player["name"] for player in result["roster"].values()}
            assert names == {"Manager", "Zoë García", "Avery Smith", "M" * 24}, "Player names were not normalized consistently"
        assert any(entry["ok"] and "already" in entry["message"].lower() for entry in client_results[0]["results"]), "Valid batched road did not pass the network protocol"
        assert not list(directory.rglob("must_not_exist.json")), "Client created a save file"

        # An enabled policy queues other managers' expensive actions without
        # reserving money. Three approvals must still obey current funds.
        (directory / "begin_approvals").touch()
        queued = wait_for(directory / "approval_queue.json", processes, 10)
        assert len(queued["pending"]) == 3 and queued["limit"] == 10, "Approval policy or queue is inconsistent"
        assert queued["state"]["cash"] == 75, "Queued requests spent money prematurely"
        assert len([b for b in queued["state"]["buildings"] if b["kind"] == "tree"]) == 1, "Queued requests built objects prematurely"
        approval_results = [wait_for(directory / f"approval_client_{i}.json", processes, 10) for i in range(4)]
        baseline = approval_results[0]["state"]
        assert all(result["state"] == baseline for result in approval_results), "Approval outcomes differ between clients"
        assert baseline["cash"] == 0, "Approvals overspent available funds"
        assert len([b for b in baseline["buildings"] if b["kind"] == "tree"]) == 2, "Approval revalidation failed"
        assert all(result["pending"] == 0 and result["limit"] == 10 for result in approval_results), "Pending policy did not synchronize"
        for result in approval_results:
            if not result["was_manager"]:
                messages = [entry["message"] for entry in result["results"] if not entry["ok"]]
                assert any("Only the session manager can change" in message for message in messages), "Non-manager changed spending policy"
                assert any("Only the session manager can review" in message for message in messages), "Non-manager approved their own request"

        overflow = start("overflow", 4)
        assert not wait_for(directory / "overflow.json", processes, 15)["joined"], "A fifth player joined a full park"
        overflow.wait(timeout=3)

        manager_index = next(i for i, result in enumerate(approval_results) if result["was_manager"])
        old_manager = approval_results[manager_index]["peer_id"]
        (directory / f"release_client_{manager_index}").touch()
        clients[manager_index].wait(timeout=5)
        time.sleep(0.5)
        observer = start("observer", manager_index)
        rejoined = wait_for(directory / "rejoined.json", processes, 12)
        assert rejoined["players"] == 4, "Rejoining client did not receive the updated roster"
        assert rejoined["state"] == baseline, "Rejoining client received stale or changed state"
        remaining_ids = [result["peer_id"] for i, result in enumerate(approval_results) if i != manager_index]
        assert rejoined["manager_id"] in remaining_ids and rejoined["manager_id"] != old_manager, "Dedicated manager was not promoted after departure"
        assert not rejoined["is_manager"] and rejoined["limit"] == 10, "Rejoining client usurped manager or lost policy"

        (directory / "begin_resilience").touch()
        pending = wait_for(directory / "observer_pending.json", processes, 10)
        assert pending["pending"] == 4, "Per-player approval queue cap was not enforced"
        assert pending["state"] == baseline, "Pending loans mutated financial state"
        assert any("already several" in result["message"] and not result["ok"] for result in pending["results"]), "Fifth pending request was not refused"
        (directory / "expire_requests").touch()
        expired = wait_for(directory / "observer_after_expiry.json", processes, 10)
        assert expired["state"] == baseline, "Expiring requests mutated park state"
        assert sum("pending request expired" in result["message"] for result in expired["results"]) == 4, "Expired requests were retained or did not notify their owner"
        assert expired["pending"] == 2, "Expired requests did not free queue capacity"
        (directory / "inject_bad_snapshot.json").write_text(json.dumps({"peer": pending["peer_id"]}))
        bad_snapshot = wait_for(directory / "observer_bad_snapshot.json", processes, 10)
        assert bad_snapshot["unchanged"] and bad_snapshot["serial_unchanged"] and bad_snapshot["connected"], "Non-finite snapshot mutated or poisoned a replica"
        (directory / "send_good_snapshot").touch()
        good_snapshot = wait_for(directory / "observer_good_snapshot.json", processes, 10)
        assert good_snapshot["unchanged"] and good_snapshot["serial_advanced"], "Valid state could not follow an invalid snapshot"
        (directory / "kick_observer.json").write_text(json.dumps({"peer": pending["peer_id"]}))
        cleanup = wait_for(directory / "pending_cleanup.json", processes, 10)
        assert cleanup["pending"] == 0, "A departing player's pending requests were retained"
        disconnected = wait_for(directory / "observer_disconnected.json", processes, 10)
        assert disconnected["unchanged"] and disconnected["mode"] == "client" and not disconnected["authority"], "Disconnected replica advanced or became an authority"
        assert disconnected["denied_save"] and disconnected["denied_load"] and disconnected["autosave_absent"], "Disconnected replica wrote or loaded authority saves"
        failed_retry = wait_for(directory / "observer_failed_retry.json", processes, 10)
        assert failed_retry["unchanged"] and failed_retry["mode"] == "client" and not failed_retry["authority"] and not failed_retry["connected"], "Failed retry changed or promoted a disconnected replica"
        recovered = wait_for(directory / "resilience_complete.json", processes, 12)
        assert recovered["restored_authority_state"] and recovered["state"] == baseline and recovered["players"] == 4, "Successful retry did not restore current authority state"

        (directory / "stop").touch()
        server_result = wait_for(directory / "server.json", processes, 8)
        assert server_result["state"] == baseline, "Authority and clients disagree"
        assert server_result["save_twice"], "Authority could not atomically save the park"
        assert server_result["backup_recovered"], "Corrupt primary save did not recover from backup"
        assert server_result["same_after_recovery"], "Backup recovery changed park state"
        assert server_result["saved_after_recovery"] and server_result["backup_still_valid"], "Saving a recovered park destroyed its valid backup"
        assert server_result["policy_after_recovery"] == 10, "Save recovery lost the spending policy"
        for process in processes:
            process.wait(timeout=6)
            assert process.returncode == 0, f"Godot process failed with {process.returncode}"
        for log in logs:
            log.flush()
            contents = Path(log.name).read_text()
            assert "ERROR:" not in contents, f"Godot error in {log.name}"
        report = {"ok": True, "transport": "ENet UDP loopback", "clients": 4,
                  "checks": ["four-player roster", "authoritative snapshots", "concurrent placement collision",
                             "no overspending", "replay rejection", "invalid/admin command rejection", "bounded batched-road protocol",
                             "safe peer-name normalization and Unicode", "control-character park-name rejection",
                             "client save denial", "fifth player refused", "late rejoin snapshot",
                             "approval queue without premature mutation", "non-manager policy/self-approval denial",
                             "approval revalidation without overspending", "manager promotion on departure",
                             "per-player pending request cap", "pending request expiry without mutation", "pending cleanup on disconnect", "non-finite snapshot rejection without serial poisoning",
                             "disconnected replica frozen and save/command denied", "failed retry preserves replica", "successful retry restores authority state",
                             "atomic authority save", "corrupt save backup recovery", "valid backup retained after recovery save", "saved spending policy"],
                  "revision": baseline["revision"], "logs": str(directory)}
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report, indent=2))
    except BaseException:
        print(f"Network test logs: {directory}")
        for log in logs:
            log.flush()
        raise
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
        for process in processes:
            if process.poll() is None:
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
        for log in logs:
            log.close()


if __name__ == "__main__":
    main()
