import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';
import 'home_screen.dart';

// 🔐 Pantalla de Login
//stateful widget porque necesitamos manejar el estado de los campos de texto y la visibilidad de la contraseña.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

//el _ significa que la clase es privada y solo se puede usar dentro de este archivo.
class _LoginScreenState extends State<LoginScreen> {
  //el final significa que la variable no puede ser reasignada después de su inicialización.
  //crea una llave global para el formulario, que nos permite validar los campos y acceder a su estado.
  final _formKey = GlobalKey<FormState>();
  //controladores para los campos de texto, que nos permiten obtener y modificar el texto ingresado.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  //variable booleana para controlar si la contraseña se muestra o se oculta.
  bool _obscurePassword = true;
  //dispose() se llama cuando el widget se elimina del árbol de widgets,
  //y nos permite liberar recursos como los controladores de texto.
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 🚀 Función para iniciar sesión
  //Future <void> indica que la función es asíncrona y no devuelve ningún valor.
  Future<void> _login() async {
    //valida el formulario usando la llave global, y si es válido, procede a iniciar sesión.
    if (_formKey.currentState!.validate()) {
      //context.read<>() busca el AuthProvider en la memoria de la app y lo guarda en authProvider.
      //Es como "ve al centro de datos y tráeme el proveedor de autenticación".
      final authProvider = context.read<AuthProvider>();
      //llama al método login del proveedor de autenticación, pasando el email y la contraseña ingresados por el usuario.
      //trim() elimina espacios en blanco al inicio y al final del texto.
      //await espera a que la función login termine de ejecutarse antes de continuar con el código.
      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      //si el login fue exitoso y el widget sigue montado en la pantalla, navega a la pantalla de inicio reemplazando la actual.
      if (success && mounted) {
        // ✅ Navegar al Home si el login es exitoso
        //pushReplacementNamed reemplaza la pantalla actual con la nueva,
        //evitando que el usuario pueda volver a la pantalla de login con el botón de retroceso.
        Navigator.pushReplacementNamed(context, '/home');
        //mounted es una propiedad que indica si el widget sigue siendo parte del árbol de widgets,
        //lo que evita errores si el usuario navega fuera de la pantalla antes de que termine el login.
      } else if (mounted) {
        // ❌ Mostrar error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Email o contraseña incorrectos'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    //scaffold es un widget que proporciona una estructura básica para la pantalla, como app bar, body y floating action button.
    return Scaffold(
      //safearea evita que el contenido se superponga con elementos del sistema, como la barra de estado o la muesca del dispositivo.
      body: SafeArea(
        //hace que todo este en el centro de la pantalla
        child: Center(
          //permite que el contenido se desplace si no cabe en la pantalla, evitando errores de overflow.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            //crea un formulario que agrupa los campos de texto y permite validarlos juntos.
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🎨 Logo o icono
                  Icon(Icons.receipt_long, size: 80, color: Colors.green[700]),
                  const SizedBox(height: 16),
                  const Text(
                    'BillTracker',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Controla tus facturas fácilmente',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 40),

                  // 📧 Campo de Email
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    //keyboardtype define el tipo de teclado que se muestra al usuario, en este caso uno optimizado para ingresar emails.
                    keyboardType: TextInputType.emailAddress,
                    //reglas de validación para el campo de email, que se ejecutan cuando el usuario intenta enviar el formulario.
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa tu email';
                      }
                      if (!value.contains('@')) {
                        return 'Email inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 🔑 Campo de Contraseña
                  //textformfield es un widget que permite al usuario ingresar texto, con opciones de validación y personalización.
                  TextFormField(
                    //para guardar el texto ingresado en el controlador de contraseña, que nos permite acceder a él más tarde.
                    controller: _passwordController,
                    //decoration personaliza la apariencia del campo, como el label, el icono y el borde.
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock),
                      //boton para mostrar u ocultar la contraseña, que cambia el estado de _obscurePassword y actualiza el icono.
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        //onpressed cambia el estado de _obscurepassword y actualiza la pantalla.
                        onPressed: () {
                          setState(() {
                            //rescontruye el widget con el nuevo valor de _obscurePassword, mostrando u ocultando la contraseña.
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText:
                        _obscurePassword, //si es true, oculta el texto ingresado con puntos o asteriscos.
                    //reglas de validación para el campo de contraseña, que se ejecutan cuando el
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa tu contraseña';
                      }
                      if (value.length < 6) {
                        return 'Mínimo 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // 🔘 Botón de Login
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      //si el botón está deshabilitado (porque authProvider.isLoading es true), no hace nada al presionarlo.
                      onPressed: authProvider.isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: authProvider.isLoading
                          //si authProvider.isLoading es true, muestra un indicador de carga en lugar del texto del botón.
                          //circularprogressindicator es un widget que muestra un círculo giratorio para indicar que algo está cargando.
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Iniciar Sesión',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🔗 Link a recuperación de contraseña
                  //textbutton es un widget que muestra un texto que se puede presionar, como un enlace.
                  //te redirecciona a la pantalla de recuperación de contraseña cuando se presiona.
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ResetPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),

                  // 📝 Link a Registro
                  Row(
                    //row organiza los widgets hijos en una fila horizontal, en este caso el texto y el botón de registro.
                    //mainaxisalignment centra los widgets hijos en la fila, dejando espacio igual a ambos lados.
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('¿No tienes cuenta?'),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Regístrate',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
