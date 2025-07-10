import 'package:get_it/get_it.dart';
import '../../features/media/data/datasources/media_local_datasource.dart';
import '../../features/media/data/repositories/media_repository_impl.dart';
import '../../features/media/domain/repositories/media_repository.dart';
import '../../features/media/domain/usecases/media_usecases.dart';
import '../../features/media/presentation/bloc/media_bloc.dart';
import '../../features/player/services/global_player_service.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // Services
  getIt.registerLazySingleton<GlobalPlayerService>(
    () => GlobalPlayerService(),
  );

  // Data sources
  getIt.registerLazySingleton<MediaLocalDataSource>(
    () => MediaLocalDataSource(),
  );

  // Repositories
  getIt.registerLazySingleton<MediaRepository>(
    () => MediaRepositoryImpl(getIt<MediaLocalDataSource>()),
  );

  // Use cases
  getIt.registerLazySingleton(() => AddMediaUseCase(getIt<MediaRepository>()));
  getIt.registerLazySingleton(
    () => GetMediaItemsUseCase(getIt<MediaRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetMediaItemsByCategoryUseCase(getIt<MediaRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetFavoriteMediaItemsUseCase(getIt<MediaRepository>()),
  );
  getIt.registerLazySingleton(
    () => UpdateMediaItemUseCase(getIt<MediaRepository>()),
  );
  getIt.registerLazySingleton(
    () => ToggleFavoriteUseCase(getIt<MediaRepository>()),
  );
  getIt.registerLazySingleton(
    () => DeleteMediaItemUseCase(getIt<MediaRepository>()),
  );

  // BLoC
  getIt.registerFactory(
    () => MediaBloc(
      addMediaUseCase: getIt<AddMediaUseCase>(),
      getMediaItemsUseCase: getIt<GetMediaItemsUseCase>(),
      getMediaItemsByCategoryUseCase: getIt<GetMediaItemsByCategoryUseCase>(),
      getFavoriteMediaItemsUseCase: getIt<GetFavoriteMediaItemsUseCase>(),
      updateMediaItemUseCase: getIt<UpdateMediaItemUseCase>(),
      toggleFavoriteUseCase: getIt<ToggleFavoriteUseCase>(),
      deleteMediaItemUseCase: getIt<DeleteMediaItemUseCase>(),
    ),
  );
}
