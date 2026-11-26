#!/usr/bin/env python3
"""Verify a deployed API; writes one synthetic result, then tests retry/conflict.

Supply --state to save the payload and reuse it after restarting the server.
HTTPS certificates are verified. HTTP is allowed only on loopback.
"""
import argparse
import concurrent.futures
import json
from pathlib import Path
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url", help="API base URL, without /api/v1")
    parser.add_argument("--state", type=Path, required=True,
                        help="Save a synthetic session here; rerun to verify persistence")
    args = parser.parse_args()
    base = args.url.rstrip("/")
    parts = urllib.parse.urlsplit(base)
    if (parts.scheme != "https" and not
            (parts.scheme == "http" and parts.hostname in ("127.0.0.1", "localhost", "::1"))):
        parser.error("HTTPS is required except on loopback")
    if not parts.hostname or parts.username or parts.password or parts.query or parts.fragment or parts.path:
        parser.error("Use a base URL containing only scheme, hostname and optional port")

    auth_token = None

    def request(path, payload=None, key=None):
        headers = {"Content-Type": "application/json"}
        if auth_token:
            headers["Authorization"] = "Bearer " + auth_token
        if key:
            headers["Idempotency-Key"] = key
        data = None if payload is None else json.dumps(payload).encode()
        req = urllib.request.Request(base + path, data=data, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                body = response.read()
                return response.status, json.loads(body) if body else None
        except urllib.error.HTTPError as error:
            return error.code, None

    def require(condition, message):
        if not condition:
            raise RuntimeError(message)

    require(request("/health")[0] == 200, "Database health check failed")
    status, routes = request("/api/v1/routes")
    require(status == 200 and bool(routes), "Catalogue unavailable or empty")
    replay = args.state.exists()
    if replay:
        state = json.loads(args.state.read_text())
        require(state["baseURL"] == base, "State belongs to a different server")
        payload = state["payload"]
        auth_token = state.get("token")
        require(auth_token is not None, "This state predates authentication; use a new state file")
    else:
        status, login = request("/api/v1/auth/register", dict(username="check_" + uuid.uuid4().hex[:16], password=uuid.uuid4().hex))
        require(status == 200, "Synthetic test-account registration failed")
        auth_token = login["token"]
        route = routes[0]
        now = time.time() - 978307200  # Swift Date reference epoch, 2001-01-01.
        payload = dict(id=str(uuid.uuid4()), route=route, startedAt=now - 60,
                       finishedAt=now, collectedPelletIDs=[route["pellets"][0]["id"]],
                       distanceMeters=10, mode="explore")
        # Save before uploading so an interrupted run can safely retry.
        args.state.touch(mode=0o600, exist_ok=False)
        args.state.write_text(json.dumps(dict(baseURL=base, payload=payload, token=auth_token), indent=2))

    key = payload["id"]
    score = sum(p.get("value", 10) for p in payload["route"]["pellets"]
                if p["id"] in payload["collectedPelletIDs"])
    status, receipt = request("/api/v1/results", payload, key)
    require(status == 200 and receipt["score"] == score, "Upload or canonical score failed")
    if replay:
        require(receipt["duplicate"] is True, "Saved result did not survive restart")
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for status, receipt in pool.map(lambda _: request("/api/v1/results", payload, key), range(4)):
            require(status == 200 and receipt["duplicate"] is True, "Concurrent retry failed")
    conflict = dict(payload, distanceMeters=11)
    require(request("/api/v1/results", conflict, key)[0] == 409, "Changed result was not rejected")
    require(request("/api/v1/results", payload)[0] == 400, "Missing retry key was not rejected")
    print("PASS: health, catalogue, stored score, concurrent retries, conflict and missing-key rejection")
    print("PASS: saved result survived restart" if replay else
          "Restart the server, then rerun this command to verify persistence.")


if __name__ == "__main__":
    main()
