import { IsEmail, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

// Username Tier1: опциональный ведущий @, мин 4 символа, [a-zA-Z0-9_.-], уникальность — в сервисе.
export class RegisterDto {
  @IsEmail()
  @MaxLength(254)
  email!: string;

  @IsString()
  @Matches(/^@?[a-zA-Z0-9_.-]{4,}$/, {
    message: 'username must be min 4 chars of [a-zA-Z0-9_.-] with optional leading @',
  })
  @MaxLength(33)
  username!: string;

  @IsString()
  @MinLength(6)
  @MaxLength(128)
  password!: string;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  deviceInfo?: string;
}

export class LoginDto {
  // email или username (@username тоже принимается)
  @IsString()
  @MinLength(3)
  @MaxLength(254)
  identifier!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(128)
  password!: string;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  deviceInfo?: string;
}

export class RefreshDto {
  @IsString()
  refreshToken!: string;
}

export class VerifyRequestDto {
  @IsEmail()
  @MaxLength(254)
  email!: string;
}

export class VerifyConfirmDto {
  @IsEmail()
  @MaxLength(254)
  email!: string;

  @IsString()
  @Matches(/^\d{6}$/, { message: 'code must be 6 digits' })
  code!: string;
}

export class LogoutDto {
  @IsString()
  refreshToken!: string;
}
