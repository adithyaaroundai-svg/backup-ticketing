abstract class Failure {
  final String message;
  Failure(this.message);
}

class ServerFailure extends Failure {
  ServerFailure([super.message = 'Server Error']);
}

class NetworkFailure extends Failure {
  NetworkFailure([super.message = 'No Internet Connection']);
}
