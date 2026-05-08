import { messagePrefix, action as Action } from "../../lib/Constants.gen";
import type { containerColor, containerIcon } from "../../lib/Constants.gen";

export { Action };

interface MessageResponse<T = unknown> {
  ok: boolean;
  data?: T;
  error?: { code: string; message: string };
}

export async function sendMessage<T = unknown>(
  action: string,
  payload?: unknown,
): Promise<T> {
  const response = (await browser.runtime.sendMessage({
    type: `${messagePrefix}${action}`,
    payload,
  })) as MessageResponse<T>;

  if (!response.ok) {
    throw new Error(`${response.error!.code}: ${response.error!.message}`);
  }
  return response.data!;
}

export interface ContainerData {
  cookieStoreId: string;
  name: string;
  color: containerColor;
  icon: containerIcon;
  resolvedName: string;
}

export interface ReconcileResultData {
  created: string[];
  updated: string[];
  removed: string[];
  reordered: boolean;
  extras: string[];
}

export function shortId(id: string): string {
  const match = id.match(/firefox-container-(\d+)/);
  return match ? `ct-${match[1]}` : id;
}

export function formatReconcileResult(result: ReconcileResultData): string {
  const parts: string[] = [];
  if (result.created.length) parts.push(`${result.created.length} created`);
  if (result.updated.length) parts.push(`${result.updated.length} updated`);
  if (result.removed.length) parts.push(`${result.removed.length} removed`);
  return parts.length ? parts.join(", ") : "No changes";
}
