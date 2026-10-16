import { createApp } from './app';
import { createPrisma } from './db';
import { env } from './env';

createApp({ db: createPrisma() }).listen(env.PORT, () => {
  console.log(`HealthBridge API on http://localhost:${env.PORT}`);
});
