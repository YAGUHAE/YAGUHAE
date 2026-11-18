import { Grade, Position, ReservationStatus, TeamSide } from './enums.js';

// 화면 표시용 이름 (정책 명세서 4·5장)
export const POSITION_LABEL: Record<Position, string> = {
  [Position.SP]: '선발투수',
  [Position.RP]: '구원투수',
  [Position.C]: '포수',
  [Position.FIRST_BASE]: '1루수',
  [Position.SECOND_BASE]: '2루수',
  [Position.THIRD_BASE]: '3루수',
  [Position.SS]: '유격수',
  [Position.LF]: '좌익수',
  [Position.CF]: '중견수',
  [Position.RF]: '우익수',
  [Position.DH]: '지명타자',
};

export const GRADE_LABEL: Record<Grade, string> = {
  [Grade.DIV_1]: '1부',
  [Grade.DIV_2]: '2부',
  [Grade.DIV_3]: '3부',
  [Grade.DIV_4]: '4부',
  [Grade.ROOKIE]: '루키',
};

export const TEAM_SIDE_LABEL: Record<TeamSide, string> = {
  [TeamSide.FIRST]: '선공',
  [TeamSide.SECOND]: '후공',
};

/** 활성 예약: 자리를 잡고 있는 상태 (정책 1.2) */
export const ACTIVE_RESERVATION_STATUSES = [
  ReservationStatus.RESERVED,
  ReservationStatus.PAYMENT_SUBMITTED,
  ReservationStatus.APPROVED,
] as const satisfies readonly ReservationStatus[];

/** 한 경기의 자리 수: 선공·후공 × 포지션 11개 (정책 5.1) */
export const SLOTS_PER_GAME =
  Object.keys(TeamSide).length * Object.keys(Position).length;
