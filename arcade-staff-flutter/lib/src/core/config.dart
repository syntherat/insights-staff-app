class AppConfig {
  const AppConfig._();

  static const apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://arcade-app-server.onrender.com/api/staff',
  );
}
