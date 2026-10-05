"""Minimal in-memory mock of the Jira Cloud REST endpoints the scripts use.

Mirrors the SDLC workflow: transitions are only offered along the configured path.
Run: python3 mock_jira.py PORT
"""
import json
import re
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

CFG = json.load(open(sys.argv[2]))
S = {k: v["name"] for k, v in CFG["jira"]["statuses"].items()}
F = CFG["jira"]["fields"]

# from-status -> list of to-status (mirrors the live workflow)
PATH = {
    S["draft"]: [S["readyToWork"]],
    S["readyToWork"]: [S["draft"], S["enrich"]],
    S["enrich"]: [S["needsInfo"], S["enriched"]],
    S["needsInfo"]: [S["enrich"]],
    S["enriched"]: [S["specApproved"], S["enrich"]],
    S["specApproved"]: [S["readyForBuild"]],
    S["readyForBuild"]: [S["inBuild"]],
    S["inBuild"]: [S["prCreated"]],
    S["prCreated"]: [S["approved"], S["inBuild"]],
    S["approved"]: [S["deployed"]],
    S["deployed"]: [S["released"]],
    S["released"]: [],
    S["blocked"]: [S["readyToWork"], S["enrich"], S["readyForBuild"], S["inBuild"], S["deployed"]],
}

ISSUES = {
    "SDLC-1": {
        "status": S["enrich"],
        "fields": {
            "summary": "Add contract end date to Account",
            "issuetype": {"name": "Story"},
            "labels": ["pilot"],
            "priority": {"name": "Medium"},
            "description": {"type": "doc", "version": 1, "content": [
                {"type": "paragraph", "content": [{"type": "text", "text": "Sales needs the contract end date."}]}]},
            F["acceptanceCriteria"]: "Given an account, when edited, then end date is saved.",
            F["riskLevel"]: {"value": "Low"},
            F["agentState"]: {"value": "Queued"},
            F["agentRun"]: None,
            F["agentAttempts"]: None,
        },
        "comments": [],
    }
}


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, obj=None):
        body = b"" if obj is None else json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _issue(self):
        m = re.match(r"^/rest/api/3/issue/([A-Z0-9-]+)(/[a-z]+)?", self.path)
        if not m or m.group(1) not in ISSUES:
            self._send(404, {"errorMessages": ["Issue does not exist"]})
            return None, None
        return m.group(1), m.group(2)

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n) or b"{}")

    def do_GET(self):
        key, sub = self._issue()
        if not key:
            return
        i = ISSUES[key]
        if sub == "/transitions":
            ts = [{"id": str(100 + n), "name": "to " + to, "to": {"name": to}}
                  for n, to in enumerate(PATH[i["status"]] + [S["blocked"]]) if to != i["status"]]
            return self._send(200, {"transitions": ts})
        if sub == "/comment":
            return self._send(200, {"comments": list(reversed(i["comments"]))})
        f = dict(i["fields"])
        f["status"] = {"name": i["status"]}
        return self._send(200, {"key": key, "fields": f})

    def do_POST(self):
        key, sub = self._issue()
        if not key:
            return
        i, b = ISSUES[key], self._body()
        if sub == "/transitions":
            avail = [t for t in PATH[i["status"]] + [S["blocked"]] if t != i["status"]]
            idx = int(b["transition"]["id"]) - 100
            if idx < 0 or idx >= len(avail):
                return self._send(400, {"errorMessages": ["bad transition"]})
            i["status"] = avail[idx]
            return self._send(204)
        if sub == "/comment":
            assert b["body"]["type"] == "doc"
            i["comments"].append({"author": {"displayName": "svc"}, "created": "now", "body": b["body"]})
            return self._send(201, {"id": str(len(i["comments"]))})
        self._send(404)

    def do_PUT(self):
        key, _ = self._issue()
        if not key:
            return
        b = self._body()
        for k, v in b["fields"].items():
            if k not in F.values():
                return self._send(400, {"errors": {k: "unknown field"}})
            ISSUES[key]["fields"][k] = v
        self._send(204)

    def do_DELETE(self):  # used by tests to inspect state
        self._send(200, ISSUES)


HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
