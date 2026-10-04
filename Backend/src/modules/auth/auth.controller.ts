import { Body, Controller, Get, Ip, Post, Query } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import {
  LoginDto,
  LogoutDto,
  RefreshDto,
  RegisterDto,
  VerifyConfirmDto,
  VerifyRequestDto,
} from './auth.dto';

@Controller('auth')
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly jwt: JwtService,
  ) {}

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto.email, dto.username, dto.password, dto.deviceInfo);
  }

  @Post('login')
  login(@Body() dto: LoginDto, @Ip() ip: string) {
    return this.auth.login(dto.identifier, dto.password, this.jwt, ip || 'unknown', dto.deviceInfo);
  }

  @Post('refresh')
  refresh(@Body() dto: RefreshDto) {
    return this.auth.refresh(dto.refreshToken, this.jwt);
  }

  @Post('logout')
  logout(@Body() dto: LogoutDto) {
    return this.auth.logout(dto.refreshToken);
  }

  @Post('logout-all')
  logoutAll(@Body() dto: { userId: string }) {
    return this.auth.logoutAll(dto.userId);
  }

  @Post('verify-code')
  verifyCode(@Body() dto: VerifyRequestDto) {
    return this.auth.requestVerifyCode(dto.email);
  }

  @Post('verify-email')
  verifyEmail(@Body() dto: VerifyConfirmDto) {
    return this.auth.verifyEmail(dto.email, dto.code);
  }

  @Get('sessions')
  sessions(@Query('userId') userId: string) {
    return this.auth.listSessions(userId);
  }

  @Get('devices')
  devices(@Query('userId') userId: string) {
    return this.auth.listDevices(userId);
  }
}
