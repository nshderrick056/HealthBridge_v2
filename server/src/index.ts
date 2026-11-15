import { createApp } from './app';
import { env } from './env';
import { createFirebase } from './firebase';
import { africasTalking } from './sms/gateway';

createApp({ fb: createFirebase(), sender: africasTalking() }).listen(env.PORT, () => {
  console.log(`HealthBridge API on http://localhost:${env.PORT}`);
});
