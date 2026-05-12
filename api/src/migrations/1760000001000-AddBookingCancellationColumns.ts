import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddBookingCancellationColumns1760000001000 implements MigrationInterface {
  name = 'AddBookingCancellationColumns1760000001000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "ride_bookings"
      ADD COLUMN "cancelled_at" TIMESTAMP WITH TIME ZONE
    `);
    await queryRunner.query(`
      ALTER TABLE "ride_bookings"
      ADD COLUMN "cancel_reason_code" character varying(40)
    `);
    await queryRunner.query(`
      ALTER TABLE "ride_bookings"
      ADD COLUMN "cancel_reason_note" character varying(280)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "ride_bookings" DROP COLUMN "cancel_reason_note"
    `);
    await queryRunner.query(`
      ALTER TABLE "ride_bookings" DROP COLUMN "cancel_reason_code"
    `);
    await queryRunner.query(`
      ALTER TABLE "ride_bookings" DROP COLUMN "cancelled_at"
    `);
  }
}
