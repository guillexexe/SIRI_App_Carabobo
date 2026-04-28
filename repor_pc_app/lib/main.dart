import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart';      
import 'edan_form.dart'; 
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- CONFIGURACIÓN GLOBAL ---
// Opción B: Emulador oficial de Android (apunta al localhost de la PC)
// const String apiUrl = "http://10.0.2.2:3000/api";
// Opción C: Teléfono físico en la misma red WiFi que la PC
 const String apiUrl = "http://localhost:3000/api";
//const String apiUrl = "http://192.168.68.101:3000/api"; // Usa TU IP real
// const String apiUrl = ""; // Usa TU IP real

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ReporPCApp());
}

class ReporPCApp extends StatelessWidget {
  const ReporPCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Protección Civil Carabobo',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Español
      ],
      theme: ThemeData(
        primaryColor: const Color(0xFF0033CC),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0033CC),
          primary: const Color(0xFF0033CC),
          secondary: const Color(0xFFD32F2F),
        ),
        useMaterial3: true,
      ),
      // --- ESTO ES LO QUE FALTA: DEFINIR LAS RUTAS ---
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/register': (context) => const RegisterPage(),
        '/dashboard': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return DashboardScreen(userData: args['usuario'], token: args['token']);
        },
      },
    );
  }
}
// --- ESTILO GLOBAL ---
final ThemeData pcTheme = ThemeData(
  primaryColor: const Color(0xFF003194),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF003194),
    secondary: const Color(0xFFD32F2F),
  ),
  scaffoldBackgroundColor: const Color(0xFFF5F5F5),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFF003194), width: 2),
      borderRadius: BorderRadius.circular(10),
    ),
  ),
);
// --- 1. PANTALLA DE LOGIN CON ESTILOS ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  // Colores Institucionales
  final Color azulInstitucional = const Color(0xFF003194);
  final Color naranjaInstitucional = const Color(0xFFD32F2F);

  Future<void> _iniciarSesion() async {
    final String correo = _userController.text.trim();
    final String password = _passController.text.trim();

    if (correo.isEmpty || password.isEmpty) {
      _showSnackBar("Por favor, ingrese sus credenciales", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {

      final response = await http.post(
        Uri.parse("$apiUrl/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "correo": correo,
          "password": password,
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_user', jsonEncode(data['usuario']));
      await prefs.setString('session_token', data['token']);
        
        if (!mounted) return;

        // Navegamos al Dashboard pasando los datos del usuario que devuelve el backend
        Navigator.pushReplacementNamed(
          context, 
          '/dashboard', 
          arguments: {
            'usuario': data['usuario'],
            'token': data['token']
          }
        );
      } else {
        // Errores controlados por el backend (401, 404, etc.)
        _showSnackBar(data['error'] ?? "Credenciales incorrectas", Colors.red);
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
    final String? userCached = prefs.getString('session_user');
    final String? tokenCached = prefs.getString('session_token');

    if (userCached != null && tokenCached != null) {
      final userMap = jsonDecode(userCached);
      
      // Verificación básica: ¿Es el mismo correo que se logueó antes?
      if (userMap['correo'] == correo) {
        _showSnackBar("Modo Offline: Sesión recuperada", Colors.orange);
        
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context, 
          '/dashboard', 
          arguments: {'usuario': userMap, 'token': tokenCached}
        );
      } else {
        _showSnackBar("Sin conexión. El usuario no coincide con la sesión guardada.", Colors.red);
      }
    } else {
      _showSnackBar("Sin conexión y no hay sesiones previas.", Colors.red);
    }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(35),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- LOGO INSTITUCIONAL ---
              Image.asset(
                'assets/images/IASIEDAGREC.jpeg',
                height: 120,
                errorBuilder: (context, error, stackTrace) => 
                  Icon(Icons.shield, size: 100, color: naranjaInstitucional),
              ),
              const SizedBox(height: 15),
              
              // --- TÍTULOS ---
              Text(
                "I.A.S.I.E.D.A.G.R.E.C.",
                style: TextStyle(
                  fontSize: 35, 
                  fontWeight: FontWeight.bold, 
                  color: azulInstitucional,
                  letterSpacing: 2,
                ),
              ),
              const Text(
                "Sistema Integral de Reporte de Incidentes - Carabobo",
                style: TextStyle(
                  color: Colors.grey, 
                  fontWeight: FontWeight.w600,
                  fontSize: 16
                ),
              ),
              const SizedBox(height: 40),

              // --- CAMPO CORREO ---
              TextField(
                controller: _userController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Correo Electrónico",
                  prefixIcon: Icon(Icons.email_outlined, color: azulInstitucional),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: naranjaInstitucional, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- CAMPO CONTRASEÑA ---
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Contraseña",
                  prefixIcon: Icon(Icons.lock_outline, color: azulInstitucional),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: naranjaInstitucional, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // --- BOTÓN ENTRAR ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _iniciarSesion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: naranjaInstitucional,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "ENTRAR", 
                        style: TextStyle(
                          fontSize: 18, 
                          color: Colors.white, 
                          fontWeight: FontWeight.bold
                        )
                      ),
                ),
              ),
              
              const SizedBox(height: 25),

              // --- ENLACE A REGISTRO ---
              TextButton(
                onPressed: () { 
                  // Asegúrate de que el nombre de la ruta coincida con tu main.dart
                  Navigator.pushNamed(context, '/register');
                },
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                    children: [
                      const TextSpan(text: "¿No tienes cuenta? "),
                      TextSpan(
                        text: "Regístrate aquí",
                        style: TextStyle(
                          color: azulInstitucional, 
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  @override
void initState() {
  super.initState();
  _revisarSesion();
}

Future<void> _revisarSesion() async {
  final prefs = await SharedPreferences.getInstance();
  final String? userCached = prefs.getString('session_user');
  final String? tokenCached = prefs.getString('session_token');

  if (userCached != null && tokenCached != null) {
    // Si hay sesión, saltamos directo al Dashboard
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context, 
      '/dashboard', 
      arguments: {
        'usuario': jsonDecode(userCached), 
        'token': tokenCached
      }
    );
  }
}
}

 //2. PANTALLA DE REGISTRO CON SECCIÓN LEGAL Y CHECKBOX ---
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidoController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _cedulaController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _esOficial = false;
  bool _aceptoTerminos = false;
  Future<void> _registrarUsuario({required String rol}) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final response = await http.post(
        Uri.parse("$apiUrl/auth/register-app"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "nombre": _nombreController.text,
          "apellido": _apellidoController.text,
          "correo": _correoController.text,
          "cedula": _cedulaController.text,
          "telefono": _telefonoController.text,
          "password": _passController.text,
          "rol": rol,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Registro exitoso! Ahora puedes iniciar sesión.")),
        );
        Navigator.pop(context); // Volver al Login
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? "Error en el registro")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo conectar con el servidor")),
      );
    }
  }
  Future<void> _abrirLey() async {
  final Uri url = Uri.parse('https://www.oas.org/juridico/spanish/mesicic3_ven_anexo18.pdf');
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    throw Exception('No se pudo abrir la ley $url');
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registro de Usuario", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF003194),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Icono o Logo arriba
              Image.asset('assets/images/logo_pc.jpeg', height: 100),
              const SizedBox(height: 20),
              _buildField("Nombre", _nombreController, Icons.person),
              _buildField("Apellido", _apellidoController, Icons.person_outline),
              _buildField("Cédula (V12345678)", _cedulaController, Icons.badge),
              _buildField("Teléfono (04121234567)", _telefonoController, Icons.phone),
              _buildField("Correo Electrónico", _correoController, Icons.email),
              _buildField("Contraseña", _passController, Icons.lock, isPass: true),
              const SizedBox(height: 30),
              SwitchListTile(
  title: const Text("Registrarme como Funcionario Oficial"),
  subtitle: const Text("Se requerirá validación de credenciales por el administrador."),
  value: _esOficial,
  activeColor:const Color(0xFFD32F2F), // Naranja
  onChanged: (bool value) {
    setState(() {
      _esOficial = value;
    });
  },
),
              _buildAvisoLegal(),
              _buildCheckboxLegal(),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _aceptoTerminos ? () => _registrarUsuario(rol: _esOficial ? 'oficial' : 'civil') : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("CREAR CUENTA", 
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {bool isPass = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        obscureText: isPass,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF003194)),
        ),
        validator: (value) => value!.isEmpty ? "Campo requerido" : null,
      ),
    );
  }
  Widget _buildAvisoLegal() {
  return Container(
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.symmetric(vertical: 15),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFD32F2F)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "⚠ ADVERTENCIA LEGAL:",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        const SizedBox(height: 5),
        RichText(
          textAlign: TextAlign.justify,
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 13),
            children: [
              const TextSpan(text: "Hacer reportes falsos o suplantar identidad es un delito. "),
              WidgetSpan(
                child: GestureDetector(
                  onTap: _abrirLey, // Llamamos a la función del PDF
                  child: const Text(
                    " Ver Ley Contra Delitos Informáticos.",
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
Widget _buildCheckboxLegal() {
  return CheckboxListTile(
    title: const Text(
      "He leído y acepto los términos legales y las sanciones por uso indebido de la plataforma.",
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
    ),
    value: _aceptoTerminos,
    activeColor: const Color(0xFF003194), // Azul institucional
    checkColor: Colors.white,
    controlAffinity: ListTileControlAffinity.leading, // Checkbox a la izquierda
    onChanged: (bool? value) {
      setState(() {
        _aceptoTerminos = value ?? false;
      });
    },
  );
}
}

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String token;
  const DashboardScreen({super.key, required this.userData, required this.token});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ignore: unused_field
  bool _isLocating = false;

  // --- LÓGICA DE UBICACIÓN CON FEEDBACK VISUAL ---
  Future<void> _obtenerUbicacionYIrFormulario(BuildContext context, String tipoDestino) async {
    setState(() => _isLocating = true);
    
    // Mostrar un diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFFFF8C00)),
                SizedBox(height: 15),
                Text("Obteniendo ubicación GPS..."),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );

      // Nominatim para reverse geocoding
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1'
      );
      
      final response = await http.get(url, headers: {'User-Agent': 'SIRI_App_Carabobo'});
      
      String municipio = "Valencia";
      String parroquia = "Carabobo";
      String via = "Punto en mapa";

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final addr = data['address'];
        municipio = addr['county'] ?? addr['city'] ?? addr['town'] ?? "Valencia";
        parroquia = addr['suburb'] ?? addr['neighbourhood'] ?? addr['village'] ?? "Sin nombre";
        via = addr['road'] ?? addr['amenity'] ?? addr['pedestrian'] ?? "Vía no identificada";
      }

      if (!mounted) return;
      Navigator.pop(context); // Cerrar el diálogo de carga
      Widget proximaPantalla;
      final datos = {
      'lat': position.latitude,
      'lng': position.longitude,
      'municipio': municipio,
      'parroquia': parroquia,
      'via': via,
      'id_usuario': widget.userData['id'],
      'rol': widget.userData['rol'],
    };
    if (tipoDestino == 'EDAN') {
      proximaPantalla = EdanFormScreen(datosIniciales: datos);
    } else {
      proximaPantalla = FormularioReporte(datosIniciales: datos);
    }
      // Navegar al formulario
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => proximaPantalla,
        ),
      );

    } catch (e) {
      if (mounted) Navigator.pop(context); // Cerrar diálogo
      _showError("Error de GPS: Asegúrese de tener el GPS activo.");
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
    
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String nombre = widget.userData['nombre'] ?? "Usuario";
    final String rol = widget.userData['rol'] ?? "civil";
    final Color azulPC = const Color(0xFF003194);
    final Color naranjaPC = const Color(0xFFD32F2F);

    return Scaffold(
      appBar: AppBar(
        title: const Text("S.I.R.I. Menu", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: azulPC,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('session_user'); // Borramos el caché
  await prefs.remove('session_token');
  if (!mounted) return;
  Navigator.pushReplacementNamed(context, '/');
}
          )
        ],
      ),
      body: Column(
        children: [
          // --- HEADER BIENVENIDA ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: azulPC,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Image.asset('assets/images/IASIEDAGREC.jpeg', height: 60),
                ),
                const SizedBox(height: 15),
                Text(
                  "Bienvenido, $nombre",
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  rol.toUpperCase(),
                  style: TextStyle(color: naranjaPC, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- GRILLA DE ACCIONES ---
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(20),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              children: [
                _buildMenuCard("REPORTAR INCIDENTE", Icons.add_alert_rounded, naranjaPC, 
                  () => _obtenerUbicacionYIrFormulario(context, 'incidentes')
                  ),
                
                _buildMenuCard("MIS REPORTES", 
                Icons.history_rounded,
                Colors.blueGrey, () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => HistorialReportesPage(
                        idUsuario: widget.userData['id'])));
                }),

                _buildMenuCard("MAPA EN VIVO", Icons.map_rounded, Colors.green, () {
                  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const MapaVivoPage()),
  );

                }),
                _buildMenuCard("AJUSTES DE USUARIO", Icons.manage_accounts_rounded, Colors.indigo, () {
                   Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AjustesPage(
          userData: widget.userData, // Pasamos el mapa con nombre, cédula, etc.
          token: widget.token,       // Pasamos el token para el backend
        ),
      ),
    );
                }),
                if (rol == 'oficial') ...[
                  _buildMenuCard("REPORTES E.D.A.N.", Icons.fact_check_rounded, Colors.red.shade700, ()=> _obtenerUbicacionYIrFormulario(context, 'EDAN') ),
                 _buildMenuCard(
          "PENDIENTES POR ENVIAR", 
          Icons.cloud_upload_rounded, 
          Colors.amber.shade800, 
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PendientesScreen(apiUrl: apiUrl),
              ),
            );
          }
        ), ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 5,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
class FormularioReporte extends StatefulWidget {
  final Map<String, dynamic> datosIniciales;
  const FormularioReporte({super.key, required this.datosIniciales});

  @override
  State<FormularioReporte> createState() => _FormularioReporteState();
}

class _FormularioReporteState extends State<FormularioReporte> {
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  List<dynamic> _categorias = [];
  List<dynamic> _tiposFull = []; 
  List<dynamic> _tiposFiltrados = []; 
  XFile? _imagen;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _heridosController = TextEditingController(text: "0");
final TextEditingController _fallecidosController = TextEditingController(text: "0");
  
  String? _idCatSeleccionada;
  String? _idTipoSeleccionado;
  bool _isLoadingData = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  // --- CARGA DE CATEGORÍAS Y TIPOS DESDE EL BACKEND ---
  Future<void> _cargarDatosIniciales() async {
    try {
      final resCat = await http.get(Uri.parse("$apiUrl/incidentes/categorias"));
      final resTipos = await http.get(Uri.parse("$apiUrl/incidentes/tipos"));
      
      if (mounted) {
        setState(() {
          _categorias = jsonDecode(resCat.body);
          _tiposFull = jsonDecode(resTipos.body);
          _tiposFiltrados = _tiposFull;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      _showSnackBar("Error al conectar con el servidor", Colors.red);
    }
  }

  Future<void> _tomarFoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera, 
      imageQuality: 40 // Comprimimos para que la subida sea más rápida
    );
    if (photo != null) setState(() => _imagen = photo);
  }

  // --- ENVÍO DEL REPORTE (MULTIPART) ---
  Future<void> _enviarReporte() async {
    if (_idTipoSeleccionado == null) {
    _showSnackBar("Debe seleccionar un tipo de incidente", Colors.orange);
    return;
  }
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );
    
    setState(() => _isSending = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse("$apiUrl/incidentes/reportar"));

    request.fields['id_de_reportante'] = widget.datosIniciales['id_usuario'].toString(); 
    request.fields['id_tipo'] = _idTipoSeleccionado!.toString();
    request.fields['lat'] = widget.datosIniciales['lat'].toString();
    request.fields['lng'] = widget.datosIniciales['lng'].toString();
    request.fields['municipio'] = widget.datosIniciales['municipio'] ?? "No detectado";
    request.fields['parroquia'] = widget.datosIniciales['parroquia'] ?? "No detectado";
    request.fields['via'] = widget.datosIniciales['via'] ?? "Vía no identificada";
    request.fields['descripcion'] = _descController.text;
    request.fields['afectados'] = "No"; 
    request.fields['heridos_cierre'] = _heridosController.text; // Coincidir con el backend
    request.fields['fallecidos_cierre'] = _fallecidosController.text;
    request.fields['tipo_de_reportante'] = widget.datosIniciales['rol'] == 'oficial' ? 'oficial' : 'ciudadano';
      if (_imagen != null) {
        request.files.add(await http.MultipartFile.fromPath('evidencia', _imagen!.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (mounted) Navigator.pop(context);
      if (response.statusCode == 201 || response.statusCode == 200) {
      _showSnackBar("✅ Reporte enviado exitosamente", Colors.green);
      if (mounted) Navigator.pop(context); // Volver al mapa
    } else {
      // Para debug: ver qué error exacto manda el servidor
      print("Error del servidor: ${response.body}");
      _showSnackBar("Error: ${response.statusCode}", Colors.red);
    }
  } catch (e) {
    if (mounted) Navigator.pop(context); // Cerrar loading en caso de error
    print("Error de red detallado: $e");
    _showSnackBar("Error de conexión. Verifique la IP del servidor.", Colors.red);
  } finally {
    if (mounted) setState(() => _isSending = false);
  }
}

  void _filtrarPorCategoria(String? idCat) {
    setState(() {
      _idCatSeleccionada = idCat;
      _idTipoSeleccionado = null;
      if (idCat == null) {
        _tiposFiltrados = _tiposFull;
      } else {
        _tiposFiltrados = _tiposFull
            .where((t) => t['id_categoria'].toString() == idCat)
            .toList();
      }
    });
  }

void _confirmarDatos() {
  if (_idTipoSeleccionado == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Por favor selecciona un tipo de incidente")),
    );
    return;
  }

  // Buscamos el nombre del tipo seleccionado para mostrarlo en el resumen
  final tipoNombre = _tiposFiltrados.firstWhere(
    (t) => t['id'].toString() == _idTipoSeleccionado,
    orElse: () => {'nombre': 'No seleccionado'},
  )['nombre'];

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Confirmar Reporte"),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              _itemResumen("Ubicación", "${widget.datosIniciales['parroquia']}, ${widget.datosIniciales['municipio']}"),
              _itemResumen("Tipo", tipoNombre),
              _itemResumen("Descripción", _descController.text.isEmpty ? "Sin descripción" : _descController.text),
              _itemResumen("Heridos", _heridosController.text),
              if (widget.datosIniciales['rol']?.toString().toLowerCase().trim() == 'oficial')
                _itemResumen("Fallecidos", _fallecidosController.text),
              _itemResumen("Evidencia", _imagen == null ? "No adjunta" : "Foto lista"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Cierra el diálogo
            child: const Text("CORREGIR", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
           onPressed: _enviarReporte,
  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
  child: const Text("ENVIAR REPORTE", style: TextStyle(color: Colors.white)),
),
        ],
      );
    },
  );
}

// Widget auxiliar para el estilo del resumen
Widget _itemResumen(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(color: Color.fromARGB(255, 255, 255, 255), fontSize: 14),
        children: [
          TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}
  void _buscarIncidente(String query) {
    setState(() {
      _tiposFiltrados = _tiposFull
          .where((t) => t['nombre'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Nuevo Reporte"),
        backgroundColor: const Color(0xFF003194),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("CLASIFICACIÓN DEL EVENTO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            
            // Selector de Categoría
            DropdownButtonFormField<String>(
              value: _idCatSeleccionada,
              decoration: const InputDecoration(labelText: "Filtrar por Categoría", border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text("Todas las categorías")),
                ..._categorias.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['nombre']))),
              ],
              onChanged: _filtrarPorCategoria,
            ),
            const SizedBox(height: 15),

            // Buscador rápido
            if (_idCatSeleccionada == null)
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: "Buscar incidente...",
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: _buscarIncidente,
              ),
            const SizedBox(height: 15),

            // Selector de Tipo de Incidente (Obligatorio)
            DropdownButtonFormField<String>(
              value: (_tiposFiltrados.any((t) => t['id'].toString() == _idTipoSeleccionado)) 
         ? _idTipoSeleccionado 
         : null, 
  decoration: const InputDecoration(labelText: "Tipo de Incidente", border: OutlineInputBorder()),
  items: _tiposFiltrados.map((t) => DropdownMenuItem(
    value: t['id'].toString(), 
    child: Text(t['nombre'])
  )).toList(),
  onChanged: (val) => setState(() { 
    _idTipoSeleccionado = val; 
  }),
            ),
            
            const SizedBox(height: 25),
            const Text("UBICACIÓN DETECTADA", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            
            _buildReadOnlyField("Municipio", widget.datosIniciales['municipio']),
            const SizedBox(height: 10),
            _buildReadOnlyField("Parroquia", widget.datosIniciales['parroquia']),
            const SizedBox(height: 10),
            _buildReadOnlyField("Vía / Referencia", widget.datosIniciales['via']),
            
            const SizedBox(height: 25),
            const Text("DETALLES ADICIONALES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),

            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Describa brevemente lo que observa...",
                border: OutlineInputBorder()
              ),
            ),
            const SizedBox(height: 15),

            // Botón de Foto
            ElevatedButton.icon(
              onPressed: _isSending ? null : _tomarFoto,
              icon: Icon(_imagen == null ? Icons.camera_alt : Icons.check_circle),
              label: Text(_imagen == null ? "TOMAR FOTO EVIDENCIA" : "FOTO ADJUNTA"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _imagen == null ? Colors.blueGrey : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)
              ),
            ),
            const SizedBox(height: 20),
            const Text("AFECTADOS", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
    Expanded(
      child: TextFormField(
        controller: _heridosController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: "Heridos", prefixIcon: Icon(Icons.medical_services)),
      ),
    ),
    // LÓGICA DE ROL: Solo oficiales ven "Fallecidos"
    if (widget.datosIniciales['rol'] == 'oficial') ...[
      const SizedBox(width: 10),
      Expanded(
        child: TextFormField(
          controller: _fallecidosController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Fallecidos"),
        ),
      ),
    ],
  ],
),
            const SizedBox(height: 30),

            // Botón de Envío Final
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: (_isSending || _isLoadingData) ? null : _confirmarDatos,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8C00),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                child: _isSending 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("ENVIAR REPORTE OFICIAL", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return TextField(
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        labelText: label, 
        border: const OutlineInputBorder(), 
        filled: true, 
        fillColor: Colors.grey[100],
        prefixIcon: const Icon(Icons.location_on, size: 20)
      ),
      readOnly: true,
    );
  }
}

class HistorialReportesPage extends StatefulWidget {
  final int idUsuario;
  const HistorialReportesPage({super.key, required this.idUsuario});

  @override
  State<HistorialReportesPage> createState() => _HistorialReportesPageState();
}

class _HistorialReportesPageState extends State<HistorialReportesPage> {
  
  Future<List<dynamic>> _fetchHistorial() async {
    final response = await http.get(Uri.parse("$apiUrl/incidentes/mis-reportes/${widget.idUsuario}"));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al cargar historial');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mis Reportes"), backgroundColor: Colors.orange[800]),
      body: FutureBuilder<List<dynamic>>(
        future: _fetchHistorial(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No has realizado reportes aún."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final reporte = snapshot.data![index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                elevation: 3,
                child: ListTile(
                  leading: _getEstatusIcon(reporte['estatus_incidente']),
                  title: Text("${reporte['nombre_incidente']}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Fecha: ${reporte['created_at'].toString().substring(0, 10)}"),
                      Text("Afectados: ${reporte['afectados']}"),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _mostrarDetalles(reporte),
                
              ));
            },
          );
        },
      ),
    );
  }

  // Widget para mostrar iconos según el estatus
  Widget _getEstatusIcon(String? estatus) {
    switch (estatus) {
      case 'nuevo': return const Icon(Icons.fiber_new, color: Colors.blue);
      case 'en proceso': return const Icon(Icons.access_time, color: Colors.orange);
      case 'resuelto': return const Icon(Icons.check_circle, color: Colors.green);
      default: return const Icon(Icons.report_problem, color: Colors.grey);
    }
  }

  void _mostrarDetalles(dynamic reporte) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reporte['nombre_incidente'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            Text("Descripción: ${reporte['descripcion'] ?? 'Sin detalle'}"),
            const SizedBox(height: 10),
            Text("Heridos: ${reporte['heridos']}"),
            Text("Fallecidos: ${reporte['fallecidos']}"),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cerrar"),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class MapaVivoPage extends StatefulWidget {
  const MapaVivoPage({super.key});

  @override
  State<MapaVivoPage> createState() => _MapaVivoPageState();
}

class _MapaVivoPageState extends State<MapaVivoPage> {
  List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    _cargarPuntos();
  }

  Future<void> _cargarPuntos() async {
    try {
      final response = await http.get(Uri.parse("$apiUrl/incidentes/mapa-global"));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _markers = data.map((item) {
            return Marker(
              point: LatLng(double.parse(item['lat']), double.parse(item['lng'])),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () => _mostrarMiniInfo(item),
                child: Icon(
                  Icons.location_on,
                  color: _getColorPorCategoria(item['categoria']),
                  size: 40,
                ),
              ),
            );
          }).toList();
        });
      }
    } catch (e) {
      print("Error cargando mapa: $e");
    }
  }

  Color _getColorPorCategoria(String? cat) {
    if (cat == null) return Colors.grey;
    if (cat.contains("Vial")) return Colors.orange;
    if (cat.contains("Incendio")) return Colors.red;
    if (cat.contains("Médico")) return Colors.blue;
    return Colors.red;
  }

  void _mostrarMiniInfo(dynamic item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${item['nombre_incidente']} (${item['estatus_incidente']})"),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mapa de Incidentes en Vivo")),
      body: FlutterMap(
        options: MapOptions(
          center: LatLng(10.23, -67.96), // Coordenadas de Carabobo/Valencia
          zoom: 12.0,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: const ['a', 'b', 'c'],
          ),
          MarkerLayer(markers: _markers),
        ],
      ),
    );
  }
}

class AjustesPage extends StatefulWidget {
  final Map<String, dynamic> userData; // Recibe los datos del login
  final String token;

  const AjustesPage({super.key, required this.userData, required this.token});

  @override
  State<AjustesPage> createState() => _AjustesPageState();
}

class _AjustesPageState extends State<AjustesPage> {
  final _formKey = GlobalKey<FormState>();
  
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _loading = false;

  Future<void> _actualizarPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final response = await http.put(
        Uri.parse('$apiUrl/auth/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'currentPassword': _currentPassController.text,
          'newPassword': _newPassController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Contraseña actualizada correctamente")),
        );
        Navigator.pop(context);
      } else {
        throw data['error'] ?? 'Error desconocido';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Perfil y Seguridad")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("DATOS PERSONALES (No editables)", 
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),
              
              // Campos bloqueados
              _buildReadOnlyField("Cédula", widget.userData['cedula'], Icons.badge),
              _buildReadOnlyField("Correo", widget.userData['correo'], Icons.email),
              _buildReadOnlyField("Teléfono", widget.userData['telefono'], Icons.phone),
              
              const Divider(height: 40),
              const Text("SEGURIDAD", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
              const SizedBox(height: 10),

              // Campo Contraseña Actual
              TextFormField(
                controller: _currentPassController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Contraseña Actual",
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) => v!.isEmpty ? "Ingresa tu clave actual" : null,
              ),

              const SizedBox(height: 15),

              // Campo Nueva Contraseña
              TextFormField(
                controller: _newPassController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Nueva Contraseña",
                  prefixIcon: Icon(Icons.vpn_key),
                ),
                validator: (v) => v!.length < 6 ? "Mínimo 6 caracteres" : null,
              ),

              const SizedBox(height: 15),

              // Confirmar Nueva Contraseña
              TextFormField(
                controller: _confirmPassController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Confirmar Nueva Contraseña",
                  prefixIcon: Icon(Icons.check_circle_outline),
                ),
                validator: (v) {
                  if (v != _newPassController.text) return "Las contraseñas no coinciden";
                  return null;
                },
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _actualizarPassword,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
                  child: _loading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("ACTUALIZAR CONTRASEÑA", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        initialValue: value,
        enabled: false, // BLOQUEADO
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.grey.shade200,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}
class PendientesScreen extends StatefulWidget {
  final String apiUrl;
  const PendientesScreen({super.key, required this.apiUrl});

  @override
  State<PendientesScreen> createState() => _PendientesScreenState();
}

class _PendientesScreenState extends State<PendientesScreen> {
  List<Map<String, dynamic>> _pendientes = [];

  @override
  void initState() {
    super.initState();
    _cargarPendientes();
  }

  Future<void> _cargarPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> lista = prefs.getStringList('edan_pendientes') ?? [];
    setState(() {
      _pendientes = lista.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
    });
  }

  Future<void> _sincronizarTodo() async {
    if (_pendientes.isEmpty) return;

    int exitosos = 0;
    List<Map<String, dynamic>> fallidos = [];

    for (var reporte in _pendientes) {
      try {
        final res = await http.post(
          Uri.parse("${widget.apiUrl}/edan/registrar"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(reporte),
        );
        if (res.statusCode == 201) exitosos++;
        else fallidos.add(reporte);
      } catch (e) {
        fallidos.add(reporte);
      }
    }

    // Actualizar almacenamiento local con lo que no se pudo enviar
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('edan_pendientes', fallidos.map((e) => jsonEncode(e)).toList());
    
    _cargarPendientes();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Sincronizados: $exitosos. Fallidos: ${fallidos.length}"))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reportes Pendientes"), backgroundColor: Colors.orange),
      body: _pendientes.isEmpty 
        ? const Center(child: Text("No hay reportes pendientes"))
        : Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: _pendientes.length,
                  itemBuilder: (context, i) => ListTile(
                    leading: const Icon(Icons.description, color: Colors.orange),
                    title: Text("Reporte: ${_pendientes[i]['sector']}"),
                    subtitle: Text("Propietario: ${_pendientes[i]['propetario']}"),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton.icon(
                  onPressed: _sincronizarTodo,
                  icon: const Icon(Icons.sync),
                  label: const Text("SINCRONIZAR AHORA"),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                ),
              )
            ],
          ),
    );
  }
}