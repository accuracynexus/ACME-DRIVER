abstract class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

class AppAuthException extends AppException {
  const AppAuthException(super.message);
}

class AppRoleException extends AppException {
  const AppRoleException([super.message = 'Acceso denegado: rol insuficiente']);
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'Sin conexión a internet']);
}

class ServerException extends AppException {
  final int? statusCode;
  const ServerException(super.message, {this.statusCode});
}

class CacheException extends AppException {
  const CacheException([super.message = 'Error al leer datos locales']);
}

class LocationException extends AppException {
  const LocationException([super.message = 'No se pudo obtener la ubicación']);
}

class OrderException extends AppException {
  const OrderException(super.message);
}
