import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { User } from '../auth/entities/user.entity';
import { PaymentAttempt } from './entities/payment-attempt.entity';
import { PaymentCard } from './entities/payment-card.entity';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { stripeClientProvider } from './stripe-client.provider';

@Module({
  imports: [
    AuthModule,
    TypeOrmModule.forFeature([User, PaymentCard, PaymentAttempt]),
  ],
  controllers: [PaymentsController],
  providers: [PaymentsService, stripeClientProvider],
  exports: [PaymentsService],
})
export class PaymentsModule {}
