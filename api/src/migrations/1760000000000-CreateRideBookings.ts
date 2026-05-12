import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateRideBookings1760000000000 implements MigrationInterface {
  name = 'CreateRideBookings1760000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`);
    await queryRunner.query(`
      CREATE TYPE "public"."ride_bookings_status_enum" AS ENUM (
        'requested',
        'accepted',
        'driver_arriving',
        'in_progress',
        'completed',
        'cancelled'
      )
    `);
    await queryRunner.query(`
      CREATE TABLE "ride_bookings" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "customer_id" uuid NOT NULL,
        "status" "public"."ride_bookings_status_enum" NOT NULL DEFAULT 'requested',
        "pickup_address" character varying(500) NOT NULL,
        "pickup_latitude" double precision NOT NULL,
        "pickup_longitude" double precision NOT NULL,
        "dropoff_address" character varying(500) NOT NULL,
        "dropoff_latitude" double precision NOT NULL,
        "dropoff_longitude" double precision NOT NULL,
        "route_distance_meters" integer,
        "route_duration_seconds" integer,
        "route_duration_in_traffic_seconds" integer,
        "car_type_id" character varying(80) NOT NULL,
        "car_type_title" character varying(120) NOT NULL,
        "car_seats" integer NOT NULL,
        "payment_method_id" character varying(120) NOT NULL,
        "payment_brand" character varying(40) NOT NULL,
        "payment_masked_number" character varying(40) NOT NULL,
        "requested_at" TIMESTAMP WITH TIME ZONE NOT NULL,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_ride_bookings_id" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_ride_bookings_customer_created"
      ON "ride_bookings" ("customer_id", "created_at")
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_ride_bookings_status_created"
      ON "ride_bookings" ("status", "created_at")
    `);
    await queryRunner.query(`
      ALTER TABLE "ride_bookings"
      ADD CONSTRAINT "FK_ride_bookings_customer"
      FOREIGN KEY ("customer_id") REFERENCES "users"("id")
      ON DELETE RESTRICT ON UPDATE NO ACTION
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "ride_bookings" DROP CONSTRAINT "FK_ride_bookings_customer"
    `);
    await queryRunner.query(`DROP INDEX "IDX_ride_bookings_status_created"`);
    await queryRunner.query(`DROP INDEX "IDX_ride_bookings_customer_created"`);
    await queryRunner.query(`DROP TABLE "ride_bookings"`);
    await queryRunner.query(`DROP TYPE "public"."ride_bookings_status_enum"`);
  }
}
