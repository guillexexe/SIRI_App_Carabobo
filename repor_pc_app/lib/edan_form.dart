import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const _municipiosCarabobo = [
  'Valencia',
  'Naguanagua',
  'San Diego',
  'Guacara',
  'Mariara',
  'Diego Ibarra',
  'Puerto Cabello',
  'Juan José Mora',
  'Bejuma',
  'Miranda',
  'Montalbán',
  'Carlos Arvelo',
];

String _normalizarTexto(String s) {
  var t = s.trim().toLowerCase();
  const map = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
  };
  map.forEach((k, v) => t = t.replaceAll(k, v));
  return t.replaceAll(RegExp(r'[^a-z0-9\s]'), '').trim();
}

String? _municipioCanonico(String? raw) {
  final mNorm = _normalizarTexto(raw ?? '');
  if (mNorm.isEmpty) return null;
  for (final m in _municipiosCarabobo) {
    if (_normalizarTexto(m) == mNorm) return m;
  }
  for (final m in _municipiosCarabobo) {
    final canon = _normalizarTexto(m);
    if (mNorm.contains(canon) || canon.contains(mNorm)) return m;
  }

  return null;

}



class EdanFormScreen extends StatefulWidget {

  final Map<String, dynamic> datosIniciales;

  final String apiUrl;

  const EdanFormScreen({super.key, required this.datosIniciales, required this.apiUrl});



  @override

  State<EdanFormScreen> createState() => _EdanFormScreenState();

}



class _EdanFormScreenState extends State<EdanFormScreen> {

  int _currentStep = 0;

  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();



  // 1. IDENTIFICACIÓN Y PROPIETARIO

  final _nroPlanillaCtrl = TextEditingController();

  final _nroInformeCtrl = TextEditingController();

  final _propietarioCtrl = TextEditingController();

  final _cedulaCtrl = TextEditingController();

  final _edadCtrl = TextEditingController();

  final _telefonoCtrl = TextEditingController();



  // 2. UBICACIÓN (Algunos vienen de datosIniciales)

  final _sectorCtrl = TextEditingController();

  final _nroCasaCtrl = TextEditingController();

  final _urbCtrl = TextEditingController();

  final _direccionCtrl = TextEditingController();



  // 3. AFECTACIÓN

  final _fechaAfectacionCtrl = TextEditingController();

  final _fechaSolicitudCtrl = TextEditingController();

  final _descAfectacionCtrl = TextEditingController();

  final _afectacionOtrosCtrl = TextEditingController();

  final _descViviendaCtrl = TextEditingController();

  String? _tipoAfectacion; 

  String? _condicionVivienda;

  String? _tipoVivienda;



  // 4. CENSO (Contadores)

  int lactFem = 0, lactMasc = 0, ninosFem = 0, ninosMasc = 0;

  int adultosFem = 0, adultosMasc = 0, terceraFem = 0, terceraMasc = 0;

  int discapacitados = 0, nroFamilias = 1;

  List<Map<String, dynamic>> _familiares = [];



  // 5. REQUERIMIENTOS Y ENSERES

  final _requerimientosCtrl = TextEditingController();

  final _enseresTotalCtrl = TextEditingController();

  final _enseresParcialCtrl = TextEditingController();

  final _enseresNoCtrl = TextEditingController();

  String _necesitaAgua = 'no', _necesitaAlimentos = 'no', _necesitaLuz = 'no';



  int get _totalPersonas => lactFem + lactMasc + ninosFem + ninosMasc + adultosFem + adultosMasc + terceraFem + terceraMasc;



  String get _municipioMostrado =>

      _municipioCanonico(widget.datosIniciales['municipio']?.toString()) ??

      widget.datosIniciales['municipio']?.toString() ??

      '—';



  Future<void> _seleccionarFecha(BuildContext context, TextEditingController controller) async {

  DateTime? picked = await showDatePicker(

    context: context,

    initialDate: DateTime.now(),

    firstDate: DateTime(2025),

    lastDate: DateTime(2101),

    locale: const Locale('es', 'ES'),

  );

  

  if (picked != null) {

    setState(() {

      controller.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";

    });

  }

}



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: const Text("Planilla EDAN Oficial"), backgroundColor: const Color(0xFF003194)),

      body: _isLoading 

        ? const Center(child: CircularProgressIndicator())

        : Form(

            key: _formKey,

            child: Stepper(

              type: StepperType.vertical,

              currentStep: _currentStep,

              onStepContinue: () {

                if (_currentStep < 4) {

                  setState(() => _currentStep++);

                } else {

                  _enviarEdan();

                }

              },

              onStepCancel: () => _currentStep > 0 ? setState(() => _currentStep--) : Navigator.pop(context),

              steps: [

                _stepIdentificacion(),

                _stepUbicacion(),

                _stepAfectacionVivienda(),

                _stepCensoPoblacional(),

                _stepNecesidades(),

              ],

            ),

          ),

    );

  }



  Step _stepIdentificacion() => Step(

    title: const Text("Identificación"),

    content: Column(children: [

      Row(children: [

        Expanded(child: _buildTextField(_nroPlanillaCtrl, "Nº Planilla")),

        const SizedBox(width: 10),

        Expanded(child: _buildTextField(_nroInformeCtrl, "Nº Informe")),

      ]),

      const Divider(),

      _buildTextField(_propietarioCtrl, "Nombre del Propietario"),

      _buildTextField(_cedulaCtrl, "Cédula del Propietario"),

      Row(children: [

        Expanded(child: _buildTextField(_edadCtrl, "Edad", isNumber: true)),

        const SizedBox(width: 10),

        Expanded(child: _buildTextField(_telefonoCtrl, "Teléfono")),

      ]),

    ]),

  );



  Step _stepUbicacion() => Step(

    title: const Text("Ubicación"),

    content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      Text("Municipio: $_municipioMostrado", style: const TextStyle(fontWeight: FontWeight.bold)),

      Text("Parroquia: ${widget.datosIniciales['parroquia']}"),

      if (_municipioCanonico(widget.datosIniciales['municipio']?.toString()) == null)

        const Padding(

          padding: EdgeInsets.only(top: 8),

          child: Text(

            "El municipio del GPS no coincide con Carabobo. El envío puede fallar; use un punto dentro del estado.",

            style: TextStyle(color: Colors.orange, fontSize: 12),

          ),

        ),

      const Divider(),

      _buildTextField(_sectorCtrl, "Sector"),

      _buildTextField(_urbCtrl, "Urbanización / Barrio"),

      _buildTextField(_nroCasaCtrl, "Casa Nº"),

      _buildTextField(_direccionCtrl, "Dirección Exacta", maxLines: 2),

    ]),

  );



  Step _stepAfectacionVivienda() => Step(

    title: const Text("Afectación y Vivienda"),

    content: Column(children: [

      _buildTextField(

        _fechaSolicitudCtrl,

        "Fecha de Solicitud",

        readOnly: true, 

        icon: Icons.calendar_today,

        onTap: () => _seleccionarFecha(context, _fechaSolicitudCtrl),

      ),

      _buildTextField(

        _fechaAfectacionCtrl,

        "Fecha de la Afectación",

        readOnly: true,

        icon: Icons.event_note,

        onTap: () => _seleccionarFecha(context, _fechaAfectacionCtrl),

      ),

      DropdownButtonFormField<String>(

        decoration: const InputDecoration(labelText: "Tipo de Afectación"),

        value: _tipoAfectacion,

        items: ['anegacion','inundacion','deslizamiento','otros']

            .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))

            .toList(),

        onChanged: (v) => setState(() => _tipoAfectacion = v),

      ),

      if (_tipoAfectacion == 'otros') _buildTextField(_afectacionOtrosCtrl, "Especifique otros"),

      _buildTextField(_descAfectacionCtrl, "Descripción de afectación", maxLines: 2),

      const Divider(),

      DropdownButtonFormField<String>(

        decoration: const InputDecoration(labelText: "Condición Vivienda"),

        value: _condicionVivienda,

        items: ['afectada','alto_riesgo','destruida']

            .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))

            .toList(),

        onChanged: (v) => setState(() => _condicionVivienda = v),

      ),

      DropdownButtonFormField<String>(

        decoration: const InputDecoration(labelText: "Tipo de Vivienda"),

        value: _tipoVivienda,

        items: ['anarquica','improvisada','casa convencional']

            .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))

            .toList(),

        onChanged: (v) => setState(() => _tipoVivienda = v),

      ),

      _buildTextField(

        _descViviendaCtrl, 

        "Descripción detallada de la vivienda", 

        maxLines: 3,

        icon: Icons.home_work,

      ),

    ]),

  );



  Step _stepCensoPoblacional() => Step(

    title: const Text("Censo Poblacional"),

    content: Column(children: [

      _buildContador("Lactantes Fem.", lactFem, (v) => setState(() => lactFem = v)),

      _buildContador("Lactantes Masc.", lactMasc, (v) => setState(() => lactMasc = v)),

      _buildContador("Niños Fem.", ninosFem, (v) => setState(() => ninosFem = v)),

      _buildContador("Niños Masc.", ninosMasc, (v) => setState(() => ninosMasc = v)),

      _buildContador("Adultos Fem.", adultosFem, (v) => setState(() => adultosFem = v)),

      _buildContador("Adultos Masc.", adultosMasc, (v) => setState(() => adultosMasc = v)),

      _buildContador("3era Edad Fem.", terceraFem, (v) => setState(() => terceraFem = v)),

      _buildContador("3era Edad Masc.", terceraMasc, (v) => setState(() => terceraMasc = v)),

      _buildContador("Discapacitados", discapacitados, (v) => setState(() => discapacitados = v)),

      _buildContador("Nro. de Familias", nroFamilias, (v) => setState(() => nroFamilias = v)),

      const SizedBox(height: 10),

      Text("Total Personas: $_totalPersonas", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),

      const Divider(),

      const Text("Detalle de Cédulas Familiares", style: TextStyle(fontWeight: FontWeight.bold)),

      ..._familiares.asMap().entries.map((e) => ListTile(

        title: Text(e.value['nombre_completo'] ?? "Familiar"),

        trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _familiares.removeAt(e.key))),

      )),

      TextButton.icon(onPressed: _addFamiliarDialog, icon: const Icon(Icons.person_add), label: const Text("Agregar Familiar")),

    ]),

  );



  Step _stepNecesidades() => Step(

    title: const Text("Necesidades y Enseres"),

    content: Column(children: [

      _buildTextField(_requerimientosCtrl, "Requerimientos por afectación"),

      _buildTextField(_enseresTotalCtrl, "Pérdidas de enseres TOTAL", maxLines: 2),

      _buildTextField(_enseresParcialCtrl, "Pérdidas de enseres PARCIAL"),

      _buildTextField(_enseresNoCtrl, "Enseres NO afectados / Observaciones"),

      const Divider(),

      SwitchListTile(title: const Text("Necesita Agua"), value: _necesitaAgua == 'si', onChanged: (v) => setState(() => _necesitaAgua = v ? 'si' : 'no')),

      SwitchListTile(title: const Text("Necesita Alimentos"), value: _necesitaAlimentos == 'si', onChanged: (v) => setState(() => _necesitaAlimentos = v ? 'si' : 'no')),

      SwitchListTile(title: const Text("Necesita Luz"), value: _necesitaLuz == 'si', onChanged: (v) => setState(() => _necesitaLuz = v ? 'si' : 'no')),

    ]),

  );



  void _addFamiliarDialog() {

    String nombre = '', ced = '', ed = '', gen = 'Masculino';

    showDialog(context: context, builder: (ctx) => AlertDialog(

      title: const Text("Datos Familiar"),

      content: Column(mainAxisSize: MainAxisSize.min, children: [

        TextField(decoration: const InputDecoration(labelText: "Nombre"), onChanged: (v) => nombre = v),

        TextField(decoration: const InputDecoration(labelText: "Cédula"), onChanged: (v) => ced = v),

        TextField(decoration: const InputDecoration(labelText: "Edad"), keyboardType: TextInputType.number, onChanged: (v) => ed = v),

        DropdownButtonFormField(

          decoration: const InputDecoration(labelText: "Género"),

          initialValue: gen,

          items: ['Masculino', 'Femenino', 'Otro'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),

          onChanged: (v) => gen = v as String,

        ),

      ]),

      actions: [TextButton(onPressed: () {

        setState(() => _familiares.add({'nombre_completo': nombre, 'cedula': ced, 'edad': int.tryParse(ed), 'genero': gen}));

        Navigator.pop(ctx);

      }, child: const Text("Añadir"))],

    ));

  }



  String? _validarAntesDeEnviar() {

    if (_nroPlanillaCtrl.text.trim().isEmpty) return 'Indique el Nº de planilla.';

    if (_nroInformeCtrl.text.trim().isEmpty) return 'Indique el Nº de informe.';

    if (_propietarioCtrl.text.trim().isEmpty) return 'Indique el nombre del propietario.';

    if (_cedulaCtrl.text.trim().isEmpty) return 'Indique la cédula del propietario.';

    if (_telefonoCtrl.text.trim().isEmpty) return 'Indique el teléfono.';

    if (_municipioCanonico(widget.datosIniciales['municipio']?.toString()) == null) {

      return 'Municipio no válido para Carabobo. Vuelva a tomar la ubicación GPS.';

    }

    if (_sectorCtrl.text.trim().isEmpty) return 'Indique el sector.';

    if (_direccionCtrl.text.trim().isEmpty) return 'Indique la dirección exacta.';

    if (widget.datosIniciales['parroquia']?.toString().trim().isEmpty ?? true) {

      return 'Falta la parroquia (vuelva a obtener ubicación GPS).';

    }

    if (_fechaSolicitudCtrl.text.trim().isEmpty) return 'Seleccione la fecha de solicitud.';

    if (_fechaAfectacionCtrl.text.trim().isEmpty) return 'Seleccione la fecha de afectación.';

    if (_tipoAfectacion == null) return 'Seleccione el tipo de afectación.';

    if (_tipoAfectacion == 'otros' && _afectacionOtrosCtrl.text.trim().isEmpty) {

      return 'Especifique el tipo de afectación (otros).';

    }

    if (_condicionVivienda == null) return 'Seleccione la condición de la vivienda.';

    if (_tipoVivienda == null) return 'Seleccione el tipo de vivienda.';

    if (_descAfectacionCtrl.text.trim().isEmpty) return 'Describa la afectación.';

    if (_descViviendaCtrl.text.trim().isEmpty) return 'Describa la vivienda.';

    if (_requerimientosCtrl.text.trim().isEmpty) return 'Indique los requerimientos por afectación.';

    if (_enseresTotalCtrl.text.trim().isEmpty) return 'Indique pérdidas de enseres TOTAL (use "Ninguna" si aplica).';

    if (_enseresParcialCtrl.text.trim().isEmpty) return 'Indique pérdidas de enseres PARCIAL (use "Ninguna" si aplica).';

    if (_enseresNoCtrl.text.trim().isEmpty) return 'Indique enseres no afectados u observaciones.';

  final idOficial = int.tryParse(widget.datosIniciales['id_usuario']?.toString() ?? '');

    if (idOficial == null || idOficial < 1) return 'Sesión inválida: vuelva a iniciar sesión como oficial.';

    return null;

  }



  Future<void> _enviarEdan() async {

    final errorValidacion = _validarAntesDeEnviar();

    if (errorValidacion != null) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text(errorValidacion), backgroundColor: Colors.red.shade800),

      );

      return;

    }



    setState(() => _isLoading = true);



    final municipio = _municipioCanonico(widget.datosIniciales['municipio']?.toString())!;

    final idOficial = int.parse(widget.datosIniciales['id_usuario'].toString());

    

    final edanData = {

        'id_oficial': idOficial,

        'numero_planilla': _nroPlanillaCtrl.text.trim(),

        'propetario': _propietarioCtrl.text.trim(),

        'p_cedula': _cedulaCtrl.text.trim(),

        'P_edad': int.tryParse(_edadCtrl.text) ?? 0,

        'P_telefono': _telefonoCtrl.text.trim(),

        'municipio': municipio,

        'parroquia': widget.datosIniciales['parroquia'].toString().trim(),

        'sector': _sectorCtrl.text.trim(),

        'nro_casa': _nroCasaCtrl.text.trim(),

        'urbanizacion': _urbCtrl.text.trim(),

        'direccion': _direccionCtrl.text.trim(),

        'lat': widget.datosIniciales['lat'],

        'lng': widget.datosIniciales['lng'],

        'nro_informe': _nroInformeCtrl.text.trim(),

        'fecha_solicitud': _fechaSolicitudCtrl.text,

        'fecha_afectacion': _fechaAfectacionCtrl.text,

        'descripcion_afectacion': _descAfectacionCtrl.text.trim(),

        'tipo_afectacion': _tipoAfectacion,

        'afectacion_otros': _afectacionOtrosCtrl.text.trim(),

        'condicion_vivienda': _condicionVivienda,

        'tipo_vivienda': _tipoVivienda,

        'descripcion_vivienda': _descViviendaCtrl.text.trim(),

        'lact_Fem': lactFem, 'lact_Masc': lactMasc,

        'ninos_Fem': ninosFem, 'ninos_Masc': ninosMasc,

        'adultos_Fem': adultosFem, 'adultos_Masc': adultosMasc,

        '3era_edad_Fem': terceraFem, '3era_edad_Masc': terceraMasc,

        'discapacitados': discapacitados,

        'total_personas': _totalPersonas,

        'nro_familias': nroFamilias,

        'requerimientos_afectacion': _requerimientosCtrl.text.trim(),

        'P_enseres_total': _enseresTotalCtrl.text.trim(),

        'P_enseres_parcial': _enseresParcialCtrl.text.trim(),

        'p_enseres_no': _enseresNoCtrl.text.trim(),

        'necesidades_agua': _necesitaAgua,

        'necesidades_alimentos': _necesitaAlimentos,

        'necesidades_luz': _necesitaLuz,

        'detalles_familiares': _familiares,

      };



    try {

      final response = await http.post(

        Uri.parse("${widget.apiUrl}/edan/registrar"),

        headers: {"Content-Type": "application/json"},

        body: jsonEncode(edanData),

      ).timeout(const Duration(seconds: 10));



      if (response.statusCode == 201) {

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text("EDAN guardado exitosamente en el servidor"), backgroundColor: Colors.green)

        );

        Navigator.pop(context);

      } else if (response.statusCode == 400) {

        String mensaje = 'Datos inválidos';

        try {

          final decoded = jsonDecode(response.body);

          if (decoded is Map && decoded['error'] != null) {

            mensaje = decoded['error'].toString();

          }

        } catch (_) {

          mensaje = response.body.isNotEmpty ? response.body : mensaje;

        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Text("Error en planilla: $mensaje"),

            backgroundColor: Colors.red.shade800,

            duration: const Duration(seconds: 6),

          ),

        );

      } else {

        throw Exception("Error del servidor (${response.statusCode})");

      }

    } catch (e) {

      await _guardarLocalmente(edanData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text(

            "Sin conexión con el servidor ($e). Reporte respaldado en 'Pendientes'.",

          ),

          backgroundColor: Colors.orange,

          duration: const Duration(seconds: 5),

        ),

      );

      Navigator.pop(context);

    } finally {

      if (mounted) setState(() => _isLoading = false);

    }

  }



  Future<void> _guardarLocalmente(Map<String, dynamic> data) async {

  final prefs = await SharedPreferences.getInstance();

  List<String> pendientes = prefs.getStringList('edan_pendientes') ?? [];

  pendientes.add(jsonEncode(data));

  await prefs.setStringList('edan_pendientes', pendientes);

}



  Widget _buildTextField(

    TextEditingController ctrl, 

    String label, 

    {bool isNumber = false, 

    int maxLines = 1, 

    bool readOnly = false,

    VoidCallback? onTap,

    IconData? icon}

  ) {

    return Padding(

      padding: const EdgeInsets.symmetric(vertical: 8),

      child: TextFormField(

        controller: ctrl,

        readOnly: readOnly,

        onTap: onTap,

        keyboardType: isNumber ? TextInputType.number : TextInputType.text,

        maxLines: maxLines,

        decoration: InputDecoration(

          labelText: label,

          prefixIcon: icon != null ? Icon(icon, color: Colors.orange.shade900) : null,

          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),

        ),

      ),

    );

  }



  Widget _buildContador(String label, int value, Function(int) onChanged) {

    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [

      Text(label),

      Row(children: [

        IconButton(icon: const Icon(Icons.remove), onPressed: () => onChanged(value > 0 ? value - 1 : 0)),

        Text("$value"),

        IconButton(icon: const Icon(Icons.add), onPressed: () => onChanged(value + 1)),

      ])

    ]);

  }

}


