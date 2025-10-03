import type { DiscoverSliderType } from '@server/constants/discover';
import { defaultSliders } from '@server/constants/discover';
import { getRepository } from '@server/datasource';
import logger from '@server/logger';
import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity()
class DiscoverSlider {
  public static async bootstrapSliders(): Promise<void> {
    try {
      const sliderRepository = getRepository(DiscoverSlider);

      // Test if table exists by attempting a count query
      try {
        await sliderRepository.count();
      } catch (tableError: any) {
        // Table doesn't exist yet - migrations haven't run
        logger.warn('DiscoverSlider table does not exist yet. Skipping bootstrap.', {
          label: 'Discover Slider',
          error: tableError.message,
        });
        return;
      }

      for (const slider of defaultSliders) {
        const existingSlider = await sliderRepository.findOne({
          where: {
            type: slider.type,
          },
        });

        if (!existingSlider) {
          logger.info('Creating built-in discovery slider', {
            label: 'Discover Slider',
            slider,
          });
          await sliderRepository.save(new DiscoverSlider(slider));
        }
      }
    } catch (error: any) {
      logger.error('Failed to bootstrap discovery sliders', {
        label: 'Discover Slider',
        error: error.message,
      });
      // Don't throw - allow app to continue
    }
  }

  @PrimaryGeneratedColumn()
  public id: number;

  @Column({ type: 'int' })
  public type: DiscoverSliderType;

  @Column({ type: 'int' })
  public order: number;

  @Column({ default: false })
  public isBuiltIn: boolean;

  @Column({ default: true })
  public enabled: boolean;

  @Column({ nullable: true })
  // Title is not required for built in sliders because we will
  // use translations for them.
  public title?: string;

  @Column({ nullable: true })
  public data?: string;

  @CreateDateColumn()
  public createdAt: Date;

  @UpdateDateColumn()
  public updatedAt: Date;

  constructor(init?: Partial<DiscoverSlider>) {
    Object.assign(this, init);
  }
}

export default DiscoverSlider;
