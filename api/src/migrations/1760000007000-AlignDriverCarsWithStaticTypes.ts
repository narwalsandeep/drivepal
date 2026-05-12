import { MigrationInterface, QueryRunner } from 'typeorm';

export class AlignDriverCarsWithStaticTypes1760000007000 implements MigrationInterface {
  name = 'AlignDriverCarsWithStaticTypes1760000007000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "driver_cars"
      ADD COLUMN IF NOT EXISTS "car_type_id" character varying(24)
    `);
    await queryRunner.query(`
      UPDATE "driver_cars"
      SET "car_type_id" = CASE
        WHEN "ride_class" = 'comfort' THEN 'mpv5'
        WHEN "ride_class" = 'premium' THEN 'suv6'
        WHEN "ride_class" = 'xl' THEN 'van7'
        ELSE 'sedan4'
      END
      WHERE "car_type_id" IS NULL OR "car_type_id" = ''
    `);
    await queryRunner.query(`
      ALTER TABLE "driver_cars"
      ALTER COLUMN "car_type_id" SET NOT NULL
    `);
    await queryRunner.query(`
      ALTER TABLE "driver_cars"
      ALTER COLUMN "car_type_id" SET DEFAULT 'sedan4'
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "driver_cars"
      DROP COLUMN "car_type_id"
    `);
  }
}
