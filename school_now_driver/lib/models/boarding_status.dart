enum BoardingStatus {
  notBoarded,
  boarded,
  alighted,
  absent,
}

class BoardingStatusCodec {
  static String toJson(BoardingStatus status) {
    switch (status) {
      case BoardingStatus.notBoarded:
        return 'not_boarded';
      case BoardingStatus.boarded:
        return 'boarded';
      case BoardingStatus.alighted:
        return 'alighted';
      case BoardingStatus.absent:
        return 'absent';
    }
  }

  static BoardingStatus fromJson(String value) {
    switch (value) {
      case 'not_boarded':
        return BoardingStatus.notBoarded;
      case 'boarded':
        return BoardingStatus.boarded;
      case 'alighted':
        return BoardingStatus.alighted;
      case 'absent':
        return BoardingStatus.absent;
      default:
        return BoardingStatus.notBoarded;
    }
  }
}
