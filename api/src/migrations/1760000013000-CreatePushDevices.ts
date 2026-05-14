import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreatePushDevices1760000013000 implements MigrationInterface {
  name = 'CreatePushDevices1760000013000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TYPE "public"."push_devices_platform_enum" AS ENUM('android', 'ios', 'web')
    `);
    await queryRunner.query(`
      CREATE TABLE "push_devices" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "platform" "public"."push_devices_platform_enum" NOT NULL,
        "device_token" character varying(2048) NOT NULL,
        "sns_endpoint_arn" character varying(2048),
        "is_active" boolean NOT NULL DEFAULT true,
        "last_seen_at" TIMESTAMP WITH TIME ZONE,
        "last_error" character varying(2048),
        "app_version" character varying(120),
        "device_label" character varying(240),
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_push_devices_id" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_push_devices_user_id_is_active"
      ON "push_devices" ("user_id", "is_active")
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "IDX_push_devices_platform_device_token"
      ON "push_devices" ("platform", "device_token")
    `);
    await queryRunner.query(`
      ALTER TABLE "push_devices"
      ADD CONSTRAINT "FK_push_devices_user_id"
      FOREIGN KEY ("user_id") REFERENCES "users"("id")
      ON DELETE CASCADE ON UPDATE NO ACTION
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "push_devices" DROP CONSTRAINT "FK_push_devices_user_id"
    `);
    await queryRunner.query(`
      DROP INDEX "public"."IDX_push_devices_platform_device_token"
    `);
    await queryRunner.query(`
      DROP INDEX "public"."IDX_push_devices_user_id_is_active"
    `);
    await queryRunner.query(`
      DROP TABLE "push_devices"
    `);
    await queryRunner.query(`
      DROP TYPE "public"."push_devices_platform_enum"
    `);
  }
}
