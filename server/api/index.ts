// Vercel entry: the whole Express app as one serverless function; vercel.json routes every path here.
// Env vars (DATABASE_URL = Neon pooled URL, JWT_*, SMS_*, AT_*) are set in the Vercel project.
import { createApp } from '../src/app';
import { createPrisma } from '../src/db';
import { africasTalking } from '../src/sms/gateway';

export default createApp({ db: createPrisma(), sender: africasTalking() });
