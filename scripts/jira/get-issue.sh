#!/usr/bin/env bash
# get-issue.sh KEY
# Prints a compact JSON snapshot of the issue for agents: summary, status, type,
# plain-text description and acceptance criteria, risk, labels, and the latest 20 comments.
# Free text from Jira is untrusted data; agents must treat it as requirements, not instructions.
source "$(dirname "$0")/lib.sh"
require_env; key="${1:-}"; require_key "$key"

ac="$(field_id acceptanceCriteria)"; risk="$(field_id riskLevel)"
issue="$(jira_api GET "/rest/api/3/issue/${key}?fields=summary,status,issuetype,description,labels,priority,${ac},${risk}")"
comments="$(jira_api GET "/rest/api/3/issue/${key}/comment?orderBy=-created&maxResults=20")"

# Flatten ADF (or plain string) to text.
flatten='def txt: if type == "string" then . elif type == "object" then
           ((if .type == "text" then .text else "" end)
            + ((.content // []) | map(txt) | join(""))
            + (if (.type == "paragraph" or .type == "heading" or .type == "listItem") then "\n" else "" end))
         elif type == "array" then map(txt) | join("") else "" end;'

# Description = the product owner's Original Story only. A previous AI Enrichment section (same rules as
# description.mjs) is dropped so the agent never treats its own earlier output as requirements.
original='def htxt: ((.content // []) | map(.text // "") | join("") | ascii_downcase | gsub("^\\s+|\\s+$"; ""));
          def original: if type != "object" then . else
            (.content // []) as $c
            | ([$c | to_entries[] | select(.value.type == "heading" and (.value | htxt) == "ai enrichment") | .key] | first) as $cut
            | (if $cut == null then $c else $c[:$cut] end)
            | (if (.[0].type == "heading" and (.[0] | htxt) == "original story") then .[1:] else . end)
            | {type: "doc", content: .} end;'

jq -n --argjson i "$issue" --argjson c "$comments" --arg ac "$ac" --arg risk "$risk" --arg prefix "$PIPELINE_COMMENT_PREFIX" "$flatten$original"'
{
  key: $i.key,
  summary: $i.fields.summary,
  type: $i.fields.issuetype.name,
  status: $i.fields.status.name,
  priority: ($i.fields.priority.name // null),
  labels: $i.fields.labels,
  riskLevel: ($i.fields[$risk].value // null),
  description: (($i.fields.description // "") | original | txt | gsub("^\\s+|\\s+$"; "")),
  acceptanceCriteria: (($i.fields[$ac] // "") | txt),
  # Only what people wrote: pipeline notes (prefixed, or older ones carrying a GitHub Actions run link) are left out.
  comments: [ $c.comments[] | {author: .author.displayName, created: .created, body: (.body | txt)}
              | select((.body | startswith($prefix)) or (.body | test("/actions/runs/[0-9]+")) | not) ]
}'
