import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'firebase_service.dart';
import 'main.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({Key? key, required this.onLoginSuccess}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _isRegister = false;
  bool _obscurePassword = true;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final result = await FirebaseService.signInWithGoogle();
      if (result != null && mounted) {
        widget.onLoginSuccess();
        if (!mounted) return;
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BibleAppYearly()));
        }
      } else {
        // result == null can mean redirect was started (fallback) or user cancelled
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выполняется вход через Google (redirect)... Пожалуйста, дождитесь завершения.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'configuration-not-found') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка: OAuth-конфигурация не найдена. Откройте настройки Firebase.')));
          await _showAuthConfigDialog('Google');
        }
      } else {
        final msg = 'Ошибка входа через Google: ${e.message ?? e.code}';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  Future<void> _handleEmailSignUp() async {
    if (!_formKey.currentState!.validate()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Проверьте введённые данные')));
      return;
    }



    setState(() => _isLoading = true);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Регистрация...')));
    try {
      final result = await FirebaseService.signUpWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      if (result.user != null && mounted) {
        // Показываем явный диалог, чтобы было видно, что регистрация прошла успешно
        await showDialog(
          context: context,
          builder: (dctx) => AlertDialog(
            title: const Text('Успешно'),
            content: const Text('Пользователь создан. Проверьте почту для подтверждения.'),
            actions: [TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('OK'))],
          ),
        );
        widget.onLoginSuccess();
        if (!mounted) return;
        // Если есть куда возвращаться — просто закроем экран, иначе заменим на главный экран
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BibleAppYearly()));
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'operation-not-allowed') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка: Email/Password вход отключён в Firebase. Откройте настройки.')));
          await _showEmailProviderDialog();
        }
      } else {
        final message = e.message ?? 'Ошибка регистрации (${e.code})';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailSignIn() async {
    if (!_formKey.currentState!.validate()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Проверьте введённые данные')));
      return;
    }



    setState(() => _isLoading = true);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Вход...')));
    try {
      final result = await FirebaseService.signInWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      if (result != null && mounted) {
        widget.onLoginSuccess();
        if (!mounted) return;
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BibleAppYearly()));
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'operation-not-allowed') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка: Email/Password вход отключён в Firebase. Откройте настройки.')));
          await _showEmailProviderDialog();
        }
      } else {
        final message = e.message ?? 'Ошибка входа (${e.code})';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.book,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Библия за год',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Пожалуйста, войдите, чтобы синхронизировать прогресс между устройствами',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'Email',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Введите email';
                            if (!v.contains('@')) return 'Неверный email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'Пароль',
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              color: Colors.grey[700],
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              tooltip: _obscurePassword ? 'Показать пароль' : 'Скрыть пароль',
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.length < 6) return 'Пароль минимум 6 символов';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Кнопки для входа и регистрации по Email
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleEmailSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue.shade600,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Войти по Email'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _handleEmailSignUp,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white70),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Зарегистрироваться'),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSignInButton(
                    icon: const FaIcon(FontAwesomeIcons.google, size: 20),
                    label: 'Войти через Google',
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue.shade600,
                  ),
                  const SizedBox(height: 16),

                  const SizedBox(height: 24),
                  if (_isLoading)
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _showAuthConfigDialog(String providerName) async {
    final projectId = (() {
      try {
        // Use Firebase project id if available
        // ignore: avoid_dynamic_calls
        return Firebase.app().options.projectId;
      } catch (_) {
        return 'your-project-id';
      }
    })();

    final providersUrl = 'https://console.firebase.google.com/project/$projectId/authentication/providers';
    final settingsUrl = 'https://console.firebase.google.com/project/$projectId/authentication/settings';

    await showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('OAuth-конфигурация $providerName не найдена'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Включите соответствующий провайдер в Firebase Console (Authentication → Sign-in method).'),
            const SizedBox(height: 8),
            const Text('Также добавьте домен localhost в Authorized domains (Authentication → Settings).'),
            const SizedBox(height: 12),
            SelectableText('Провайдеры: $providersUrl', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            SelectableText('Настройки доменов: $settingsUrl', style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: providersUrl));
              if (mounted) {
                Navigator.pop(dctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ссылка на страницу провайдеров скопирована в буфер обмена')));
              }
            },
            child: const Text('Скопировать ссылку на провайдеры'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: settingsUrl));
              if (mounted) {
                Navigator.pop(dctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ссылка на настройки доменов скопирована в буфер обмена')));
              }
            },
            child: const Text('Скопировать ссылку на домены'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await launchUrlString(providersUrl, webOnlyWindowName: '_blank');
                if (mounted) Navigator.pop(dctx);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось открыть ссылку: $e')));
                }
              }
            },
            child: const Text('Открыть провайдеры'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await launchUrlString(settingsUrl, webOnlyWindowName: '_blank');
                if (mounted) Navigator.pop(dctx);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось открыть ссылку: $e')));
                }
              }
            },
            child: const Text('Открыть домены'),
          ),
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  Future<void> _showEmailProviderDialog() async {
    final projectId = (() {
      try {
        // ignore: avoid_dynamic_calls
        return Firebase.app().options.projectId;
      } catch (_) {
        return 'your-project-id';
      }
    })();
    final providersUrl = 'https://console.firebase.google.com/project/$projectId/authentication/providers';

    await showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Email/Password вход отключён'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Для использования входа по Email/Паролю включите провайдер в Firebase Console (Authentication → Sign-in method → Email/Password).'),
            const SizedBox(height: 8),
            SelectableText('Страница провайдеров: $providersUrl', style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await launchUrlString(providersUrl, webOnlyWindowName: '_blank');
                if (mounted) Navigator.pop(dctx);
              } catch (e) {
                if (mounted) {
                  Navigator.pop(dctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось открыть ссылку: $e')));
                }
              }
            },
            child: const Text('Открыть провайдеры'),
          ),
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  Widget _buildSignInButton({
    required Widget icon,
    required String label,
    required VoidCallback? onPressed,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: icon,
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
