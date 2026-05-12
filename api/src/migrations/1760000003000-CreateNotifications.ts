import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateNotifications1760000003000 implements MigrationInterface {
  name = 'CreateNotifications1760000003000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "notifications" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "kind" character varying(40) NOT NULL,
        "title" character varying(140) NOT NULL,
        "body" character varying(420) NOT NULL,
        "metadata" jsonb,
        "is_read" boolean NOT NULL DEFAULT false,
        "read_at" TIMESTAMP WITH TIME ZONE,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_notifications_id" PRIMARY KEY ("id"),
        CONSTRAINT "FK_notifications_user_id" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      )
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_notifications_user_is_read" ON "notifications" ("user_id", "is_read")
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_notifications_user_created_at" ON "notifications" ("user_id", "created_at")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX "public"."IDX_notifications_user_created_at"
    `);
    await queryRunner.query(`
      DROP INDEX "public"."IDX_notifications_user_is_read"
    `);
    await queryRunner.query(`
      DROP TABLE "notifications"
    `);
  }
}
