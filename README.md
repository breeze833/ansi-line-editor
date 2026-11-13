# ansi-line-editor

> Zero-dependency, high-performance, prompt-safe ANSI/VT100 terminal line-editing engine for JavaScript and TypeScript runtimes.

[![CI](https://github.com/breeze833/ansi-line-editor/actions/workflows/test.yml/badge.svg)](https://github.com/breeze833/ansi-line-editor/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## Overview

`ansi-line-editor` provides a complete, modern line-editing experience (`readline`) for browser terminals ([`xterm.js`](https://github.com/xtermjs/xterm.js)), WebAssembly language runtimes (WASI, Emscripten, Pyodide), Node.js / Bun / Deno CLI applications, and WebSerial / WebSocket terminal proxies.

Unlike conventional line editors that assume they own the line from column 0, `ansi-line-editor` uses **strict relative cursor positioning**. It redraws, modifies, and navigates lines without emitting absolute carriage returns (`\r`), ensuring external prompts printed by child processes (such as BusyBox `ash`, SQLite `sqlite> `, Python `>>> `, or GDB `(gdb) `) are **never erased or corrupted**.

---

## Key Features

- **Prompt-Safe Relative Redrawing**: Redraws and clears buffers strictly relative to the current cursor position (`\b.repeat(cursor)` + `\x1b[K`), leaving external prompts untouched.
- **Contextual History Isolation**: Supports isolated history stacks per context (`historyContext`), preventing shell commands from bleeding into interactive sub-prompts (e.g. SQLite queries or `scanf` inputs).
- **Uncommitted Scratch Preservation**: Caches uncommitted draft text when traversing backward into history (`Up`), cleanly restoring it when returning to the baseline (`Down`).
- **Complete VT100 / ANSI Support**: Handles cursor navigation (arrows, Home/End, Ctrl+A/E), in-line deletion (Backspace, Delete, Ctrl+K, Ctrl+U), and control signals (Ctrl+C interrupt, Ctrl+D EOF, Enter, Tab).
- **Zero Dependencies**: 100% pure vanilla JavaScript (~250 LOC). Zero third-party npm packages, zero native C/C++ bindings, and zero Node.js/DOM requirements.

---

## Installation

`ansi-line-editor` is published directly to [GitHub Releases](https://github.com/breeze833/ansi-line-editor/releases) as pre-packaged `.tgz` distribution archives.

### Install via GitHub Releases Tarball

```bash
# Install the latest release tarball directly:
npm install https://github.com/breeze833/ansi-line-editor/releases/download/latest/ansi-line-editor-0.1.0.tgz
```

Or add directly to `package.json`:

```json
{
  "dependencies": {
    "ansi-line-editor": "https://github.com/breeze833/ansi-line-editor/releases/download/latest/ansi-line-editor-0.1.0.tgz"
  }
}
```

### Install directly from Git Repository

```bash
npm install github:breeze833/ansi-line-editor
# or target a specific release tag:
npm install github:breeze833/ansi-line-editor#v0.1.0
```

---

## Quick Start

### Integrating with `xterm.js` in the Browser

```javascript
import { Terminal } from '@xterm/xterm';
import { LineEditor } from 'ansi-line-editor';

const term = new Terminal();
term.open(document.getElementById('terminal'));

const editor = new LineEditor({
  // Terminal output hook
  write: (str) => term.write(str),

  // Called when the user hits Enter
  onLine: (line) => {
    term.write('\r\n');
    console.log('User entered:', line);
    // Display next prompt
    term.write('my-shell$ ');
  },

  // Called on Ctrl+C
  onInterrupt: () => {
    term.write('^C\r\nmy-shell$ ');
    editor.reset();
  },

  // Called on Ctrl+D
  onEof: (buffer) => {
    if (buffer.length === 0) {
      term.write('\r\nexit\r\n');
    }
  },
});

// Feed raw terminal input directly to editor
term.onData((data) => editor.feed(data));

// Print initial prompt
term.write('my-shell$ ');
```

---

### Contextual History Isolation

When switching between a top-level shell and sub-prompts (such as a database REPL or interactive C program input):

```javascript
// Top-level shell prompt
editor.setHistoryContext('shell');

// When user launches SQLite:
term.write('\r\nsqlite> ');
editor.setHistoryContext('sqlite');

// When exiting back to shell:
term.write('\r\nmy-shell$ ');
editor.setHistoryContext('shell');
```

Each context maintains its own independent history stack and recall pointer.

---

## API Reference

### `new LineEditor(options?: LineEditorOptions)`

#### Options

| Option | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `write` | `(data: string) => void` | `() => {}` | Callback receiving ANSI terminal escape sequences and characters. |
| `historyContext` | `string` | `'default'` | Key identifier for contextual history isolation. |
| `maxHistory` | `number` | `200` | Maximum number of history entries retained per context. |
| `onLine` | `(line: string) => void` | `null` | Invoked when the user commits a line (`Enter`). |
| `onTab` | `(buffer: string, cursor: number) => void` | `null` | Invoked when `Tab` is pressed for completion. |
| `onEof` | `(buffer: string) => void` | `null` | Invoked on EOF (`Ctrl+D`). |
| `onInterrupt` | `() => void` | `null` | Invoked on Interrupt (`Ctrl+C`). |

#### Methods

| Method | Description |
| :--- | :--- |
| `feed(key: string): boolean` | Feeds a raw keystroke string into the editor. Returns `true` if handled. |
| `setBuffer(newBuffer: string, newCursor?: number): void` | Safely replaces the buffer and repositions the cursor using relative erasing without destroying external prompts. |
| `getBuffer(): string` | Returns the current uncommitted text buffer. |
| `getCursor(): number` | Returns the current 0-based cursor offset within the buffer. |
| `reset(): void` | Clears internal buffer, cursor, and scratch state without emitting terminal sequences. |
| `clearFromTerminal(): void` | Emits relative backspaces and line-clear codes to erase the current buffer from the screen. |
| `commitHistory(line?: string): void` | Appends a command string to the active history context (deduplicating consecutive duplicates). |
| `setHistoryContext(ctx: string): void` | Switches active history context, resetting the history pointer and scratch buffer. |
| `getHistory(): string[]` | Returns the active context's history array. |

---

## Technical Specification

For in-depth architectural details, design invariants, and escape sequence mechanics, see [`SPEC.md`](./SPEC.md).

---

## License

[MIT](./LICENSE) © 2026 breeze833
