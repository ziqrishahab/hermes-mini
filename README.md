# Hermes Mobile

A public, cross-platform mobile client for [Hermes Agent](https://github.com/NousResearch/hermes-agent), inspired by the official [Hermes Desktop](https://github.com/fathah/hermes-desktop) app.

This project is **not tied to a single VPS or environment**. It supports multiple connection modes so any Hermes Agent user can connect from their phone.

---

## Features

- **Remote Mode** — connect directly to any Hermes API server via URL + API key.
- **SSH Tunnel Mode** — connect through an SSH local forward to a remote Hermes Agent that only listens on `127.0.0.1`.
- **Connection-first flow** — the app must successfully connect before entering the chat screen, unlike the desktop app which opens directly.
- **Streaming chat UI** — real-time SSE parsing with Markdown rendering and code syntax highlighting.
- **Material Design 3** — dark mode by default, clean mobile-first UI.

---

## Connection Modes

### 1. Remote (Direct)

```
Flutter App ──HTTPS──▶ Hermes API Server
```

- Requires `API_SERVER_ENABLED=true`, `API_SERVER_HOST=0.0.0.0`, and `API_SERVER_KEY=<secret>` on the server.
- User inputs the public URL and API key.

### 2. SSH Tunnel

```
Flutter App
    │ talks to localhost:8642
    ▼
dartssh2 local forward
    │ encrypted over SSH port 22
    ▼
Remote server
    │ forwards to 127.0.0.1:8642
    ▼
Hermes API Server (localhost-only)
```

- Best for self-hosted setups where the API server binds to `127.0.0.1` only.
- User inputs SSH host, port, username, and private key.

---

## Architecture

```
lib/
├── main.dart                      # ProviderScope + app entry
├── src/
│   ├── app.dart                   # MaterialApp.router
│   ├── router.dart                # go_router
│   ├── theme.dart                 # MD3 dark/light themes
│   ├── models/
│   │   ├── connection_config.dart # Remote vs SSH Tunnel config
│   │   ├── sse_event.dart         # SSE event parser
│   │   └── chat_message.dart      # Message model
│   ├── services/
│   │   ├── hermes_connection.dart # Abstract connection + factory
│   │   ├── remote_connection.dart # Direct HTTPS connection
│   │   ├── ssh_connection.dart    # SSH tunnel + local forward
│   │   └── storage_service.dart   # Secure config persistence
│   ├── providers/
│   │   ├── connection_provider.dart
│   │   └── chat_provider.dart
│   └── ui/
│       ├── screens/
│       │   ├── connection_screen.dart
│       │   └── chat_screen.dart
│       └── widgets/
│           ├── chat_bubble.dart
│           └── markdown_body.dart
```

---

## Tech Stack

| Category | Package |
|----------|---------|
| State management | `flutter_riverpod` |
| Routing | `go_router` |
| HTTP / SSE | `dio` |
| SSH tunnel | `dartssh2` |
| Markdown | `flutter_markdown` |
| Code highlight | `flutter_highlight` |
| Secure storage | `flutter_secure_storage` |
| Local DB | `sqflite` |
| File picker | `file_picker` |
| Fonts | `google_fonts` |
| Connectivity | `connectivity_plus` |

---

## How Hermes Agent API Server Works

Hermes Agent v0.16.0 exposes an API server on port `8642` when these environment variables are set in `~/.hermes/.env`:

```env
API_SERVER_ENABLED=true
API_SERVER_KEY=your-secret-key
API_SERVER_PORT=8642
API_SERVER_HOST=127.0.0.1
```

The `aiohttp` package must be installed on the server for the API server to start.

Health endpoint:

```bash
curl http://127.0.0.1:8642/health
# {"status": "ok", "platform": "hermes-agent"}
```

Chat completions use OpenAI-compatible SSE streaming:

```bash
POST /v1/chat/completions
{
  "model": "default",
  "messages": [{ "role": "user", "content": "hello" }],
  "stream": true
}
```

---

## Why SSH Local Forwarding?

The API server is intentionally bound to `127.0.0.1` by default so it is **never exposed to the internet**. The Flutter app uses SSH local forwarding (`ssh -L` equivalent) so the phone can reach the server through the encrypted SSH tunnel on port 22, without opening any additional firewall ports.

This is the same pattern used by Hermes Desktop's SSH Tunnel mode and the reverse pattern used by `node_host_tunnel.py` to give a VPS access to the local Chrome DevTools port.

---

## Run

```bash
cd D:\Dataku\Programer\live\hermes_mobile
flutter pub get
flutter run
```

---

## Project Origin

This mobile client was built to mirror the Hermes Desktop experience on mobile devices. The original configuration and tooling live in a separate workspace at:

```
c:\Users\RejalPC\Desktop\Hermes Config
```

That workspace contains:
- VPS connection configuration (`rejalserver` alias, SSH keys)
- Hermes Agent gateway management scripts
- Chrome DevTools MCP bridge scripts (`mcp_hermes_panel.py`, `node_host_tunnel.py`)
- Session logs and project documentation

The Flutter project is kept separate to maintain a clean boundary between the mobile client codebase and the Hermes configuration/tooling workspace.

---

## Security Notes

- API keys and private keys are stored with `flutter_secure_storage`.
- Private key files are read at runtime but not stored in plain text preferences.
- When using SSH Tunnel mode, the API server never needs to be exposed to the public internet.
