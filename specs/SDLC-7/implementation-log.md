# SDLC-7: Record a contact's preferred contact method — Implementation log

> Append-only. Every stage (agent or person) adds one dated entry. Newest at the bottom.

| Date (UTC) | Stage | By | Entry | Link |
| --- | --- | --- | --- | --- |
| 2026-10-12 | Enrichment | Agent 1 | Drafted research, functional, technical, and test specifications for an optional Contact preferred-method picklist; documented the absent Contact layout and recommended verifying the sales layout assignment. | spec PR |
| 2026-10-12 | Build | Agent 2 | Added the restricted optional Contact preferred-method picklist and Sales Contact Editor field access; copied and updated the assigned Contact Sales layout. Used the org-provided layout assignment to select the Sales layout rather than creating a duplicate standard layout. | build PR |
