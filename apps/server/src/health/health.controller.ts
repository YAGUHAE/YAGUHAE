import { Controller, Get } from '@nestjs/common';

// 배포 스크립트와 컨테이너 헬스체크가 호출한다.
// 외부 의존성(DB 등)이 생기면 여기서 함께 확인한다.
@Controller('health')
export class HealthController {
  @Get()
  check(): { status: 'ok' } {
    return { status: 'ok' };
  }
}
