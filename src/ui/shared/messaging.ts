import { messagePrefix } from "../../lib/Constants.gen";

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
