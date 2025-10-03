import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddTmdbSortingAndCuratedColumns1751780113001 implements MigrationInterface {
  name = 'AddTmdbSortingAndCuratedColumns1751780113001';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Add nullable columns without defaults for safe migration from vanilla Overseerr
    // Defaults will be handled in application code
    
    // Add tmdbSortingMode column
    await queryRunner.query(
      `ALTER TABLE "user_settings" ADD "tmdbSortingMode" varchar`
    );
    
    // Add curatedMinVotes column
    await queryRunner.query(
      `ALTER TABLE "user_settings" ADD "curatedMinVotes" int`
    );
    
    // Add curatedMinRating column
    await queryRunner.query(
      `ALTER TABLE "user_settings" ADD "curatedMinRating" float`
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
