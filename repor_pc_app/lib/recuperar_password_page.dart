import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http; // O tu cliente http personalizado

class RecuperarPasswordPage extends StatefulWidget {
  const RecuperarPasswordPage({super.key});

  @override
  State<RecuperarPasswordPage> createState() => _RecuperarPasswordPageState();
}

class _RecuperarPasswordPageState extends State<RecuperarPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores
  final TextEditingController _correoCtrl = TextEditingController();
  final TextEditingController _codigoCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _confirmPassCtrl = TextEditingController();

  bool _isLoading = false;
  int _pasoActual = 1; // 1 = Solicitar Código, 2 = Validar Código y Cambiar Clave
  bool _obscurePass = true;

  // Base URL de tu Serveo
  final String _baseUrl = "https://cfc5b7860e5ffac7-190-120-254-236.serveousercontent.com/api/auth";

  // Paso 1: Enviar correo para recibir el código de 6 dígitos
  Future<void> _solicitarCodigo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/solicitar-codigo"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "correo": _correoCtrl.text.trim().toLowerCase(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['ok'] == true) {
        _mostrarMensaje(data['message'] ?? "Código enviado a su correo.", Colors.green);
        setState(() => _pasoActual = 2); // Saltamos al paso de restauración
      } else {
        _mostrarMensaje(data['error'] ?? "Error al solicitar código.", Colors.red);
      }
    } catch (e) {
      _mostrarMensaje("Error de conexión con el servidor.", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Paso 2: Enviar el código, el correo y la nueva contraseña
  Future<void> _cambiarPassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passCtrl.text != _confirmPassCtrl.text) {
      _mostrarMensaje("La confirmación de la contraseña no coincide.", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/cambiar-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "correo": _correoCtrl.text.trim().toLowerCase(),
          "codigo": _codigoCtrl.text.trim(),
          "password": _passCtrl.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['ok'] == true) {
        _mostrarMensaje("Contraseña restablecida con éxito.", Colors.green);
        if (mounted) Navigator.pop(context); // Regresa al Login automáticamente
      } else {
        _mostrarMensaje(data['error'] ?? "Error al cambiar contraseña.", Colors.red);
      }
    } catch (e) {
      _mostrarMensaje("Error de conexión con el servidor.", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _mostrarMensaje(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recuperación de Cuenta"),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icono dinámico según el paso
                  Icon(
                    _pasoActual == 1 ? Icons.mark_email_unread_rounded : Icons.lock_open_rounded,
                    size: 80,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(height: 20),
                  
                  // Títulos
                  Text(
                    _pasoActual == 1 ? "Solicitar Código" : "Restablecer Contraseña",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _pasoActual == 1
                        ? "Ingrese su correo institucional. Le enviaremos un código de verificación de 6 dígitos."
                        : "Ingrese el código enviado a su correo electrónico junto con su nueva contraseña.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 30),

                  // --- RENDERIZADO CONDICIONAL DE PASOS ---
                  if (_pasoActual == 1) ...[
                    // PASO 1: Ingreso de correo
                    TextFormField(
                      controller: _correoCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Correo Electrónico",
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return "El correo es requerido.";
                        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(val.trim())) {
                          return "Formato de correo inválido.";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _solicitarCodigo,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Enviar Código", style: TextStyle(fontSize: 16)),
                    ),
                  ] else ...[
                    // PASO 2: Ingreso de Código y Contraseñas
                    TextFormField(
                      controller: _codigoCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: "Código de Verificación",
                        counterText: "",
                        prefixIcon: Icon(Icons.pin),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return "El código es requerido.";
                        if (val.trim().length < 6) return "El código consta de 6 dígitos.";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      decoration: InputDecoration(
                        labelText: "Nueva Contraseña",
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return "La contraseña es requerida.";
                        if (val.length < 6) return "Mínimo 6 caracteres (Requerido por Servidor).";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPassCtrl,
                      obscureText: _obscurePass,
                      decoration: const InputDecoration(
                        labelText: "Confirmar Nueva Contraseña",
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.isEmpty ? "Confirme su contraseña." : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _cambiarPassword,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green.shade700,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Actualizar Contraseña", style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() => _pasoActual = 1),
                      child: const Text("Volver a solicitar un código"),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}