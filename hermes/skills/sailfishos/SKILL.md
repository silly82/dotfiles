---
name: sailfishos
description: >
  Reference and workflow guide for developing, packaging, and shipping apps on
  Sailfish OS (Jolla's Linux mobile OS). Use this skill whenever the user works
  with Sailfish OS, Jolla devices, Silica/QML UI, the Sailfish SDK, the sfdk CLI,
  Harbour/Jolla Store submission, RPM packaging for Sailfish, Sailjail sandboxing,
  or porting Sailfish OS to new hardware — even if they only mention "Jolla",
  "Sailfish", "Silica", "Xperia + Sailfish", "sfdk", or "harbour" without saying
  "Sailfish OS" explicitly. Also use it for questions about supported devices,
  current OS versions, licensing, or the Android AppSupport layer. Verify anything
  version- or availability-dependent against the live docs before relying on it.
---

# Sailfish OS

Sailfish OS is a Qt/QML-based, RPM-packaged Linux mobile OS developed by Jolla.
Apps are written in **QML + C++** (Python is also fully supported) on top of the
**Sailfish Silica** UI toolkit, built with the **Sailfish SDK**, and distributed
through **Harbour** (the Jolla Store). Much of the platform is open source; some
components remain proprietary.

The canonical, always-current source is **https://docs.sailfishos.org/**. This
skill summarizes the stable structure and the constraints that trip people up.
For anything that changes between releases (exact version numbers, device
support, allowed-API lists), fetch the live page rather than trusting memory.

## Current facts (verify before quoting)

These were accurate as of early 2026; re-check the live docs if the answer
depends on them:

- Latest release line: **Sailfish OS 5.0** (released 24 February 2025).
- Vendor: **Jolla** (development continued under Jollyboys Oy after the 2023
  restructuring that separated it from its former Russian ownership).
- Reference hardware: **Jolla C2** (ships with a Sailfish OS licence included)
  and the **Mind2** device.
- Community/porting targets via Sailfish X: Sony **Xperia X, XA2, 10, 10 II,
  10 III, 10 IV, 10 V**.
- Since September 2025, Jolla has been progressively **open-sourcing** more
  previously-closed components.
- Security sandboxing uses **Sailjail** (built on Firejail), mandatory for
  sandboxed native apps since 4.0.1.

When a user asks "what's the newest version / is device X supported?", fetch
`https://docs.sailfishos.org/Support/Releases/` and
`https://docs.sailfishos.org/Support/Supported_Devices/` — do not answer from
memory, these move.

## Choosing the right task path

Match the user's goal to the right area before diving in:

- **Building an app** → SDK setup + Silica/QML (see "App development workflow").
- **Getting an app into the Jolla Store** → Harbour rules (see "Harbour /
  Jolla Store submission"). This is the most constraint-heavy path.
- **Contributing to the OS itself** (fixing/extending core packages, not an app)
  → Platform core development (see "Platform (core OS) development"). Different
  from app dev: you build/deploy/test core packages and merge upstream.
- **Porting the OS to new hardware** → HW Adaptation + the HADK
  (`https://docs.sailfishos.org/Develop/HADK/`). Very different workflow; heavy,
  device-specific, not app development.
- **Installing/flashing on an Xperia** →
  `https://docs.sailfishos.org/Support/Help_Articles/Managing_Sailfish_OS/Installing_Sailfish_OS/`.
  Requires a purchased licence tied to a Jolla account + device IMEI.
- **Running Android apps** → the proprietary **Android AppSupport** layer
  (available on supported devices via Settings), not a dev task per se.

## App development workflow

### 1. Install the SDK

The **Sailfish SDK** bundles: a Qt Creator-based **Sailfish IDE**, a **build
engine** (a VM with the cross-compilation toolchains and build targets), the
**Emulator** (x86 VM of the device software), and the **`sfdk`** command-line
tool. Download and installation instructions:
`https://docs.sailfishos.org/Tools/Sailfish_SDK/` and its Installation subpage.

Early-access build targets/emulator are available ~a week before public
releases — useful for testing apps against an upcoming OS version.

### 2. Create the project

In the IDE: File → New File or Project → use the Sailfish OS app template. See
`https://docs.sailfishos.org/Develop/Apps/Your_First_App/` and the
Code Walkthrough. Native project build systems supported directly are **qmake**
and **CMake**; other build systems can be handled via the manual/CLI packaging
route (see "advanced techniques" tutorial).

Third-party apps should link **libsailfishapp** — it sets up correct install
paths, speeds startup, and exposes runtime path helpers. Docs:
`https://sailfishos.org/develop/docs/libsailfishapp`.

### 3. Build the UI with Silica

- **Sailfish Silica** is the QML module providing the platform UI components:
  pulley menus, application cover, page stack, `ApplicationWindow`, etc. It is
  what makes an app look and behave like a Sailfish app.
- Stack: **Qt 5** + **Qt Quick 2** + **Wayland** compositor. QML is the
  preferred language for UI; drop to **C++** for performance, existing C/C++
  libraries, or heavy processing. **Python** is fully supported and fine for
  modest apps (see the Python tutorial).
- Follow the **UI "Definition of Done"** checklist
  (`https://docs.sailfishos.org/Develop/Apps/UI/Definition_of_Done/`) and the
  **Common Pitfalls** page
  (`https://sailfishos.org/develop/docs/silica/sailfish-application-pitfalls.html/`)
  — these catch the anti-patterns reviewers reject.
- Use the **Sailfish Icon Reference** for platform-style vector icons (auto-
  scaled; don't hand-resize).

### 4. Iterate faster

- **Emulator** for gestures/task-switching/ambience without a device.
- **Qt QmlLive** for live QML coding without redeploying (see the QmlLive
  tutorial).
- Deploy to a real device over the network from the IDE for final checks.

### 5. Build from the command line with `sfdk`

`sfdk` (in the SDK's `bin/`) builds packages without the IDE — handy for CI.
Platform notes: on **Windows** run it from an **MSYS2 MSYS** shell; on **macOS**
install a newer `bash` + `bash-completion@2` from Homebrew.

### Key app-facing APIs

Point the user to the specific API when their feature needs it (all under
`https://sailfishos.org/develop/docs/...` unless noted):

- **Silica** — core UI components.
- **Sailfish Pickers** — content/file picker components.
- **Configuration (DConf)** — read/write settings from QML with bindings.
- **Nemo D-Bus plugin** — call/expose services on system/session bus.
- **Notifications** — categorized banners/sounds/vibration.
- **Sailfish Share (Transfer Engine)** — share content via BT/SMS/email/etc.
- **Sailfish WebView** — embed web content.
- **Amber Web Authorization** — OAuth1.0a / OAuth2 flows (C++ and QML).
- **MDM API** — device-management policies (2nd-party, still evolving).

## Platform (core OS) development

This is a **separate workflow from app development**. It covers adding features,
fixing bugs, addressing security issues, writing unit tests, or improving docs
in the **Sailfish OS core packages** — the layer that sits on top of the
hardware adaptation in the platform architecture. Don't route an app author
here, and don't apply Harbour's allowed-API limits to it — those bind third-
party apps, not core-package work.

The high-level loop: interact with the **source repositories**, use the
**Sailfish SDK** to **build** the package, **deploy** and **test** it on a
device/emulator, then **merge the change back** through the collaborative
development process.

Key entry points (fetch the specific one the task needs):

- **Collaborative development process** (the umbrella workflow, incl. how to
  contribute the change): `https://docs.sailfishos.org/Develop/Collaborate/`
- **Getting the OS source**:
  `https://docs.sailfishos.org/Services/Development/Sailfish_OS_Source`
- **Building packages**:
  `https://docs.sailfishos.org/Tools/Sailfish_SDK/Building_packages`
- **Deploying packages**:
  `https://docs.sailfishos.org/Tools/Sailfish_SDK/Deploying_packages`
- **Architecture** (where core packages sit):
  `https://docs.sailfishos.org/Reference/Architecture`
- **Core Areas and APIs** (what the core is made of):
  `https://docs.sailfishos.org/Reference/Core_Areas_and_APIs`
- **Packaging formats** + the **upstream-git / long-lived topic branch**
  approach: `https://docs.sailfishos.org/Develop/Platform/Usage_of_packaging_formats/`
- **Platform testing advice**:
  `https://docs.sailfishos.org/Develop/Platform/Testing_Advice/`
- **Cheat Sheet** of commonly used dev commands:
  `https://docs.sailfishos.org/Reference/Sailfish_OS_Cheat_Sheet`

## Harbour / Jolla Store submission

Harbour is the review + distribution pipeline for the Jolla Store. It is the
strictest part of the whole process — design for it from the start, because
retrofitting is painful. Before promising an app can ship, check it against:

- **Allowed APIs**:
  `https://docs.sailfishos.org/Develop/Apps/Harbour/Allowed_APIs/`
- **Allowed Permissions**:
  `https://docs.sailfishos.org/Develop/Apps/Harbour/Allowed_Permissions/`
- **API Checklist** (the philosophy behind what gets allowed):
  `https://docs.sailfishos.org/Develop/Apps/Harbour/API_Checklist/`

Principles that follow from the checklist — use these to predict whether
something will be accepted:

- Only **stable, non-deprecated, documented** APIs that already exist in the
  repositories are allowed. Unstable or private APIs → rejection.
- APIs that **expose sensitive user data** are restricted.
- **Low-level C APIs are generally not allowed** when a C++/QML equivalent
  exists — prefer the QML/C++ API for the same purpose.
- **No new language runtimes** — the platform is C, C++, and QML (with the
  supported Python tooling). Don't propose shipping an app that drags in another
  runtime.
- Packages are **RPM**; apps run under **Sailjail** sandboxing with declared
  **permissions**. Declare the minimum set of permissions the app truly needs.
- If a needed API isn't on the allowed list, the path is to request it (it must
  pass the checklist) — not to work around the sandbox.

Packaging + signing details:
`https://docs.sailfishos.org/Develop/Apps/Packaging/` and its Signing subpage.

Note the alternative store **OpenRepos / Storeman** exists in the community and
has *no* Harbour restrictions — but apps there are unvetted and can use
restricted APIs. If the user targets OpenRepos, the Harbour allowed-API limits
don't apply; if they target the official Jolla Store, they do.

## Coding conventions

Sailfish apps are Qt/QML and should follow **Qt coding conventions**:
`https://docs.sailfishos.org/Develop/Apps/Coding_Conventions/`. Keep QML
declarative and move complex logic to C++ where it matters.

## Reference map (fetch on demand)

Don't paste these wholesale; fetch the specific one the task needs.

| Need | URL |
|------|-----|
| Docs home | https://docs.sailfishos.org/ |
| App dev hub | https://docs.sailfishos.org/Develop/Apps/ |
| First app | https://docs.sailfishos.org/Develop/Apps/Your_First_App/ |
| C++ + QML | https://docs.sailfishos.org/Develop/Apps/Tutorials/Combining_C++_with_QML/ |
| Python app | https://docs.sailfishos.org/Develop/Apps/Tutorials/Creating_an_application_in_Python/ |
| Debugging | https://docs.sailfishos.org/Develop/Apps/Tutorials/Debugging_applications/ |
| SDK / tools | https://docs.sailfishos.org/Tools/Sailfish_SDK/ |
| Platform (core OS) dev | https://docs.sailfishos.org/Develop/Platform/ |
| Collaborative dev process | https://docs.sailfishos.org/Develop/Collaborate/ |
| OS source | https://docs.sailfishos.org/Services/Development/Sailfish_OS_Source |
| Building packages | https://docs.sailfishos.org/Tools/Sailfish_SDK/Building_packages |
| Deploying packages | https://docs.sailfishos.org/Tools/Sailfish_SDK/Deploying_packages |
| Architecture | https://docs.sailfishos.org/Reference/Architecture |
| Core Areas and APIs | https://docs.sailfishos.org/Reference/Core_Areas_and_APIs |
| Cheat Sheet | https://docs.sailfishos.org/Reference/Sailfish_OS_Cheat_Sheet |
| Harbour allowed APIs | https://docs.sailfishos.org/Develop/Apps/Harbour/Allowed_APIs/ |
| Harbour permissions | https://docs.sailfishos.org/Develop/Apps/Harbour/Allowed_Permissions/ |
| Packaging | https://docs.sailfishos.org/Develop/Apps/Packaging/ |
| HW adaptation / HADK | https://docs.sailfishos.org/Develop/HADK/ |
| Supported devices | https://docs.sailfishos.org/Support/Supported_Devices/ |
| Releases | https://docs.sailfishos.org/Support/Releases/ |
| Install Sailfish OS | https://docs.sailfishos.org/Support/Help_Articles/Managing_Sailfish_OS/Installing_Sailfish_OS/ |
| Forum (support) | https://forum.sailfishos.org/ |
| Source code | https://github.com/sailfishos/ |
| Community wiki | https://sailfishos.wiki/ |

## Guardrails

- Documentation is licensed **CC-BY-NC-SA 4.0** — summarize/paraphrase, don't
  wholesale-copy pages into deliverables.
- For version numbers, device support, and allowed-API lists: **fetch, don't
  recall.** These change every release and stale answers mislead.
- Distinguish **Harbour (Jolla Store)** rules from **OpenRepos** — the API
  constraints only bind the former. State which target you're assuming.
- Three distinct workflows — don't conflate them: **app development** (SDK +
  Silica), **platform/core-package development** (Collaborate process, build/
  deploy/merge upstream), and **OS-to-hardware porting** (HADK). Harbour's
  allowed-API limits apply only to third-party apps, not to core-package work.
