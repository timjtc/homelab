---
aliases:
  - Tailnet overhaul
tags:
  - project/scalable-homelab-rebuild
created: 2026-07-14T16:10
left: "[[scalable-homelab-rebuild|Scalable Homelab Rebuild]]"
---
# Definitions

This document serves as a change management log for the personal timothyjtc@outlook.com tailnet.

# Change Logs

## 2026-07-14 16:10

Expired and stale devices were removed.

A new tag structure and rules:
- The `default` tag is the fallback tag. It is generally used for all consumer hosts that needs connection to other `default`-tagged hosts.
- A different tag (`server-*` and `server-*--allow`) for each server type is always advisable for newly added servers.
- The generic `server` and `server--alow` tag enables connection between a server and client, although within defined port limitations. By default, only ports `80` and `443` are allowed.
	- E.g., a hosted web app on port `80` needs to be demonstrated to other connected hosts, it can be accessed since port `80` is allowed by default; or
	- a game server is hosted by one of the connected hosts, then its access port should be added to the `"ip"` key under the `server--alow` grant.
- No more allow-by-default grants for all added hosts, except for hosts within the same user account. If added hosts between different accounts or with no account needs connection, the `default` tag should be sufficient. If it needs access to servers, one of the `server*--allow` tags should be assigned.


```json
	"tagOwners": {
		// Default fallback tag, lets the same tagged devices to connect
		"tag:default":           ["autogroup:admin"],
		"tag:default--no-allow": ["autogroup:admin"],
		// General servers
		"tag:server":        ["autogroup:admin"],
		"tag:server--allow": ["autogroup:admin"],
		// Proxmox VE servers
		"tag:server-pve":        ["autogroup:admin"],
		"tag:server-pve--allow": ["autogroup:admin"],
		// Reverse proxy routers
		"tag:server-rpr":        ["autogroup:admin"],
		"tag:server-rpr--allow": ["autogroup:admin"],
	},
```

Appropriate ACLs were assigned to the restructured tags:
```json
	"grants": [
		{
			"src": ["autogroup:member"],
			"dst": ["autogroup:self"],
			"ip":  ["*"],
		},
		{
			"src": ["tag:default"],
			"dst": ["tag:default"],
			"ip":  ["*"],
		},
		{
			"src": ["tag:server"],
			"dst": ["tag:server--allow"],
			"ip":  ["*"],
		},
		{
			"src": ["tag:server--allow"],
			"dst": ["tag:server"],
			"ip":  ["80", "443"],
		},
		{
			"src": ["tag:server-pve"],
			"dst": ["tag:server-pve--allow"],
			"ip":  ["*"],
		},
		{
			"src": ["tag:server-pve--allow"],
			"dst": ["tag:server-pve"],
			"ip":  ["tcp:8006"],
		},
		{
			"src": ["tag:server-rpr"],
			"dst": ["tag:server-rpr--allow"],
			"ip":  ["*"],
		},
		{
			"src": ["tag:server-rpr--allow"],
			"dst": ["tag:server-rpr"],
			"ip":  ["*"],
		},
	],
```

