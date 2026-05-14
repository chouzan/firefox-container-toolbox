export type ToastType = "success" | "error" | "info" | "warning";

export interface ToastItem {
  id: number;
  message: string;
  type: ToastType;
}

let nextId = 0;
let items: ToastItem[] = [];
const listeners = new Set<(toasts: ToastItem[]) => void>();

function emit() {
  const snapshot = [...items];
  for (const fn of listeners) fn(snapshot);
}

export function subscribe(fn: (toasts: ToastItem[]) => void): () => void {
  listeners.add(fn);
  fn([...items]);
  return () => listeners.delete(fn);
}

export function dismiss(id: number) {
  items = items.filter((t) => t.id !== id);
  emit();
}

function add(message: string, type: ToastType, duration: number) {
  const id = nextId++;
  items = [...items, { id, message, type }];
  emit();
  setTimeout(() => dismiss(id), duration);
}

export const toast = {
  success: (msg: string, dur = 4000) => add(msg, "success", dur),
  error: (msg: string, dur = 6000) => add(msg, "error", dur),
  info: (msg: string, dur = 4000) => add(msg, "info", dur),
  warning: (msg: string, dur = 5000) => add(msg, "warning", dur),
};
