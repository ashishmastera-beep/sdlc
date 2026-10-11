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


def _card(status, sha=None, state="Idle"):
    return {"status": status, "comments": [], "fields": {
        "summary": "card", "issuetype": {"name": "Story"}, "labels": [], "priority": {"name": "Medium"},
        "description": None, F["acceptanceCriteria"]: None, F["riskLevel"]: None,
        F["agentState"]: {"value": state}, F["agentRun"]: None, F["agentAttempts"]: None,
        F["approvedSpecSha"]: sha, F["specPr"]: None, F["buildPr"]: None}}


ISSUES["SDLC-3"] = _card(S["specApproved"], sha="abc123")   # oldest approved spec
ISSUES["SDLC-4"] = _card(S["specApproved"], sha="def456")
ISSUES["SDLC-5"] = _card(S["inBuild"])
ISSUES["SDLC-6"] = _card(S["prCreated"])
ISSUES["SDLC-7"] = _card(S["approved"])
ISSUES["SDLC-8"] = _card(S["readyForBuild"], state="Queued")


def _match(key, issue, clause):
    """Tiny JQL subset: project =, status =, status in (...), cf[N] = V, cf[N] is not EMPTY; other clauses ignored."""
    c = clause.strip()
    m = re.fullmatch(r'project\s*=\s*(\S+)', c)
    if m:
        return key.startswith(m.group(1) + "-")
    m = re.fullmatch(r'status\s*=\s*"([^"]+)"', c)
    if m:
        return issue["status"] == m.group(1)
    m = re.fullmatch(r'status\s+in\s*\((.*)\)', c)
    if m:
        return issue["status"] in re.findall(r'"([^"]+)"', m.group(1))
    m = re.fullmatch(r'cf\[(\d+)\]\s+is\s+not\s+EMPTY', c)
    if m:
        return issue["fields"].get("customfield_" + m.group(1)) not in (None, "")
    m = re.fullmatch(r'cf\[(\d+)\]\s*=\s*"?([^"]+?)"?', c)
    if m:
        v = issue["fields"].get("customfield_" + m.group(1))
        return (v.get("value") if isinstance(v, dict) else v) == m.group(2)
    return True


def search(query):
    from urllib.parse import parse_qs
    q = parse_qs(query)
    jql = re.split(r'\s+ORDER\s+BY\s+', q.get("jql", [""])[0])[0]
    fields = q.get("fields", ["status"])[0].split(",")
    mx = int(q.get("maxResults", ["50"])[0])
    out = []
    for key in sorted(ISSUES, key=lambda k: int(k.split("-")[1])):
        i = ISSUES[key]
        if all(_match(key, i, c) for c in re.split(r'\s+AND\s+', jql)):
            f = {n: i["fields"].get(n) for n in fields if n != "status"}
            f["status"] = {"name": i["status"]}
            out.append({"key": key, "fields": f})
    return {"issues": out[:mx]}


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
        if self.path.startswith("/rest/api/3/search/jql?"):
            return self._send(200, search(self.path.split("?", 1)[1]))
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
