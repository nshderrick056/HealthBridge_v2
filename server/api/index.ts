// Vercel entry: the whole Express app as one serverless function; vercel.json routes every path here.
// Env vars (FIREBASE_SERVICE_ACCOUNT, JWT_SECRET, SMS_*, AT_*) are set in the Vercel project.
import { createApp } from '../src/app';
import { createFirebase } from '../src/firebase';
import { africasTalking } from '../src/sms/gateway';

export default createApp({ fb: createFirebase(), sender: africasTalking() });
