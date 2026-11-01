# sendblob

Share a file from your browser using iroh-blobs: [sendblob.app](https://sendblob.app). Drop a file, share the ticket or link, and the recipient downloads it — from another browser tab or from any iroh-blobs node (e.g. the companion CLI).

## How it works

- Each tab runs an ephemeral iroh node (WASM + OPFS store) speaking the
  standard iroh-blobs protocol.
- Sharing = importing bytes into the local store + handing out a ticket
  (`blob…` or the 88-char compact form embedded in the link).
- Receiving = resolving the ticket, downloading and validating chunks
  into OPFS, then saving to disk.

Works with any iroh node: browser tabs interoperate with the native CLI
(`provide` / `download`) and other iroh-blobs peers over the same ALPN.

## Network reality

- This is not direct browser-to-browser P2P today. Browsers cannot open
  direct QUIC/TCP connections, so traffic is relayed through public iroh
  relays, with discovery to find the sender.
- Relayed traffic stays end-to-end encrypted by iroh: relays forward
  bytes but cannot read file contents. They do see metadata (endpoints,
  volumes) and are a hard dependency — no relay, no transfer.
- Direct browser connectivity should come via WebTransport support in
  iroh. Until then, expect relay bandwidth/latency and relay availability
  to bound performance.

## Ephemeral by design

Closing the tab stops the node. Files live in a per-tab OPFS directory,
reclaimed by a Web Locks-based purge; nothing is uploaded to persistent
cloud storage by sendblob itself.

## Development

Prerequisites: Rust with the `wasm32-unknown-unknown` target,
`wasm-bindgen-cli` 0.2.129 (must match the crate version), Node.js 24.

- `npm run dev` — build the WASM module and start the Vite dev server
- `npm run build` — production build (WASM + frontend)
- `npm run typecheck` — TypeScript check
- `cargo test --all-features` — Rust tests

## Self-hosting with Nix and Docker

The runtime image contains only the built site and a statically linked
darkhttpd server. There is no shell, Node.js, Rust, database, or writable
storage in the container. File transfers still use the public iroh relays;
this container serves the app, not the transferred files or a relay.

On a Linux build machine with Nix (flakes enabled), the locked flake
provides Rust (including the WASM target), Node.js, Binaryen, and the matching
wasm-bindgen CLI. Build and load the image:

```sh copy Copy Build Commands
nix develop --command npm ci
nix develop --command npm run build:release
nix run .
docker load < /tmp/sendblob-image
docker compose up -d
```

`nix run .` packages the current `dist/` using `default.nix` and writes an
image archive symlink at `/tmp/sendblob-image` (override with
`nix run . -- --out-link /your/path`). Run it from the repository root.
Nix dependencies are pinned in `flake.lock`; the frontend is built
separately using the project's lockfiles and existing release pipeline.
Rebuild it before rebuilding the image. No Docker daemon is needed to
build the image. Linux x86-64 and ARM64 builds are supported; build on the
same CPU architecture as the deployment host. You can copy the resulting
image archive and `compose.yaml` to a separate Docker host and load/run
them there.

### GitHub Container Registry

The `Container` workflow builds and smoke-tests the image on pull requests.
On pushes to `main`, `v*` tags, and manual runs, it also publishes to
`ghcr.io/<owner>/<repository>` using `GITHUB_TOKEN`; no registry secret is
needed. `main` gets `latest`, version tags get their tag name, and all
published builds get a `sha-<short-commit>` tag. CI currently publishes
Linux x86-64 images only. Existing GitHub Pages deployment is unchanged.

After the first successful publish, make the package public in GitHub's
package settings for anonymous pulls, or authenticate with `docker login
ghcr.io` for private pulls. If an existing package rejects the push, grant
this repository Actions access to that package. To use the registry image:

```sh copy Copy Registry Deployment
SENDBLOB_IMAGE=ghcr.io/tiecoon/sendblob:latest docker compose up -d --pull always
```

Replace the image path if deploying a fork. Set `SENDBLOB_IMAGE` in `.env`
to keep using that image on subsequent Compose commands. Prefer a version
or SHA tag rather than `latest` when you need controlled upgrades.

### Runtime and HTTPS

The app is available at <http://localhost:8080>. Compose binds to loopback
only and runs as UID/GID 65534 with a read-only filesystem, no Linux
capabilities, a 32 MiB memory ceiling, half a CPU, and bounded logs. These
are starting limits, not a guarantee for every traffic level; raise them
if your workload needs it. The server accepts up to 128 connections and
closes idle connections after 15 seconds. There are no volumes to manage.

For public hosting, put an HTTPS reverse proxy on the Docker host in front
of `127.0.0.1:8080` and point your domain at it. HTTPS is required outside
localhost for the browser APIs used by the app. For example, an existing
Caddy installation can use:

```caddyfile copy Copy Caddy Config
sendblob.example.com {
    reverse_proxy 127.0.0.1:8080
}
```

If the reverse proxy is itself a container, attach both services to the
same Docker network and proxy to `sendblob:8080` instead. Do not expose the
unencrypted app port directly to the Internet.

---

*Inspired by the `browser-blobs` example from the [n0-computer/iroh](https://github.com/n0-computer/iroh) team.*
