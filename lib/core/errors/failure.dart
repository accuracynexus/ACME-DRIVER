import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class RoleFailure extends Failure {
  const RoleFailure([super.message = 'Acceso denegado: solo repartidores']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sin conexión a internet']);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Error en datos locales']);
}

class LocationFailure extends Failure {
  const LocationFailure([super.message = 'Error al obtener ubicación']);
}

class OrderFailure extends Failure {
  const OrderFailure(super.message);
}
