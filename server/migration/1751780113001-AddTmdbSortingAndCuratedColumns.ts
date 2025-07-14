import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddTmdbSortingAndCuratedColumns1751780113001 implements MigrationInterface {
  name = 'AddTmdbSortingAndCuratedColumns1751780113001';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Add tmdbSortingMode column
    await queryRunner.query(
      `ALTER TABLE "user_settings" ADD "tmdbSortingMode" varchar DEFAULT 'curated'`
    );
    
    // Add curatedMinVotes column
    await queryRunner.query(
      `ALTER TABLE "user_settings" ADD "curatedMinVotes" integer DEFAULT 3000`
    );
    
    // Add curatedMinRating column
    await queryRunner.query(
      `ALTER TABLE "user_settings" ADD "curatedMinRating" real DEFAULT 6.0`
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "user_settings" DROP COLUMN "curatedMinRating"`
    );
    await queryRunner.query(
      `ALTER TABLE "user_settings" DROP COLUMN "curatedMinVotes"`
    );
    await queryRunner.query(
      `ALTER TABLE "user_settings" DROP COLUMN "tmdbSortingMode"`
    );
  }
}
