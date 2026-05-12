import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddDriverProfileAndBookingAssignment1760000005000 implements MigrationInterface {
  name = 'AddDriverProfileAndBookingAssignment1760000005000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "users"
      ADD COLUMN "driver_profile_completed" boolean NOT NULL DEFAULT false,
      ADD COLUMN "driver_profile_photo_base64" text,
      ADD COLUMN "driver_address" character varying(500),
      ADD COLUMN "driver_location_text" character varying(160),
      ADD COLUMN "driver_age" integer,
      ADD COLUMN "driver_gender" character varying(32),
      ADD COLUMN "driver_visa_status" character varying(120),
      ADD COLUMN "driver_dl_image_base64" text
    `);
    await queryRunner.query(`
      ALTER TABLE "ride_bookings"
      ADD COLUMN "driver_id" uuid,
      ADD COLUMN "accepted_at" TIMESTAMP WITH TIME ZONE
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_ride_bookings_driver_created"
      ON "ride_bookings" ("driver_id", "created_at")
    `);
    await queryRunner.query(`
      ALTER TABLE "ride_bookings"
      ADD CONSTRAINT "FK_ride_bookings_driver"
      FOREIGN KEY ("driver_id") REFERENCES "users"("id")
      ON DELETE SET NULL ON UPDATE NO ACTION
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "ride_bookings" DROP CONSTRAINT "FK_ride_bookings_driver"
    `);
    await queryRunner.query(`
      DROP INDEX "IDX_ride_bookings_driver_created"
    `);
    await queryRunner.query(`
      ALTER TABLE "ride_bookings"
      DROP COLUMN "accepted_at",
      DROP COLUMN "driver_id"
    `);
    await queryRunner.query(`
      ALTER TABLE "users"
      DROP COLUMN "driver_dl_image_base64",
      DROP COLUMN "driver_visa_status",
      DROP COLUMN "driver_gender",
      DROP COLUMN "driver_age",
      DROP COLUMN "driver_location_text",
      DROP COLUMN "driver_address",
      DROP COLUMN "driver_profile_photo_base64",
      DROP COLUMN "driver_profile_completed"
    `);
  }
}
