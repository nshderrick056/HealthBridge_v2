// FR-14: an urgent visit sent by SMS first reaches the server as a partial case (a stub patient, the signs
// and vitals only, under a server-made ID). Once the phone has uploaded the full visit, it calls this, and
// the partial case is folded into it: the alert, its history and the SMS log move to the full visit, and the
// partial visit and stub patient go. The supervisor sees one case, not two. Safe to call more than once.
import { Router } from 'express';
import { z } from 'zod';
import { audit } from '../accounts';
import type { Fb } from '../firebase';
import { HttpError } from '../http';
import { callerOf, requireRole, requireUser } from '../middleware/auth';
import { STUB_PATIENT_NAME } from '../sms/webhook';

export function visitsRouter(fb: Fb) {
  const router = Router();
  const { fs } = fb;

  router.post('/:id/merge-sms', requireUser(fb), requireRole('chw'), async (req, res) => {
    const { uid } = callerOf(res);
    const fullRef = fs.collection('visits').doc(z.uuid().parse(req.params.id));
    const full = (await fullRef.get()).data();
    if (!full || full.chwId !== uid) throw new HttpError(404, 'not_found');
    if (full.isPartial) throw new HttpError(409, 'not_a_full_visit');

    const partials = await fs
      .collection('visits')
      .where('deviceId', '==', full.deviceId)
      .where('shortCode', '==', full.shortCode)
      .where('isPartial', '==', true)
      .get();
    const partial = partials.docs.find((d) => d.id !== fullRef.id);
    if (!partial) return void res.json({ merged: false });

    const oldAlert = fs.collection('alerts').doc(partial.id);
    const newAlert = fs.collection('alerts').doc(fullRef.id);
    const [events, sms] = await Promise.all([
      oldAlert.collection('events').get(),
      fs.collection('smsMessages').where('visitId', '==', partial.id).get(),
    ]);
    const stubRef = fs.collection('patients').doc(partial.data().patientId);

    await fs.runTransaction(async (tx) => {
      const [oldSnap, newSnap, stub] = await Promise.all([tx.get(oldAlert), tx.get(newAlert), tx.get(stubRef)]);
      // The phone may have raised its own internet alert for the full visit: keep that, drop the SMS one.
      if (oldSnap.exists && !newSnap.exists) {
        tx.create(newAlert, { ...oldSnap.data(), visitId: fullRef.id });
        for (const e of events.docs) tx.create(newAlert.collection('events').doc(e.id), e.data());
      }
      for (const e of events.docs) tx.delete(e.ref);
      if (oldSnap.exists) tx.delete(oldAlert);
      for (const m of sms.docs) tx.update(m.ref, { visitId: fullRef.id });
      tx.delete(partial.ref);
      // The stub patient goes once nothing points at it (the full visit has the real patient).
      if (stub.exists && stub.data()!.fullName === STUB_PATIENT_NAME && stubRef.id !== full.patientId) {
        tx.delete(stubRef);
      }
    });
    await audit(fb, uid, 'visit.merge_sms', 'visits', fullRef.id);
    res.json({ merged: true });
  });

  return router;
}
