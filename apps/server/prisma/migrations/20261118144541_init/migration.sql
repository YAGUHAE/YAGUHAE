-- CreateEnum
CREATE TYPE "user_role" AS ENUM ('PLAYER', 'HOST', 'ADMIN');

-- CreateEnum
CREATE TYPE "phone_source" AS ENUM ('KAKAO', 'MANUAL');

-- CreateEnum
CREATE TYPE "position" AS ENUM ('SP', 'RP', 'C', 'FIRST_BASE', 'SECOND_BASE', 'THIRD_BASE', 'SS', 'LF', 'CF', 'RF', 'DH');

-- CreateEnum
CREATE TYPE "team_side" AS ENUM ('FIRST', 'SECOND');

-- CreateEnum
CREATE TYPE "grade" AS ENUM ('DIV_1', 'DIV_2', 'DIV_3', 'DIV_4', 'ROOKIE');

-- CreateEnum
CREATE TYPE "review_status" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- CreateEnum
CREATE TYPE "game_status" AS ENUM ('SCHEDULED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "game_cancel_reason" AS ENUM ('RAIN', 'STADIUM', 'LACK_OF_PLAYERS', 'OTHER');

-- CreateEnum
CREATE TYPE "reservation_status" AS ENUM ('RESERVED', 'PAYMENT_SUBMITTED', 'APPROVED', 'EXPIRED', 'CANCELLED', 'REJECTED', 'GAME_CANCELLED', 'ATTENDED', 'NO_SHOW');

-- CreateEnum
CREATE TYPE "expire_reason" AS ENUM ('PAYMENT_TIMEOUT', 'APPROVAL_TIMEOUT');

-- CreateEnum
CREATE TYPE "user_review_reason" AS ENUM ('NO_SHOW_THRESHOLD');

-- CreateEnum
CREATE TYPE "user_review_status" AS ENUM ('PENDING', 'SUSPENDED', 'DISMISSED');

-- CreateEnum
CREATE TYPE "suspension_source" AS ENUM ('NO_SHOW_REVIEW', 'REPORT', 'ADMIN');

-- CreateEnum
CREATE TYPE "report_reason" AS ENUM ('BAD_MANNER', 'ABUSE', 'FALSE_INFO', 'FRAUD', 'OTHER');

-- CreateEnum
CREATE TYPE "report_status" AS ENUM ('PENDING', 'WARNED', 'SUSPENDED', 'DISMISSED');

-- CreateEnum
CREATE TYPE "appeal_type" AS ENUM ('NO_SHOW', 'EVALUATION');

-- CreateEnum
CREATE TYPE "appeal_status" AS ENUM ('PENDING', 'ACCEPTED', 'REJECTED');

-- CreateEnum
CREATE TYPE "notification_type" AS ENUM ('PAYMENT_DEADLINE_12H', 'PAYMENT_DEADLINE_1H', 'RESERVATION_APPROVED', 'RESERVATION_REJECTED', 'RESERVATION_EXPIRED', 'APPROVAL_REMINDER', 'RESERVATION_CANCELLED', 'GAME_CANCELLED', 'ATTENDANCE_REMINDER', 'EVALUATION_OPENED', 'REPORT_RESOLVED');

-- CreateEnum
CREATE TYPE "notification_status" AS ENUM ('PENDING', 'SENT', 'FAILED', 'SKIPPED');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "kakao_id" TEXT NOT NULL,
    "roles" "user_role"[] DEFAULT ARRAY['PLAYER']::"user_role"[],
    "phone" TEXT,
    "phone_source" "phone_source",
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "player_profiles" (
    "user_id" UUID NOT NULL,
    "nickname" TEXT NOT NULL,
    "region_code" CHAR(5) NOT NULL,
    "main_position" "position" NOT NULL,
    "sub_positions" "position"[] DEFAULT ARRAY[]::"position"[],
    "grade" "grade" NOT NULL,
    "is_former_pro" BOOLEAN NOT NULL DEFAULT false,
    "gameone_url" TEXT,
    "uniqueplay_url" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "player_profiles_pkey" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE "host_applications" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "contact_phone" TEXT NOT NULL,
    "leagues_note" TEXT NOT NULL,
    "status" "review_status" NOT NULL DEFAULT 'PENDING',
    "reviewed_by" UUID,
    "reviewed_at" TIMESTAMPTZ,
    "reject_reason" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "host_applications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "host_profiles" (
    "user_id" UUID NOT NULL,
    "bank_name" TEXT NOT NULL,
    "account_number" TEXT NOT NULL,
    "account_holder" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "host_profiles_pkey" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE "user_reviews" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "reason" "user_review_reason" NOT NULL,
    "status" "user_review_status" NOT NULL DEFAULT 'PENDING',
    "decided_by" UUID,
    "decided_at" TIMESTAMPTZ,
    "note" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "user_reviews_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_suspensions" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "source" "suspension_source" NOT NULL,
    "user_review_id" UUID,
    "report_id" UUID,
    "reason" TEXT NOT NULL,
    "starts_at" TIMESTAMPTZ NOT NULL,
    "ends_at" TIMESTAMPTZ,
    "lifted_at" TIMESTAMPTZ,
    "created_by" UUID NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "user_suspensions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "regions" (
    "code" CHAR(5) NOT NULL,
    "sido" TEXT NOT NULL,
    "sigungu" TEXT NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "regions_pkey" PRIMARY KEY ("code")
);

-- CreateTable
CREATE TABLE "leagues" (
    "id" UUID NOT NULL,
    "region_code" CHAR(5) NOT NULL,
    "name" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "leagues_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "stadiums" (
    "id" UUID NOT NULL,
    "league_id" UUID NOT NULL,
    "region_code" CHAR(5) NOT NULL,
    "name" TEXT NOT NULL,
    "address" TEXT,
    "status" "review_status" NOT NULL,
    "requested_by" UUID,
    "reviewed_by" UUID,
    "reviewed_at" TIMESTAMPTZ,
    "reject_reason" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "stadiums_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "games" (
    "id" UUID NOT NULL,
    "host_id" UUID NOT NULL,
    "stadium_id" UUID NOT NULL,
    "series_id" UUID,
    "series_no" SMALLINT,
    "starts_at" TIMESTAMPTZ NOT NULL,
    "ends_at" TIMESTAMPTZ NOT NULL,
    "fee" INTEGER NOT NULL,
    "allowed_grades" "grade"[],
    "allows_former_pro" BOOLEAN NOT NULL DEFAULT true,
    "notice" TEXT,
    "bank_name" TEXT NOT NULL,
    "account_number" TEXT NOT NULL,
    "account_holder" TEXT NOT NULL,
    "status" "game_status" NOT NULL DEFAULT 'SCHEDULED',
    "bumped_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "cancel_reason" "game_cancel_reason",
    "cancel_reason_detail" TEXT,
    "cancelled_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "games_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "game_slots" (
    "id" UUID NOT NULL,
    "game_id" UUID NOT NULL,
    "side" "team_side" NOT NULL,
    "position" "position" NOT NULL,
    "closed_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "game_slots_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reservations" (
    "id" UUID NOT NULL,
    "game_id" UUID NOT NULL,
    "game_slot_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "status" "reservation_status" NOT NULL DEFAULT 'RESERVED',
    "depositor_name" TEXT NOT NULL,
    "reserved_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "payment_deadline_at" TIMESTAMPTZ NOT NULL,
    "payment_submitted_at" TIMESTAMPTZ,
    "approved_at" TIMESTAMPTZ,
    "rejected_at" TIMESTAMPTZ,
    "cancelled_at" TIMESTAMPTZ,
    "cancel_reason" TEXT,
    "expired_at" TIMESTAMPTZ,
    "expire_reason" "expire_reason",
    "attendance_marked_at" TIMESTAMPTZ,
    "attendance_auto" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "reservations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "evaluations" (
    "id" UUID NOT NULL,
    "game_id" UUID NOT NULL,
    "evaluator_id" UUID NOT NULL,
    "target_id" UUID NOT NULL,
    "manner" SMALLINT NOT NULL,
    "skill_match" SMALLINT NOT NULL,
    "punctuality" SMALLINT NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "evaluations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "best_player_votes" (
    "game_id" UUID NOT NULL,
    "voter_id" UUID NOT NULL,
    "target_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "best_player_votes_pkey" PRIMARY KEY ("game_id","voter_id")
);

-- CreateTable
CREATE TABLE "reports" (
    "id" UUID NOT NULL,
    "reporter_id" UUID NOT NULL,
    "target_user_id" UUID NOT NULL,
    "game_id" UUID NOT NULL,
    "reason" "report_reason" NOT NULL,
    "detail" TEXT,
    "status" "report_status" NOT NULL DEFAULT 'PENDING',
    "handled_by" UUID,
    "handled_at" TIMESTAMPTZ,
    "handle_note" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "reports_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "appeals" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "type" "appeal_type" NOT NULL,
    "reservation_id" UUID,
    "evaluation_id" UUID,
    "reason" TEXT NOT NULL,
    "status" "appeal_status" NOT NULL DEFAULT 'PENDING',
    "handled_by" UUID,
    "handled_at" TIMESTAMPTZ,
    "handle_note" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "appeals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "type" "notification_type" NOT NULL,
    "dedupe_key" TEXT NOT NULL,
    "reservation_id" UUID,
    "game_id" UUID,
    "payload" JSONB NOT NULL DEFAULT '{}',
    "status" "notification_status" NOT NULL DEFAULT 'PENDING',
    "sent_at" TIMESTAMPTZ,
    "error" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_kakao_id_key" ON "users"("kakao_id");

-- CreateIndex
CREATE UNIQUE INDEX "player_profiles_nickname_key" ON "player_profiles"("nickname");

-- CreateIndex
CREATE INDEX "player_profiles_region_code_idx" ON "player_profiles"("region_code");

-- CreateIndex
CREATE INDEX "host_applications_user_id_idx" ON "host_applications"("user_id");

-- CreateIndex
CREATE INDEX "host_applications_status_idx" ON "host_applications"("status");

-- CreateIndex
CREATE INDEX "user_reviews_user_id_idx" ON "user_reviews"("user_id");

-- CreateIndex
CREATE INDEX "user_reviews_status_idx" ON "user_reviews"("status");

-- CreateIndex
CREATE INDEX "user_suspensions_user_id_idx" ON "user_suspensions"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "leagues_region_code_name_key" ON "leagues"("region_code", "name");

-- CreateIndex
CREATE INDEX "stadiums_region_code_idx" ON "stadiums"("region_code");

-- CreateIndex
CREATE INDEX "stadiums_status_idx" ON "stadiums"("status");

-- CreateIndex
CREATE UNIQUE INDEX "stadiums_league_id_name_key" ON "stadiums"("league_id", "name");

-- CreateIndex
CREATE INDEX "games_bumped_at_idx" ON "games"("bumped_at");

-- CreateIndex
CREATE INDEX "games_starts_at_idx" ON "games"("starts_at");

-- CreateIndex
CREATE INDEX "games_stadium_id_starts_at_idx" ON "games"("stadium_id", "starts_at");

-- CreateIndex
CREATE INDEX "games_host_id_starts_at_idx" ON "games"("host_id", "starts_at");

-- CreateIndex
CREATE UNIQUE INDEX "games_series_id_series_no_key" ON "games"("series_id", "series_no");

-- CreateIndex
CREATE UNIQUE INDEX "game_slots_game_id_side_position_key" ON "game_slots"("game_id", "side", "position");

-- CreateIndex
CREATE UNIQUE INDEX "game_slots_id_game_id_key" ON "game_slots"("id", "game_id");

-- CreateIndex
CREATE INDEX "reservations_game_slot_id_idx" ON "reservations"("game_slot_id");

-- CreateIndex
CREATE INDEX "reservations_user_id_status_idx" ON "reservations"("user_id", "status");

-- CreateIndex
CREATE INDEX "reservations_game_id_status_idx" ON "reservations"("game_id", "status");

-- CreateIndex
CREATE INDEX "evaluations_target_id_idx" ON "evaluations"("target_id");

-- CreateIndex
CREATE UNIQUE INDEX "evaluations_game_id_evaluator_id_target_id_key" ON "evaluations"("game_id", "evaluator_id", "target_id");

-- CreateIndex
CREATE INDEX "best_player_votes_target_id_idx" ON "best_player_votes"("target_id");

-- CreateIndex
CREATE INDEX "reports_status_idx" ON "reports"("status");

-- CreateIndex
CREATE INDEX "reports_target_user_id_idx" ON "reports"("target_user_id");

-- CreateIndex
CREATE INDEX "appeals_status_idx" ON "appeals"("status");

-- CreateIndex
CREATE INDEX "appeals_user_id_idx" ON "appeals"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "notifications_dedupe_key_key" ON "notifications"("dedupe_key");

-- CreateIndex
CREATE INDEX "notifications_user_id_idx" ON "notifications"("user_id");

-- CreateIndex
CREATE INDEX "notifications_status_idx" ON "notifications"("status");

-- AddForeignKey
ALTER TABLE "player_profiles" ADD CONSTRAINT "player_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "player_profiles" ADD CONSTRAINT "player_profiles_region_code_fkey" FOREIGN KEY ("region_code") REFERENCES "regions"("code") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "host_applications" ADD CONSTRAINT "host_applications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "host_applications" ADD CONSTRAINT "host_applications_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "host_profiles" ADD CONSTRAINT "host_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_reviews" ADD CONSTRAINT "user_reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_reviews" ADD CONSTRAINT "user_reviews_decided_by_fkey" FOREIGN KEY ("decided_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_suspensions" ADD CONSTRAINT "user_suspensions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_suspensions" ADD CONSTRAINT "user_suspensions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_suspensions" ADD CONSTRAINT "user_suspensions_user_review_id_fkey" FOREIGN KEY ("user_review_id") REFERENCES "user_reviews"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_suspensions" ADD CONSTRAINT "user_suspensions_report_id_fkey" FOREIGN KEY ("report_id") REFERENCES "reports"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "leagues" ADD CONSTRAINT "leagues_region_code_fkey" FOREIGN KEY ("region_code") REFERENCES "regions"("code") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stadiums" ADD CONSTRAINT "stadiums_league_id_fkey" FOREIGN KEY ("league_id") REFERENCES "leagues"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stadiums" ADD CONSTRAINT "stadiums_region_code_fkey" FOREIGN KEY ("region_code") REFERENCES "regions"("code") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stadiums" ADD CONSTRAINT "stadiums_requested_by_fkey" FOREIGN KEY ("requested_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stadiums" ADD CONSTRAINT "stadiums_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "games" ADD CONSTRAINT "games_host_id_fkey" FOREIGN KEY ("host_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "games" ADD CONSTRAINT "games_stadium_id_fkey" FOREIGN KEY ("stadium_id") REFERENCES "stadiums"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "game_slots" ADD CONSTRAINT "game_slots_game_id_fkey" FOREIGN KEY ("game_id") REFERENCES "games"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reservations" ADD CONSTRAINT "reservations_game_id_fkey" FOREIGN KEY ("game_id") REFERENCES "games"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reservations" ADD CONSTRAINT "reservations_game_slot_id_game_id_fkey" FOREIGN KEY ("game_slot_id", "game_id") REFERENCES "game_slots"("id", "game_id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reservations" ADD CONSTRAINT "reservations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "evaluations" ADD CONSTRAINT "evaluations_game_id_fkey" FOREIGN KEY ("game_id") REFERENCES "games"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "evaluations" ADD CONSTRAINT "evaluations_evaluator_id_fkey" FOREIGN KEY ("evaluator_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "evaluations" ADD CONSTRAINT "evaluations_target_id_fkey" FOREIGN KEY ("target_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "best_player_votes" ADD CONSTRAINT "best_player_votes_game_id_fkey" FOREIGN KEY ("game_id") REFERENCES "games"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "best_player_votes" ADD CONSTRAINT "best_player_votes_voter_id_fkey" FOREIGN KEY ("voter_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "best_player_votes" ADD CONSTRAINT "best_player_votes_target_id_fkey" FOREIGN KEY ("target_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_reporter_id_fkey" FOREIGN KEY ("reporter_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_target_user_id_fkey" FOREIGN KEY ("target_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_handled_by_fkey" FOREIGN KEY ("handled_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_game_id_fkey" FOREIGN KEY ("game_id") REFERENCES "games"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "appeals" ADD CONSTRAINT "appeals_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "appeals" ADD CONSTRAINT "appeals_handled_by_fkey" FOREIGN KEY ("handled_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "appeals" ADD CONSTRAINT "appeals_reservation_id_fkey" FOREIGN KEY ("reservation_id") REFERENCES "reservations"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "appeals" ADD CONSTRAINT "appeals_evaluation_id_fkey" FOREIGN KEY ("evaluation_id") REFERENCES "evaluations"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_reservation_id_fkey" FOREIGN KEY ("reservation_id") REFERENCES "reservations"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_game_id_fkey" FOREIGN KEY ("game_id") REFERENCES "games"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- ═══════════════════════════════════════════════════════════════════════
-- Prisma 스키마 밖의 제약 (docs/design/erd.md 7장)
-- schema.prisma 로 표현할 수 없어 직접 작성한다. 바꿀 때는 새 마이그레이션으로.
-- ═══════════════════════════════════════════════════════════════════════

-- 배열 컬럼: Prisma 는 NULL 허용으로 만든다. 빈 배열만 허용한다.
ALTER TABLE "users" ALTER COLUMN "roles" SET NOT NULL;
ALTER TABLE "player_profiles" ALTER COLUMN "sub_positions" SET NOT NULL;
ALTER TABLE "games" ALTER COLUMN "allowed_grades" SET NOT NULL;

-- ─── 부분 unique ───────────────────────────────────────────────────────
-- 자리 1개에 활성 예약 1개 (P0-3: 마지막 자리 동시 예약에서 1명만 성공)
CREATE UNIQUE INDEX "reservations_active_slot_key" ON "reservations" ("game_slot_id")
  WHERE "status" IN ('RESERVED', 'PAYMENT_SUBMITTED', 'APPROVED');
-- 같은 경기 활성 예약 1개 (P0-3)
CREATE UNIQUE INDEX "reservations_active_game_user_key" ON "reservations" ("game_id", "user_id")
  WHERE "status" IN ('RESERVED', 'PAYMENT_SUBMITTED', 'APPROVED');
CREATE UNIQUE INDEX "host_applications_pending_user_key" ON "host_applications" ("user_id")
  WHERE "status" = 'PENDING';
CREATE UNIQUE INDEX "user_reviews_pending_user_key" ON "user_reviews" ("user_id")
  WHERE "status" = 'PENDING';
CREATE UNIQUE INDEX "appeals_pending_reservation_key" ON "appeals" ("reservation_id")
  WHERE "status" = 'PENDING' AND "reservation_id" IS NOT NULL;
CREATE UNIQUE INDEX "appeals_pending_evaluation_key" ON "appeals" ("evaluation_id")
  WHERE "status" = 'PENDING' AND "evaluation_id" IS NOT NULL;

-- ─── 부분 인덱스 ───────────────────────────────────────────────────────
-- 입금 기한 만료 Cron
CREATE INDEX "reservations_payment_deadline_idx" ON "reservations" ("payment_deadline_at")
  WHERE "status" = 'RESERVED';

-- ─── check ─────────────────────────────────────────────────────────────
ALTER TABLE "users" ADD CONSTRAINT "users_phone_source_check"
  CHECK (("phone" IS NULL) = ("phone_source" IS NULL));

ALTER TABLE "player_profiles" ADD CONSTRAINT "player_profiles_sub_positions_check"
  CHECK (cardinality("sub_positions") <= 2 AND NOT ("main_position" = ANY ("sub_positions")));

ALTER TABLE "games" ADD CONSTRAINT "games_duration_check"
  CHECK ("ends_at" - "starts_at" BETWEEN interval '2 hours' AND interval '3 hours'
    AND extract(epoch FROM "ends_at" - "starts_at")::integer % 600 = 0);
ALTER TABLE "games" ADD CONSTRAINT "games_fee_check"
  CHECK ("fee" BETWEEN 0 AND 100000 AND "fee" % 1000 = 0);
ALTER TABLE "games" ADD CONSTRAINT "games_allowed_grades_check"
  CHECK (cardinality("allowed_grades") >= 1);
ALTER TABLE "games" ADD CONSTRAINT "games_notice_check"
  CHECK ("notice" IS NULL OR char_length("notice") <= 500);
ALTER TABLE "games" ADD CONSTRAINT "games_series_check"
  CHECK (("series_id" IS NULL) = ("series_no" IS NULL) AND ("series_no" IS NULL OR "series_no" >= 1));
ALTER TABLE "games" ADD CONSTRAINT "games_cancel_check"
  CHECK (
    ("status" = 'CANCELLED') = ("cancel_reason" IS NOT NULL AND "cancelled_at" IS NOT NULL)
    AND ("cancel_reason" IS DISTINCT FROM 'OTHER' OR "cancel_reason_detail" IS NOT NULL)
  );

ALTER TABLE "reservations" ADD CONSTRAINT "reservations_depositor_name_check"
  CHECK (char_length("depositor_name") BETWEEN 2 AND 20);
ALTER TABLE "reservations" ADD CONSTRAINT "reservations_expire_check"
  CHECK (("status" = 'EXPIRED') = ("expire_reason" IS NOT NULL));

ALTER TABLE "evaluations" ADD CONSTRAINT "evaluations_scores_check"
  CHECK ("manner" BETWEEN 1 AND 5 AND "skill_match" BETWEEN 1 AND 5 AND "punctuality" BETWEEN 1 AND 5);
ALTER TABLE "evaluations" ADD CONSTRAINT "evaluations_not_self_check"
  CHECK ("evaluator_id" <> "target_id");

ALTER TABLE "best_player_votes" ADD CONSTRAINT "best_player_votes_not_self_check"
  CHECK ("voter_id" <> "target_id");

ALTER TABLE "reports" ADD CONSTRAINT "reports_not_self_check"
  CHECK ("reporter_id" <> "target_user_id");

ALTER TABLE "appeals" ADD CONSTRAINT "appeals_target_check"
  CHECK (
    ("type" = 'NO_SHOW' AND "reservation_id" IS NOT NULL AND "evaluation_id" IS NULL)
    OR ("type" = 'EVALUATION' AND "evaluation_id" IS NOT NULL AND "reservation_id" IS NULL)
  );
