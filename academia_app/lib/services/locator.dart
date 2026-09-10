import 'package:get_it/get_it.dart';
import 'package:academia_app/services/theme_controller.dart';
import 'package:academia_app/services/notification_service.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  locator.registerLazySingleton(() => ThemeController.instance);
  locator.registerLazySingleton(() => NotificationService);
}
