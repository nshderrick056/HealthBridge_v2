-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "user_role" AS ENUM ('chw', 'supervisor', 'admin');

-- CreateEnum
CREATE TYPE "chw_role" AS ENUM ('asm', 'binome');

-- CreateEnum
CREATE TYPE "visit_type" AS ENUM ('maternal', 'child', 'malaria', 'nutrition');

-- CreateEnum
CREATE TYPE "alert_status" AS ENUM ('new', 'reviewed', 'escalated', 'follow_up', 'resolved');

-- CreateTable
CREATE TABLE "health_centers" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "district" TEXT NOT NULL,
    "sector" TEXT NOT NULL,
    "call_number" TEXT,

    CONSTRAINT "health_centers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "role" "user_role" NOT NULL,
    "chw_role" "chw_role",
    "full_name" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "email" TEXT,
    "secret_hash" TEXT NOT NULL,
    "health_center_id" UUID,
    "village" TEXT,
    "language" TEXT NOT NULL DEFAULT 'rw',
    "active" BOOLEAN NOT NULL DEFAULT true,
    "failed_logins" SMALLINT NOT NULL DEFAULT 0,
    "locked_until" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "devices" (
    "id" TEXT NOT NULL,
    "user_id" UUID NOT NULL,
    "sms_key" BYTEA NOT NULL,
    "sim_phone" TEXT,
    "build_flavor" TEXT NOT NULL DEFAULT 'store',
    "last_sync_at" TIMESTAMPTZ(6),
    "revoked_at" TIMESTAMPTZ(6),

    CONSTRAINT "devices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "patients" (
    "id" UUID NOT NULL,
    "short_id" TEXT NOT NULL,
    "chw_id" UUID NOT NULL,
    "full_name" TEXT NOT NULL,
    "sex" CHAR(1),
    "birth_date" DATE,
    "age_estimate" SMALLINT,
    "village" TEXT NOT NULL,
    "phone" TEXT,
    "consent_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "patients_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "visits" (
    "id" UUID NOT NULL,
    "short_code" TEXT NOT NULL,
    "patient_id" UUID NOT NULL,
    "chw_id" UUID NOT NULL,
    "device_id" TEXT NOT NULL,
    "type" "visit_type" NOT NULL,
    "answers" JSONB NOT NULL DEFAULT '{}',
    "notes" TEXT,
    "is_urgent" BOOLEAN NOT NULL DEFAULT false,
    "follow_up_on" DATE,
    "recorded_at" TIMESTAMPTZ(6) NOT NULL,
    "received_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "source" TEXT NOT NULL,
    "is_partial" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "visits_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "danger_signs" (
    "code" CHAR(2) NOT NULL,
    "visit_type" "visit_type" NOT NULL,
    "label_en" TEXT NOT NULL,
    "label_rw" TEXT NOT NULL,

    CONSTRAINT "danger_signs_pkey" PRIMARY KEY ("code")
);

-- CreateTable
CREATE TABLE "visit_danger_signs" (
    "visit_id" UUID NOT NULL,
    "code" CHAR(2) NOT NULL,

    CONSTRAINT "visit_danger_signs_pkey" PRIMARY KEY ("visit_id","code")
);

-- CreateTable
CREATE TABLE "alerts" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "visit_id" UUID NOT NULL,
    "health_center_id" UUID NOT NULL,
    "channel" TEXT NOT NULL,
    "status" "alert_status" NOT NULL DEFAULT 'new',
    "acked_to_chw_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "alerts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "alert_events" (
    "id" BIGSERIAL NOT NULL,
    "alert_id" UUID NOT NULL,
    "actor_id" UUID,
    "from_status" "alert_status",
    "to_status" "alert_status" NOT NULL,
    "note" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "alert_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sms_messages" (
    "id" BIGSERIAL NOT NULL,
    "direction" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "device_id" TEXT,
    "nonce" BYTEA,
    "raw_text" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "error" TEXT,
    "gateway_id" TEXT,
    "visit_id" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "sms_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_log" (
    "id" BIGSERIAL NOT NULL,
    "actor_id" UUID,
    "action" TEXT NOT NULL,
    "entity" TEXT NOT NULL,
    "entity_id" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_log_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_phone_key" ON "users"("phone");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "patients_short_id_key" ON "patients"("short_id");

-- CreateIndex
CREATE INDEX "patients_chw_id_village_idx" ON "patients"("chw_id", "village");

-- CreateIndex
CREATE INDEX "visits_chw_id_recorded_at_idx" ON "visits"("chw_id", "recorded_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "visits_device_id_short_code_key" ON "visits"("device_id", "short_code");

-- CreateIndex
CREATE UNIQUE INDEX "alerts_visit_id_key" ON "alerts"("visit_id");

-- CreateIndex
CREATE INDEX "alerts_health_center_id_status_created_at_idx" ON "alerts"("health_center_id", "status", "created_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "sms_messages_device_id_nonce_key" ON "sms_messages"("device_id", "nonce");

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_health_center_id_fkey" FOREIGN KEY ("health_center_id") REFERENCES "health_centers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "devices" ADD CONSTRAINT "devices_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "patients" ADD CONSTRAINT "patients_chw_id_fkey" FOREIGN KEY ("chw_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visits" ADD CONSTRAINT "visits_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "patients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visits" ADD CONSTRAINT "visits_chw_id_fkey" FOREIGN KEY ("chw_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visits" ADD CONSTRAINT "visits_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "devices"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visit_danger_signs" ADD CONSTRAINT "visit_danger_signs_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "visits"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visit_danger_signs" ADD CONSTRAINT "visit_danger_signs_code_fkey" FOREIGN KEY ("code") REFERENCES "danger_signs"("code") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "alerts" ADD CONSTRAINT "alerts_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "visits"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "alerts" ADD CONSTRAINT "alerts_health_center_id_fkey" FOREIGN KEY ("health_center_id") REFERENCES "health_centers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "alert_events" ADD CONSTRAINT "alert_events_alert_id_fkey" FOREIGN KEY ("alert_id") REFERENCES "alerts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "alert_events" ADD CONSTRAINT "alert_events_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sms_messages" ADD CONSTRAINT "sms_messages_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "devices"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sms_messages" ADD CONSTRAINT "sms_messages_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "visits"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_log" ADD CONSTRAINT "audit_log_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;


-- CHECK constraints from the Backend Schema spec (not expressible in Prisma)
ALTER TABLE "devices" ADD CONSTRAINT "devices_build_flavor_check" CHECK ("build_flavor" IN ('store', 'managed'));
ALTER TABLE "patients" ADD CONSTRAINT "patients_sex_check" CHECK ("sex" IN ('F', 'M'));
ALTER TABLE "visits" ADD CONSTRAINT "visits_source_check" CHECK ("source" IN ('sync', 'sms'));
ALTER TABLE "alerts" ADD CONSTRAINT "alerts_channel_check" CHECK ("channel" IN ('internet', 'sms'));
ALTER TABLE "sms_messages" ADD CONSTRAINT "sms_messages_direction_check" CHECK ("direction" IN ('in', 'out'));
