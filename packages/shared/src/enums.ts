// DB enum 과 같은 값. apps/server/prisma/schema.prisma 를 바꾸면 여기도 바꾼다.
// (server 의 enums.spec.ts 가 두 값이 같은지 검사한다)

export const UserRole = {
  PLAYER: 'PLAYER',
  HOST: 'HOST',
  ADMIN: 'ADMIN',
} as const;
export type UserRole = (typeof UserRole)[keyof typeof UserRole];

export const PhoneSource = {
  KAKAO: 'KAKAO',
  MANUAL: 'MANUAL',
} as const;
export type PhoneSource = (typeof PhoneSource)[keyof typeof PhoneSource];

export const Position = {
  SP: 'SP',
  RP: 'RP',
  C: 'C',
  FIRST_BASE: 'FIRST_BASE',
  SECOND_BASE: 'SECOND_BASE',
  THIRD_BASE: 'THIRD_BASE',
  SS: 'SS',
  LF: 'LF',
  CF: 'CF',
  RF: 'RF',
  DH: 'DH',
} as const;
export type Position = (typeof Position)[keyof typeof Position];

export const TeamSide = {
  FIRST: 'FIRST',
  SECOND: 'SECOND',
} as const;
export type TeamSide = (typeof TeamSide)[keyof typeof TeamSide];

export const Grade = {
  DIV_1: 'DIV_1',
  DIV_2: 'DIV_2',
  DIV_3: 'DIV_3',
  DIV_4: 'DIV_4',
  ROOKIE: 'ROOKIE',
} as const;
export type Grade = (typeof Grade)[keyof typeof Grade];

export const ReviewStatus = {
  PENDING: 'PENDING',
  APPROVED: 'APPROVED',
  REJECTED: 'REJECTED',
} as const;
export type ReviewStatus = (typeof ReviewStatus)[keyof typeof ReviewStatus];

export const GameStatus = {
  SCHEDULED: 'SCHEDULED',
  CANCELLED: 'CANCELLED',
} as const;
export type GameStatus = (typeof GameStatus)[keyof typeof GameStatus];

export const GameCancelReason = {
  RAIN: 'RAIN',
  STADIUM: 'STADIUM',
  LACK_OF_PLAYERS: 'LACK_OF_PLAYERS',
  OTHER: 'OTHER',
} as const;
export type GameCancelReason =
  (typeof GameCancelReason)[keyof typeof GameCancelReason];

export const ReservationStatus = {
  RESERVED: 'RESERVED',
  PAYMENT_SUBMITTED: 'PAYMENT_SUBMITTED',
  APPROVED: 'APPROVED',
  EXPIRED: 'EXPIRED',
  CANCELLED: 'CANCELLED',
  REJECTED: 'REJECTED',
  GAME_CANCELLED: 'GAME_CANCELLED',
  ATTENDED: 'ATTENDED',
  NO_SHOW: 'NO_SHOW',
} as const;
export type ReservationStatus =
  (typeof ReservationStatus)[keyof typeof ReservationStatus];

export const ExpireReason = {
  PAYMENT_TIMEOUT: 'PAYMENT_TIMEOUT',
  APPROVAL_TIMEOUT: 'APPROVAL_TIMEOUT',
} as const;
export type ExpireReason = (typeof ExpireReason)[keyof typeof ExpireReason];

export const UserReviewReason = {
  NO_SHOW_THRESHOLD: 'NO_SHOW_THRESHOLD',
} as const;
export type UserReviewReason =
  (typeof UserReviewReason)[keyof typeof UserReviewReason];

export const UserReviewStatus = {
  PENDING: 'PENDING',
  SUSPENDED: 'SUSPENDED',
  DISMISSED: 'DISMISSED',
} as const;
export type UserReviewStatus =
  (typeof UserReviewStatus)[keyof typeof UserReviewStatus];

export const SuspensionSource = {
  NO_SHOW_REVIEW: 'NO_SHOW_REVIEW',
  REPORT: 'REPORT',
  ADMIN: 'ADMIN',
} as const;
export type SuspensionSource =
  (typeof SuspensionSource)[keyof typeof SuspensionSource];

export const ReportReason = {
  BAD_MANNER: 'BAD_MANNER',
  ABUSE: 'ABUSE',
  FALSE_INFO: 'FALSE_INFO',
  FRAUD: 'FRAUD',
  OTHER: 'OTHER',
} as const;
export type ReportReason = (typeof ReportReason)[keyof typeof ReportReason];

export const ReportStatus = {
  PENDING: 'PENDING',
  WARNED: 'WARNED',
  SUSPENDED: 'SUSPENDED',
  DISMISSED: 'DISMISSED',
} as const;
export type ReportStatus = (typeof ReportStatus)[keyof typeof ReportStatus];

export const AppealType = {
  NO_SHOW: 'NO_SHOW',
  EVALUATION: 'EVALUATION',
} as const;
export type AppealType = (typeof AppealType)[keyof typeof AppealType];

export const AppealStatus = {
  PENDING: 'PENDING',
  ACCEPTED: 'ACCEPTED',
  REJECTED: 'REJECTED',
} as const;
export type AppealStatus = (typeof AppealStatus)[keyof typeof AppealStatus];

export const NotificationType = {
  PAYMENT_DEADLINE_12H: 'PAYMENT_DEADLINE_12H',
  PAYMENT_DEADLINE_1H: 'PAYMENT_DEADLINE_1H',
  RESERVATION_APPROVED: 'RESERVATION_APPROVED',
  RESERVATION_REJECTED: 'RESERVATION_REJECTED',
  RESERVATION_EXPIRED: 'RESERVATION_EXPIRED',
  APPROVAL_REMINDER: 'APPROVAL_REMINDER',
  RESERVATION_CANCELLED: 'RESERVATION_CANCELLED',
  GAME_CANCELLED: 'GAME_CANCELLED',
  ATTENDANCE_REMINDER: 'ATTENDANCE_REMINDER',
  EVALUATION_OPENED: 'EVALUATION_OPENED',
  REPORT_RESOLVED: 'REPORT_RESOLVED',
} as const;
export type NotificationType =
  (typeof NotificationType)[keyof typeof NotificationType];

export const NotificationStatus = {
  PENDING: 'PENDING',
  SENT: 'SENT',
  FAILED: 'FAILED',
  SKIPPED: 'SKIPPED',
} as const;
export type NotificationStatus =
  (typeof NotificationStatus)[keyof typeof NotificationStatus];
