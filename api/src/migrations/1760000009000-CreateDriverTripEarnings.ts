import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateDriverTripEarnings1760000009000
  implements MigrationInterface
{
  name = 'CreateDriverTripEarnings1760000009000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "driver_trip_earnings" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "driver_id" uuid NOT NULL,
        "booking_id" uuid NOT NULL,
        "payment_attempt_id" uuid,
        "gross_amount_minor" integer NOT NULL,
        "platform_fee_minor" integer NOT NULL,
        "driver_amount_minor" integer NOT NULL,
        "driver_share_bps" integer NOT NULL,
        "currency_code" character varying(8) NOT NULL,
        "calculated_at" TIMESTAMP WITH TIME ZONE NOT NULL,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_driver_trip_earnings_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_driver_trip_earnings_booking_id" UNIQUE ("booking_id"),
        CONSTRAINT "FK_driver_trip_earnings_driver_id" FOREIGN KEY ("driver_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE NO ACTION,
        CONSTRAINT "FK_driver_trip_earnings_booking_id" FOREIGN KEY ("booking_id") REFERENCES "ride_bookings"("id") ON DELETE RESTRICT ON UPDATE NO ACTION,
        CONSTRAINT "FK_driver_trip_earnings_payment_attempt_id" FOREIGN KEY ("payment_attempt_id") REFERENCES "payment_attempts"("id") ON DELETE SET NULL ON UPDATE NO ACTION
      )
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_driver_trip_earnings_driver_created" ON "driver_trip_earnings" ("driver_id", "created_at")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX "public"."IDX_driver_trip_earnings_driver_created"`,
    );
    await queryRunner.query(`DROP TABLE "driver_trip_earnings"`);
  }
}
