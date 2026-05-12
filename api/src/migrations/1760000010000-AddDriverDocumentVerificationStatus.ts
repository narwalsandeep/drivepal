import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddDriverDocumentVerificationStatus1760000010000
  implements MigrationInterface
{
  name = 'AddDriverDocumentVerificationStatus1760000010000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TYPE "public"."users_driver_document_status_enum" AS ENUM('pending', 'approved', 'rejected')
    `);
    await queryRunner.query(`
      ALTER TABLE "users"
      ADD COLUMN "driver_document_status" "public"."users_driver_document_status_enum" NOT NULL DEFAULT 'pending'
    `);
    await queryRunner.query(`
      ALTER TABLE "users"
      ADD COLUMN "driver_document_reviewed_at" TIMESTAMP WITH TIME ZONE
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "users" DROP COLUMN "driver_document_reviewed_at"
    `);
    await queryRunner.query(`
      ALTER TABLE "users" DROP COLUMN "driver_document_status"
    `);
    await queryRunner.query(`
      DROP TYPE "public"."users_driver_document_status_enum"
    `);
  }
}
