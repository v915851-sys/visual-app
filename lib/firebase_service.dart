import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseService {
  // Используем getters, чтобы отложить доступ к синглтонам Firebase до реального вызова
  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static bool get _isInitialized => Firebase.apps.isNotEmpty;

  static void _ensureInitOrThrow() {
    if (!_isInitialized) {
      // Сгенерированная ошибка — можно ловить её в UI
      throw StateError('Firebase is not initialized. Call Firebase.initializeApp() first.');
    }
  }

  // Вход через Google
  static Future<UserCredential?> signInWithGoogle() async {
    if (!_isInitialized) {
      print('Google Sign In attempted but Firebase is not initialized');
      return null;
    }

    // На Web лучше использовать popup/redirect OAuth flow через Firebase Auth
    // В нативных приложениях используем google_sign_in package
    try {
      // Используем lazy import флага платформы
      // ignore: avoid_web_libraries_in_flutter
      if (const bool.fromEnvironment('dart.library.html', defaultValue: false)) {
        // Web path: sign in with popup (with redirect fallback)
        final provider = GoogleAuthProvider();
        try {
          return await _auth.signInWithPopup(provider);
        } on FirebaseAuthException catch (e) {
          // Попробуем fallback на redirect, если попапы заблокированы или пользователь закрыл окно
          if (e.code == 'popup-blocked' || e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
            // signInWithRedirect перенаправит браузер и завершит авторизацию после возврата
            await _auth.signInWithRedirect(provider);
            return null;
          }
          rethrow;
        }
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      // Логируем и пробрасываем дальше — UI покажет подробную ошибку
      print('Google Sign In Error: $e');
      rethrow;
    }
  }


  // Регистрация через Email/Password
  static Future<UserCredential> signUpWithEmail({required String email, required String password}) async {
    if (!_isInitialized) throw StateError('Firebase is not initialized');
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    try {
      await cred.user?.sendEmailVerification();
    } catch (_) {}
    return cred;
  }

  // Вход через Email/Password
  static Future<UserCredential?> signInWithEmail({required String email, required String password}) async {
    if (!_isInitialized) {
      print('Email Sign In attempted but Firebase is not initialized');
      return null;
    }

    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      print('Email sign in error: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      print('Email sign in error: $e');
      return null;
    }
  }

  // Выход из аккаунта
  static Future<void> signOut() async {
    if (!_isInitialized) {
      print('Sign out attempted but Firebase is not initialized');
      return;
    }

    try {
      await _auth.signOut();
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    } catch (e) {
      print('Sign Out Error: $e');
    }
  }

  // Получить текущего пользователя
  static User? getCurrentUser() {
    if (!_isInitialized) return null;
    return _auth.currentUser;
  }

  // Проверить, авторизован ли пользователь
  static bool isUserLoggedIn() {
    if (!_isInitialized) return false;
    return _auth.currentUser != null;
  }

  // Сохранить прогресс в облако
  static Future<void> saveProgressToCloud({
    required Map<String, int> durations,
    required Map<String, bool> isReadStatus,
    required DateTime? userStartDate,
  }) async {
    if (!_isInitialized) {
      print('Save progress attempted but Firebase is not initialized');
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'lastUpdated': FieldValue.serverTimestamp(),
        'progress': {
          'durations': durations,
          'isRead': isReadStatus,
          'userStartDate': userStartDate?.toIso8601String(),
        },
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving progress: $e');
    }
  }

  // Загрузить прогресс из облака
  static Future<Map<String, dynamic>?> loadProgressFromCloud() async {
    if (!_isInitialized) {
      print('Load progress attempted but Firebase is not initialized');
      return null;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error loading progress: $e');
      return null;
    }
  }

  // Stream для отслеживания изменений данных
  static Stream<DocumentSnapshot> getUserProgressStream() {
    if (!_isInitialized) return Stream.empty();
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.empty();
    }
    return _firestore.collection('users').doc(user.uid).snapshots();
  }
}
