import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreatePaymentCards1760000002000 implements MigrationInterface {
  name = 'CreatePaymentCards1760000002000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "users"
      ADD COLUMN "stripe_customer_id" character varying(255)
    `);
    await queryRunner.query(`
      CREATE TABLE "payment_cards" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "stripe_payment_method_id" character varying(255) NOT NULL,
        "brand" character varying(40) NOT NULL,
        "last4" character varying(8) NOT NULL,
        "exp_month" integer NOT NULL,
        "exp_year" integer NOT NULL,
        "funding" character varying(40),
        "country" character varying(8),
        "is_default" boolean NOT NULL DEFAULT false,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_payment_cards_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_payment_cards_stripe_payment_method_id" UNIQUE ("stripe_payment_method_id"),
        CONSTRAINT "FK_payment_cards_user_id" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      )
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_payment_cards_user_default" ON "payment_cards" ("user_id", "is_default")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX "public"."IDX_payment_cards_user_default"
    `);
    await queryRunner.query(`
      DROP TABLE "payment_cards"
    `);
    await queryRunner.query(`
      ALTER TABLE "users" DROP COLUMN "stripe_customer_id"
    `);
  }
}
