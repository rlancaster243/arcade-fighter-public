# Builder environment (Linux agents)

CI uses the Docker image `swift:6.1.3-noble` and runs `swift test --parallel` in `FightCore/` (see `.github/workflows/build.yml`).

## Recommended toolchain

- **Swift 6.1.3** on Ubuntu 24.04 (Noble), matching CI.
- **macOS app builds** require Xcode **16.4** on macOS 15+ (CI `app-macos` job).

## Installing Swift 6.1.3 on Ubuntu 24.04

### Option A — Official Docker image (matches CI)

```bash
docker pull swift:6.1.3-noble
docker run --rm -v "$PWD":/workspace -w /workspace/FightCore swift:6.1.3-noble swift test --parallel
```

Pin digest: `swift:6.1.3-noble@sha256:42b58c8cff07f45e6f083ade65743b5b147d0c01d4370d602fcf3c7b37dc1cac`

### Option B — swift.org tarball

Download `swift-6.1.3-RELEASE-ubuntu24.04.tar.gz` from [Swift releases](https://www.swift.org/install/linux/ubuntu/24_04/), extract to `/opt/swift-6.1.3`, and add `/opt/swift-6.1.3/usr/bin` to `PATH`.

## Phase 0 agent VM (this run)

| Step | Result |
|------|--------|
| `download.swift.org` tarball | **Failed** — host not on cloud agent egress allowlist (`SSL_ERROR_SYSCALL`). |
| `docker pull swift:6.1.3-noble` | **Failed** — Docker not installed on VM. |
| GitHub release mirror for tarball | **404** on attempted asset URL. |

**Could not verify locally:** `swift build` / `swift test` in `FightCore/` on this VM. Draft PR left until toolchain is available or CI runs on push.

When Swift is available:

```bash
cd FightCore
swift --version
swift build
swift test --parallel
swift run FightSim
echo $?   # expect 0
```