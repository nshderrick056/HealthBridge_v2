import { env } from '../env';

export type SmsSender = {
  /** Returns the gateway's message ID so delivery reports can be matched. */
  send(to: string, text: string): Promise<{ gatewayId: string | null }>;
};

// Africa's Talking REST API, called directly to avoid a dependency. Username "sandbox" uses the simulator.
export function africasTalking(): SmsSender {
  const { AT_USERNAME, AT_API_KEY, AT_SENDER } = env;
  return {
    async send(to, text) {
      if (!AT_USERNAME || !AT_API_KEY) throw new Error('Africa\'s Talking is not configured');
      const host = AT_USERNAME === 'sandbox' ? 'api.sandbox.africastalking.com' : 'api.africastalking.com';
      const form = new URLSearchParams({ username: AT_USERNAME, to, message: text });
      if (AT_SENDER) form.set('from', AT_SENDER);
      const res = await fetch(`https://${host}/version1/messaging`, {
        method: 'POST',
        headers: { apiKey: AT_API_KEY, Accept: 'application/json' },
        body: form,
        signal: AbortSignal.timeout(10_000),
      });
      const body = (await res.json()) as {
        SMSMessageData?: { Recipients?: { statusCode: number; messageId?: string }[] };
      };
      const r = body.SMSMessageData?.Recipients?.[0];
      // 100 processed, 101 sent, 102 queued
      if (!res.ok || !r || r.statusCode < 100 || r.statusCode > 102) {
        throw new Error(`gateway rejected message (${res.status})`);
      }
      return { gatewayId: r.messageId ?? null };
    },
  };
}
