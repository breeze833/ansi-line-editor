# AGENTS.md: Developer and AI Agent Guidelines for `ansi-line-editor`

This document provides architectural context, design invariants, coding conventions, and maintenance procedures for AI agents and human contributors working on `ansi-line-editor`.

---

## 1. Project Mission & Architecture

`ansi-line-editor` is a zero-dependency, high-performance, **prompt-safe ANSI/VT100 terminal line-editing engine** for JavaScript and TypeScript runtimes.

Designed specifically for web terminals ([`xterm.js`](https://github.com/xtermjs/xterm.js), `hterm`), in-browser IDEs (such as [`wasm-c-ide`](https://github.com/breeze833/wasm-c-ide)), WebAssembly language runtimes (WASI, Emscripten, Pyodide), Node.js / Bun / Deno CLI applications, and WebSerial / WebSocket terminal proxies, `ansi-line-editor` provides:
1. **Prompt-Safe Relative Redrawing**: Redraws and modifies buffers strictly relative to current cursor position, completely eliminating prompt-clobbering bugs when child processes (such as BusyBox `ash`, SQLite, Python, or GDB) print custom prompts.
2. **Contextual History Isolation**: Supports isolated history stacks per context (`historyContext`), preventing cross-contamination between shell commands and application inputs.
3. **Scratch Preservation**: Automatically caches uncommitted drafts when navigating backward into history, cleanly restoring the draft when returning to the baseline.
4. **Zero-Dependency Architecture**: 100% vanilla JavaScript with zero runtime npm dependencies, zero native C/C++ bindings, and zero Node.js/DOM requirements.

---

## 2. Core Design Invariants

When modifying or extending the codebase, strictly adhere to these fundamental invariants:

1. **Strict Specification Alignment**:
   - `SPEC.md` is the architectural ground truth. Autonomous agents must strictly adhere to the architecture, escape sequences, and API contracts defined in `SPEC.md`. Do not deviate, substitute architectures, or introduce external dependencies.
2. **Zero External Runtime Dependencies**:
   - The core engine (`src/index.js`, `src/line-editor.js`) must remain 100% zero-dependency modern JavaScript.
3. **Strict Prompt-Safe Invariant (Relative Redrawing Only)**:
   - Never emit absolute carriage returns (`\r`) or line resets (`\r\x1b[K`) for buffer edits. All clears and re-renders must be relative to the cursor (`\b.repeat(cursor)` + `\x1b[K`).
4. **Transport Decoupling**:
   - The engine must not bind directly to DOM events, sockets, or Node streams. Keystrokes enter via `feed(data)` and ANSI sequences exit via `write(data)`.
5. **Universal Runtime Support**:
   - The engine must run seamlessly across modern browser main threads, Web Workers, Node.js (>= 18), Bun, and Deno.

---

## 3. Developer Collaboration & Revision Workflow

All agent-assisted development in this repository must strictly adhere to the developer's 4-phase revision workflow:

```
┌──────────────────────────────────────────────────────────────┐
│  Phase 1: Specification Revision & Developer Confirmation     │
│  - Propose/update SPEC.md changes first                      │
│  - Await explicit developer review & approval                │
└──────────────────────────────┬───────────────────────────────┘
                               │ Approved
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  Phase 2: Specification-Compliant Implementation             │
│  - Strictly implement according to the confirmed SPEC.md     │
│  - Verify automated tests (npm test) with zero failures      │
└──────────────────────────────┬───────────────────────────────┘
                               │ Verified
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  Phase 3: Developer Manual Verification                      │
│  - Prompt developer to perform interactive verification      │
│  - Developer tests LineEditor via unit tests and terminals   │
└──────────────────────────────┬───────────────────────────────┘
                               │ Developer Confirmed
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  Phase 4: Explicitly Instructed Document Alignment & Commit  │
│  - Await developer's explicit instruction                    │
│  - Align secondary docs (README.md, package.json, etc.)      │
│  - Stage and commit changes to git repository                │
└──────────────────────────────┘
```

---

## 4. Directory Structure & Key Files

```
ansi-line-editor/
├── SPEC.md                    # Technical specification & architectural ground truth
├── AGENTS.md                  # Developer & AI agent operating protocols (this file)
├── README.md                  # User-facing documentation, API reference, and examples
├── LICENSE                    # MIT license
├── package.json               # Package metadata, exports, and npm test scripts
├── Makefile                   # Convenience Makefile (test, pack, clean)
├── .github/
│   └── workflows/
│       └── release.yml        # Automated release packaging & publishing on v* tags
├── src/
│   ├── index.js               # Main package entry point and unified exports
│   └── line-editor.js         # Core LineEditor implementation
└── test/
    └── line-editor.test.js    # Comprehensive unit and integration test suite
```

---

## 5. Development & Testing Commands

```bash
# Run automated test suite
npm test
# (or: node test/line-editor.test.js)

# Package release archive
make dist

# Clean temporary files
make clean
```

---

## 6. Verification Checklist Before Committing Changes

Before completing tasks or submitting PRs, verify:

- [ ] Specification updated in `SPEC.md` and confirmed by the developer prior to code changes.
- [ ] Implementation strictly conforms to the confirmed `SPEC.md`.
- [ ] Automated tests (`npm test`) pass with zero errors in standard Node.js.
- [ ] Prompt-safety verified: zero absolute `\r` carriage returns used in buffer editing.
- [ ] Contextual history isolation and uncommitted scratch line restoration verified.
- [ ] Developer has conducted verification via tests.
- [ ] Secondary documentation (`README.md`, `package.json`, etc.) aligned upon explicit developer instruction.
- [ ] Git commit performed only when explicitly instructed by the developer.
