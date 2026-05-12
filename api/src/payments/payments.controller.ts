import {
  Body,
  Controller,
  Delete,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Get,
} from '@nestjs/common';
import { PaymentsService } from './payments.service';
import { CreateWebSetupSessionDto } from './dto/create-web-setup-session.dto';

@Controller('payments')
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}

  @Get('cards')
  @HttpCode(HttpStatus.OK)
  listCards(@Headers('authorization') authorization: string | undefined) {
    return this.payments.listCards(authorization);
  }

  @Post('setup-intent')
  @HttpCode(HttpStatus.OK)
  createSetupIntent(
    @Headers('authorization') authorization: string | undefined,
  ) {
    return this.payments.createSetupIntent(authorization);
  }

  @Post('web/setup-session')
  @HttpCode(HttpStatus.OK)
  createWebSetupSession(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: CreateWebSetupSessionDto,
  ) {
    return this.payments.createWebSetupSession(authorization, body.returnUrl);
  }

  @Post('cards/sync')
  @HttpCode(HttpStatus.OK)
  syncCards(@Headers('authorization') authorization: string | undefined) {
    return this.payments.syncCards(authorization);
  }

  @Delete('cards/:cardId')
  @HttpCode(HttpStatus.OK)
  removeCard(
    @Headers('authorization') authorization: string | undefined,
    @Param('cardId', ParseUUIDPipe) cardId: string,
  ) {
    return this.payments.removeCard(authorization, cardId);
  }
}
