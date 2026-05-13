import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateRideBookingDriverLocations1760000011000 implements MigrationInterface {
  name = 'CreateRideBookingDriverLocations1760000011000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "ride_booking_driver_locations" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "booking_id" uuid NOT NULL,
        "driver_id" uuid NOT NULL,
        "latitude" double precision NOT NULL,
        "longitude" double precision NOT NULL,
        "accuracy_meters" double precision,
        "recorded_at" TIMESTAMP WITH TIME ZONE NOT NULL,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_ride_booking_driver_locations_id" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "IDX_ride_booking_driver_locations_booking_id"
      ON "ride_booking_driver_locations" ("booking_id")
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_ride_booking_driver_locations_driver_id_updated_at"
      ON "ride_booking_driver_locations" ("driver_id", "updated_at")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX "public"."IDX_ride_booking_driver_locations_driver_id_updated_at"
    `);
    await queryRunner.query(`
      DROP INDEX "public"."IDX_ride_booking_driver_locations_booking_id"
    `);
    await queryRunner.query(`
      DROP TABLE "ride_booking_driver_locations"
    `);
  }
}
