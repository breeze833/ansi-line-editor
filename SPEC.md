# SPEC.md: Architectural Specification for `ansi-line-editor`

---

## 1. Architectural Ground Truth & Mission Statement

`ansi-line-editor` is a zero-dependency, high-performance, **prompt-safe ANSI/VT100 terminal line-editing engine** for JavaScript and TypeScript runtimes.

Designed specifically for web terminals ([`xterm.js`](https://github.com/xtermjs/xterm.js), `hterm`), in-browser IDEs (such as [`wasm-c-ide`](https://github.com/breeze833/wasm-c-ide)), WebAssembly language runtimes (WASI, Emscripten, Pyodide), Node.js / Bun / Deno CLI applications, and WebSerial / WebSocket terminal proxies, `ansi-line-editor` provides a complete, modern line-editing experience (`readline`) without clobbering external prompts or assuming the terminal cursor begins at column 0.

---

## 2. Motivation & Architectural Problem Statement

In conventional terminal emulators and web-based CLI environments, line-editing routines (such as standard Readline ports or naive input listeners) frequently break when interacting with external processes or complex prompt layouts.

### 2.1 The Prompt-Clobbering Dilemma
Most terminal line editors assume they own the entire terminal line:
1. When redrawing the line (e.g. during history recall, backspacing, or cursor navigation), they emit a carriage return (`\r`) followed by an ANSI line-clear sequence (`\x1b[K`), effectively clearing the line from column 0.
2. In real-world terminal environments, however, **the prompt is printed by the running application or host process** (such as BusyBox `ash`, GNU GDB `(gdb) `, SQLite `sqlite> `, Python `>>> `, or remote SSH shells).
3. Emitting `\r\x1b[K` instantly **erases and destroys the external prompt**, leaving the terminal in a visually corrupt state with missing prompts and broken column alignments.

### 2.2 History Bleeding Across Multi-REPL Environments
Modern browser IDEs and terminal environments switch frequently between different command contexts:
- A user runs commands in a POSIX shell (`gcc`, `make`, `ls`).
- The user launches an interactive database CLI (`sqlite3`) or standard C program (`scanf`).
- Traditional global history buffers bleed shell commands into database queries and application inputs, disrupting history navigation.

### 2.3 Scratch Buffer Loss During Traversal
When a user writes an uncommitted command line, presses the Up arrow to inspect earlier history, and then returns with the Down arrow, naive editors overwrite or discard the uncommitted draft.

`ansi-line-editor` resolves these issues via **strict relative cursor positioning**, **prompt-safe redrawing**, **contextual history isolation**, and **uncommitted scratch preservation**.

---

## 3. Target Platform & Environment Profile

- **Host Runtimes**:
  - Modern web browsers (main thread and Web Workers).
  - Node.js (>= 18, standard ES Modules and CommonJS).
  - Bun and Deno.
  - Headless CI environments and embedded WebSerial / WebUSB terminal monitors.
- **Zero Runtime Dependencies**: 100% pure vanilla JavaScript with zero third-party npm packages, zero native C/C++ bindings, and zero Node.js/DOM built-in dependencies.
- **Terminal Compatibility**: Fully compatible with VT100, VT220, xterm, and standard ANSI terminal emulators.

---

## 4. Core Design Invariants

When implementing or extending `ansi-line-editor`, the following fundamental invariants must be strictly maintained:

1. **Strict Prompt-Safe Invariant (Relative Redrawing Only)**:
   - The line editor must never emit absolute carriage returns (`\r`) or absolute column resets when redrawing, clearing, or modifying the input buffer.
   - All erase operations must be strictly relative to the current cursor position:
     $$\text{eraseSequence} = \texttt{"\\b"}^{\text{cursor}} + \texttt{"\\x1b[K"}$$
   - This ensures the external prompt preceding the buffer remains untouched regardless of column position.

2. **Decoupled Transport & I/O Boundary**:
   - The editor does not bind directly to DOM events, sockets, or Node streams.
   - Keystrokes enter via `feed(data: string)`.
   - Terminal escape sequences exit via a user-supplied callback `write(data: string)`.

3. **Contextual History Isolation**:
   - The history system must maintain separate, isolated history stacks indexed by context keys (`historyContext`).
   - Switching contexts must isolate recall indices and preserve uncommitted scratch states per context.

4. **Preservation of Uncommitted Scratch**:
   - Traversing backward into history (`Up`) from an in-progress line must cache the uncommitted buffer.
   - Traversing forward back to the baseline (`Down`) must restore the exact uncommitted buffer and cursor position.

5. **ANSI VT100 Escape Code Completeness**:
   - Full support for standard editing sequences:
     - Navigation: Left (`\x1b[D`), Right (`\x1b[C`), Home (`\x1b[H`, `\x1b[1~`, `Ctrl+A`), End (`\x1b[F`, `\x1b[4~`, `Ctrl+E`).
     - Modification: Backspace (`\x7f`, `\x08`), Delete (`\x1b[3~`), Kill to end (`\x0b` / `Ctrl+K`), Clear line (`\x15` / `Ctrl+U`).
     - Control Signals: Interrupt (`\x03` / `Ctrl+C`), EOF (`\x04` / `Ctrl+D`), Commit (`\r`, `\n`), Tab completion hook (`\t`).
   - Unknown escape sequences (e.g. mouse tracking, function keys `F1-F12`) must be gracefully consumed without polluting the text buffer.

---

## 5. Repository Topology & Source File Organization

```
ansi-line-editor/
├── SPEC.md                    # Technical specification & architectural ground truth (this file)
├── AGENTS.md                  # Developer & AI agent operating protocols
├── README.md                  # User-facing documentation, API reference, and examples
├── LICENSE                    # MIT License
├── package.json               # Package metadata, exports, and npm test scripts
├── Makefile                   # Convenience Makefile (test, build, pack, clean)
├── .github/
│   └── workflows/
│       └── release.yml        # Automated release packaging & publishing on v* tags
├── src/
│   ├── index.js               # Main package entry point and unified exports
│   └── line-editor.js         # Core LineEditor class implementing relative cursor engine
└── test/
    └── line-editor.test.js    # Comprehensive automated test suite
```

---

## 6. Detailed API Specification

### 6.1 Constructor Options (`LineEditorOptions`)

```typescript
interface LineEditorOptions {
  /** Output callback receiving ANSI terminal escape sequences and characters. */
  write?: (data: string) => void;

  /** Key identifier for contextual history isolation. Default: 'default'. */
  historyContext?: string;

  /** Maximum number of history entries retained per context. Default: 200. */
  maxHistory?: number;

  /** Callback invoked when the user commits a line (Enter). */
  onLine?: (line: string) => void;

  /** Callback invoked when Tab is pressed for completion. */
  onTab?: (buffer: string, cursor: number) => void;

  /** Callback invoked on EOF (Ctrl+D) with current buffer content. */
  onEof?: (buffer: string) => void;

  /** Callback invoked on Interrupt (Ctrl+C). */
  onInterrupt?: () => void;
}
```

### 6.2 Public Methods (`LineEditor`)

| Method | Parameters | Return | Description |
| :--- | :--- | :--- | :--- |
| `feed(key)` | `key: string` | `boolean` | Feeds a raw keystroke or character sequence into the editor. Returns `true` if handled. |
| `setBuffer(newBuffer, newCursor?)` | `newBuffer: string, newCursor?: number` | `void` | Safely replaces the buffer and repositions the cursor using relative erasing without destroying external prompts. |
| `getBuffer()` | — | `string` | Returns the current uncommitted text buffer. |
| `getCursor()` | — | `number` | Returns the current 0-based cursor offset within the buffer. |
| `reset()` | — | `void` | Clears the internal buffer, cursor, and scratch state without emitting terminal sequences. |
| `clearFromTerminal()` | — | `void` | Emits relative backspaces and line-clear escape codes to erase the current buffer from the terminal screen. |
| `commitHistory(line?)` | `line?: string` | `void` | Appends a command string (defaulting to current buffer) into the active history context, deduplicating identical consecutive entries. |
| `setHistoryContext(ctx)` | `ctx: string` | `void` | Switches the active history context (e.g. from `'shell'` to `'sqlite'`), resetting the history pointer and scratch buffer. |
| `getHistory()` | — | `string[]` | Returns the active context's history array. |

---

## 7. Verification & Automated Test Standards

The automated test suite must run via standard Node.js without third-party test harnesses:
- **Cursor Navigation & Insertion**: Validates in-line editing, middle character insertion, Home/End jumping, Left/Right boundary clamping.
- **Deletion Mechanics**: Validates Backspace at beginning, middle, and end of buffer; validates forward Delete (`\x1b[3~`), line kill (`Ctrl+K`), and line clear (`Ctrl+U`).
- **Prompt Safety**: Asserts that redrawing operations only emit relative backspaces (`\b`) and clear-to-end (`\x1b[K`), never absolute carriage returns (`\r`).
- **History Traversal & Scratch Restoration**: Verifies Up/Down recall, history indexing bounds, deduplication, and scratch line restoration.
- **Contextual Isolation**: Verifies that distinct history contexts maintain completely independent history stacks.
- **Signal & Event Dispatching**: Validates `onLine`, `onTab`, `onInterrupt`, and `onEof` event triggers.
