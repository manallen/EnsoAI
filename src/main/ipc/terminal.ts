import {
  IPC_CHANNELS,
  type TerminalCreateOptions,
  type TerminalResizeOptions,
} from '@shared/types';
import { ipcMain, type WebContents } from 'electron';
import { PtyManager } from '../services/terminal/PtyManager';

export const ptyManager = new PtyManager();
const terminalCleanupOwners = new Set<number>();

// Batch PTY output before IPC. TUI agents (Claude Code/Codex) emit hundreds of
// small chunks per second; per-chunk webContents.send() overhead dominates with
// many terminals. The first chunk of a burst is sent immediately so keystroke
// echo latency stays at zero; subsequent chunks coalesce into a 16ms window.
const DATA_FLUSH_INTERVAL_MS = 16;
const DATA_FLUSH_MAX_BYTES = 64 * 1024;

interface DataBatcher {
  push: (data: string) => void;
  flush: () => void;
  dispose: () => void;
}

// ownerId allows cleanup when a webContents is destroyed without exit events
const dataBatchers = new Map<string, { batcher: DataBatcher; ownerId: number }>();

function createDataBatcher(send: (data: string) => void): DataBatcher {
  let buffer = '';
  let timer: NodeJS.Timeout | null = null;

  const flush = () => {
    if (timer) {
      clearTimeout(timer);
      timer = null;
    }
    if (buffer.length > 0) {
      const data = buffer;
      buffer = '';
      send(data);
    }
  };

  return {
    push(data) {
      // Idle: send immediately for low latency, then open a batching window
      if (!timer && buffer.length === 0) {
        send(data);
        timer = setTimeout(() => {
          timer = null;
          flush();
        }, DATA_FLUSH_INTERVAL_MS);
        return;
      }
      buffer += data;
      if (buffer.length >= DATA_FLUSH_MAX_BYTES) {
        flush();
      }
    },
    flush,
    dispose() {
      if (timer) {
        clearTimeout(timer);
        timer = null;
      }
      buffer = '';
    },
  };
}

function disposeBatcher(id: string): void {
  const entry = dataBatchers.get(id);
  if (entry) {
    entry.batcher.dispose();
    dataBatchers.delete(id);
  }
}

function disposeBatchersByOwner(ownerId: number): void {
  for (const [id, entry] of dataBatchers) {
    if (entry.ownerId === ownerId) {
      entry.batcher.dispose();
      dataBatchers.delete(id);
    }
  }
}

function disposeAllBatchers(): void {
  for (const entry of dataBatchers.values()) {
    entry.batcher.dispose();
  }
  dataBatchers.clear();
}

function ensureTerminalCleanup(sender: WebContents): void {
  const ownerId = sender.id;
  if (terminalCleanupOwners.has(ownerId)) {
    return;
  }

  terminalCleanupOwners.add(ownerId);
  sender.once('destroyed', () => {
    terminalCleanupOwners.delete(ownerId);
    disposeBatchersByOwner(ownerId);
    ptyManager.destroyByOwner(ownerId);
  });
}

export function destroyAllTerminals(): void {
  terminalCleanupOwners.clear();
  disposeAllBatchers();
  ptyManager.destroyAll();
}

/**
 * Destroy all terminals and wait for them to fully exit.
 * This should be used during app shutdown to prevent crashes.
 */
export async function destroyAllTerminalsAndWait(): Promise<void> {
  terminalCleanupOwners.clear();
  disposeAllBatchers();
  await ptyManager.destroyAllAndWait();
}

export function registerTerminalHandlers(): void {
  ipcMain.handle(
    IPC_CHANNELS.TERMINAL_CREATE,
    async (event, options: TerminalCreateOptions = {}) => {
      ensureTerminalCleanup(event.sender);
      const ownerId = event.sender.id;

      // node-pty delivers data asynchronously, so ptyId is assigned before
      // the first push can ever fire.
      let ptyId = '';
      const batcher = createDataBatcher((data) => {
        if (!event.sender.isDestroyed()) {
          event.sender.send(IPC_CHANNELS.TERMINAL_DATA, { id: ptyId, data });
        }
      });

      const id = ptyManager.create(
        options,
        (data) => {
          batcher.push(data);
        },
        (exitCode, signal) => {
          // Flush pending output first so the renderer never sees exit before data
          batcher.flush();
          dataBatchers.delete(id);
          if (!event.sender.isDestroyed()) {
            event.sender.send(IPC_CHANNELS.TERMINAL_EXIT, { id, exitCode, signal });
          }
        },
        ownerId
      );

      ptyId = id;
      dataBatchers.set(id, { batcher, ownerId });

      return id;
    }
  );

  ipcMain.handle(IPC_CHANNELS.TERMINAL_WRITE, async (_, id: string, data: string) => {
    ptyManager.write(id, data);
  });

  ipcMain.handle(
    IPC_CHANNELS.TERMINAL_RESIZE,
    async (_, id: string, size: TerminalResizeOptions) => {
      ptyManager.resize(id, size.cols, size.rows);
    }
  );

  ipcMain.handle(IPC_CHANNELS.TERMINAL_DESTROY, async (_, id: string) => {
    disposeBatcher(id);
    ptyManager.destroy(id);
  });

  ipcMain.handle(IPC_CHANNELS.TERMINAL_GET_ACTIVITY, async (_, id: string) => {
    return ptyManager.getProcessActivity(id);
  });
}
