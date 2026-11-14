-- A CHW can archive a patient (the app's "delete"); health records are kept, never deleted.
ALTER TABLE "patients" ADD COLUMN "archived_at" TIMESTAMPTZ(6);
