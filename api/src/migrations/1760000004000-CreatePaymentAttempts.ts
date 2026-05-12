import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreatePaymentAttempts1760000004000 implements MigrationInterface {
  name = 'CreatePaymentAttempts1760000004000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TYPE "public"."payment_attempts_status_enum" AS ENUM('pending', 'succeeded', 'failed', 'refunded')
    `);
    await queryRunner.query(`
      CREATE TABLE "payment_attempts" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "booking_id" uuid,
        "payment_card_id" uuid,
        "stripe_payment_method_id" character varying(255),
        "stripe_payment_intent_id" character varying(255),
        "amount_minor" integer NOT NULL,
        "currency_code" character varying(8) NOT NULL,
        "captured_amount_minor" integer,
        "status" "public"."payment_attempts_status_enum" NOT NULL DEFAULT 'pending',
        "error_code" character varying(80),
        "error_message" character varying(500),
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_payment_attempts_id" PRIMARY KEY ("id"),
        CONSTRAINT "FK_payment_attempts_user_id" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE NO ACTION,
        CONSTRAINT "FK_payment_attempts_booking_id" FOREIGN KEY ("booking_id") REFERENCES "ride_bookings"("id") ON DELETE SET NULL ON UPDATE NO ACTION,
        CONSTRAINT "FK_payment_attempts_card_id" FOREIGN KEY ("payment_card_id") REFERENCES "payment_cards"("id") ON DELETE SET NULL ON UPDATE NO ACTION
      )
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_payment_attempts_user_created" ON "payment_attempts" ("user_id", "created_at")
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_payment_attempts_booking_id" ON "payment_attempts" ("booking_id")
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_payment_attempts_status_created" ON "payment_attempts" ("status", "created_at")
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_payment_attempts_intent_id" ON "payment_attempts" ("stripe_payment_intent_id")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX "public"."IDX_payment_attempts_intent_id"`,
    );
    await queryRunner.query(
      `DROP INDEX "public"."IDX_payment_attempts_status_created"`,
    );
    await queryRunner.query(
      `DROP INDEX "public"."IDX_payment_attempts_booking_id"`,
    );
    await queryRunner.query(
      `DROP INDEX "public"."IDX_payment_attempts_user_created"`,
    );
    await queryRunner.query(`DROP TABLE "payment_attempts"`);
    await queryRunner.query(
      `DROP TYPE "public"."payment_attempts_status_enum"`,
    );
  }
}
