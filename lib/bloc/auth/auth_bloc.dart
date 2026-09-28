import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.login(event.username, event.password);
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        final remaining = authRepository.getRemainingAttempts(event.username);
        if (remaining > 0 && remaining < 5) {
          emit(AuthFailure('اسم المستخدم أو كلمة المرور غير صحيحة. المحاولات المتبقية قبل القفل: $remaining'));
        } else {
          emit(const AuthFailure('اسم المستخدم أو كلمة المرور غير صحيحة'));
        }
      }
    } on AuthLockoutException catch (e) {
      emit(AuthFailure(e.message));
    } catch (e) {
      emit(AuthFailure('حدث خطأ أثناء تسجيل الدخول: $e'));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthUnauthenticated());
  }
}
