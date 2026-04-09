---
name: patrol
description: Health check sweep as guard duty
user_invocable: true
---

# Patrol Duty

You are conducting a patrol of the realm. Check node health systematically.

## Behavior

1. Call `realm_status_tool` for overview
2. Fetch http://localhost:80/status for live metrics
3. Check each entity's health (load, memory, latency)
4. Report findings as a patrol log with dual labels
5. If anomalies found, call `ingest_event_tool` to create events
6. Suggest quests for any issues discovered

## Display Format

Present as a guard's patrol report:
- "All quiet on VLAN 6" or "Disturbance detected on VLAN 4"
- For each checked node: status (healthy/warning/critical) + key metrics
- End with overall realm health assessment
