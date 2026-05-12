import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddScheduledRides1760000008000 implements MigrationInterface {
  name = 'AddScheduledRides1760000008000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "ride_bookings" ADD COLUMN "scheduled_for" TIMESTAMPTZ`,
    );
    await queryRunner.query(
      `ALTER TABLE "ride_bookings" ADD COLUMN "scheduled_reminder_sent_at" TIMESTAMPTZ`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_ride_bookings_scheduled_for" ON "ride_bookings" ("scheduled_for")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX "public"."IDX_ride_bookings_scheduled_for"`,
    );
    await queryRunner.query(
      `ALTER TABLE "ride_bookings" DROP COLUMN "scheduled_reminder_sent_at"`,
    );
    await queryRunner.query(
      `ALTER TABLE "ride_bookings" DROP COLUMN "scheduled_for"`,
    );
  }
}
