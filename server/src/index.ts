import { createApp } from './app';
import { createPrisma } from './db';
import { env } from './env';
import { africasTalking } from './sms/gateway';

createApp({ db: createPrisma(), sender: africasTalking() }).listen(env.PORT, () => {
  console.log(`HealthBridge API on http://localhost:${env.PORT}`);
});
