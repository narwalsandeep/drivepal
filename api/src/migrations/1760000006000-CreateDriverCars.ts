import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateDriverCars1760000006000 implements MigrationInterface {
  name = 'CreateDriverCars1760000006000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "driver_cars" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "driver_id" uuid NOT NULL,
        "display_name" character varying(50) NOT NULL,
        "manufacturer" character varying(60) NOT NULL,
        "model" character varying(60) NOT NULL,
        "color" character varying(40) NOT NULL,
        "plate_number" character varying(24) NOT NULL,
        "plate_normalized" character varying(24) NOT NULL,
        "seat_capacity" integer NOT NULL,
        "price_per_km_gbp" double precision NOT NULL,
        "ride_class" character varying(24) NOT NULL,
        "transmission" character varying(24) NOT NULL,
        "is_active" boolean NOT NULL DEFAULT true,
        "accepts_pets" boolean NOT NULL DEFAULT false,
        "has_air_conditioning" boolean NOT NULL DEFAULT true,
        "has_child_seat" boolean NOT NULL DEFAULT false,
        "wheelchair_accessible" boolean NOT NULL DEFAULT false,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_driver_cars_id" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_driver_cars_driver_created"
      ON "driver_cars" ("driver_id", "created_at")
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "IDX_driver_cars_driver_plate"
      ON "driver_cars" ("driver_id", "plate_normalized")
    `);
    await queryRunner.query(`
      ALTER TABLE "driver_cars"
      ADD CONSTRAINT "FK_driver_cars_driver"
      FOREIGN KEY ("driver_id") REFERENCES "users"("id")
      ON DELETE CASCADE ON UPDATE NO ACTION
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "driver_cars" DROP CONSTRAINT "FK_driver_cars_driver"
    `);
    await queryRunner.query(`
      DROP INDEX "IDX_driver_cars_driver_plate"
    `);
    await queryRunner.query(`
      DROP INDEX "IDX_driver_cars_driver_created"
    `);
    await queryRunner.query(`
      DROP TABLE "driver_cars"
    `);
  }
}
