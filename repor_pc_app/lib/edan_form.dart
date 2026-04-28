import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String apiUrl = "http://localhost:3000/api"; 

class EdanFormScreen extends StatefulWidget {
  final Map<String, dynamic> datosIniciales;
  const EdanFormScreen({super.key, required this.datosIniciales});

  @override
  State<EdanFormScreen> createState() => _EdanFormScreenState();
}

class _EdanFormScreenState extends State<EdanFormScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  // 1. IDENTIFICACIÓN Y PROPIETARIO
  final _planillaCtrl = TextEditingController();
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
  Future<void> _seleccionarFecha(BuildContext context, TextEditingController controller) async {
  DateTime? picked = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2025), // No necesitamos fechas muy viejas
    lastDate: DateTime(2101),
    locale: const Locale('es', 'ES'), // Si configuraste el soporte de idioma
  );
  
  if (picked != null) {
    setState(() {
      // Formato YYYY-MM-DD (Ej: 2026-04-28)
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
              onStepContinue: () => _currentStep < 4 ? setState(() => _currentStep++) : _enviarEdan(),
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
      _buildTextField(_planillaCtrl, "Nro. Planilla"),
      _buildTextField(_nroInformeCtrl, "Nro. de Informe"),
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
      Text("Municipio: ${widget.datosIniciales['municipio']}", style: const TextStyle(fontWeight: FontWeight.bold)),
      Text("Parroquia: ${widget.datosIniciales['parroquia']}"),
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
      DropdownButtonFormField(
        decoration: const InputDecoration(labelText: "Tipo de Afectación"),
        items: ['anegacion','inundacion','deslizamiento','otros'].map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
        onChanged: (v) => setState(() => _tipoAfectacion = v as String?),
      ),
      if (_tipoAfectacion == 'otros') _buildTextField(_afectacionOtrosCtrl, "Especifique otros"),
      _buildTextField(_descAfectacionCtrl, "Descripción de afectación", maxLines: 2),
      const Divider(),
      DropdownButtonFormField(
        decoration: const InputDecoration(labelText: "Condición Vivienda"),
        items: ['afectada','alto_riesgo','destruida'].map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
        onChanged: (v) => setState(() => _condicionVivienda = v as String?),
      ),
      DropdownButtonFormField(
        decoration: const InputDecoration(labelText: "Tipo de Vivienda"),
        items: ['anarquica','improvisada','casa convencional'].map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
        onChanged: (v) => setState(() => _tipoVivienda = v as String?),
      ),
      _buildTextField(
        _descViviendaCtrl, 
        "Descripción detallada de la vivienda", 
        maxLines: 3,
        icon: Icons.home_work, // Un icono para que se vea mejor
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
          value: gen,
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
  

  Future<void> _enviarEdan() async {
    setState(() => _isLoading = true);
    try {
      final edanData = {
        'id_oficial': widget.datosIniciales['id_usuario'],
        'numero_planilla': _planillaCtrl.text,
        'propetario': _propietarioCtrl.text,
        'p_cedula': _cedulaCtrl.text,
        'P_edad': int.tryParse(_edadCtrl.text) ?? 0,
        'P_telefono': _telefonoCtrl.text,
        'municipio': widget.datosIniciales['municipio'],
        'parroquia': widget.datosIniciales['parroquia'],
        'sector': _sectorCtrl.text,
        'nro_casa': _nroCasaCtrl.text,
        'urbanizacion': _urbCtrl.text,
        'direccion': _direccionCtrl.text,
        'lat': widget.datosIniciales['lat'],
        'lng': widget.datosIniciales['lng'],
        'nro_informe': _nroInformeCtrl.text,
        "fecha_solicitud": _fechaSolicitudCtrl.text,
        "fecha_afectacion": _fechaAfectacionCtrl.text,
        'descripcion_afectacion': _descAfectacionCtrl.text,
        'tipo_afectacion': _tipoAfectacion,
        'afectacion_otros': _afectacionOtrosCtrl.text,
        'condicion_vivienda': _condicionVivienda,
        'tipo_vivienda': _tipoVivienda,
        "descripcion_vivienda": _descViviendaCtrl.text,
        'lact_Fem': lactFem, 'lact_Masc': lactMasc,
        'niños_Fem': ninosFem, 'niños_Masc': ninosMasc,
        'adultos_Fem': adultosFem, 'adultos_Masc': adultosMasc,
        '3era_edad_Fem': terceraFem, '3era_edad_Masc': terceraMasc,
        'discapacitados': discapacitados,
        'total_personas': _totalPersonas,
        'nro_familias': nroFamilias,
        'requerimientos_afectacion': _requerimientosCtrl.text,
        'P_enseres_total': _enseresTotalCtrl.text,
        'P_enseres_parcial': _enseresParcialCtrl.text,
        'p_enseres_no': _enseresNoCtrl.text,
        'necesidades_agua': _necesitaAgua,
        'necesidades_alimentos': _necesitaAlimentos,
        'necesidades_luz': _necesitaLuz,
        'detalles_familiares': _familiares,
      };

      final response = await http.post(
        Uri.parse("$apiUrl/edan/registrar"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(edanData),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("EDAN guardado exitosamente"), backgroundColor: Colors.green));
        Navigator.pop(context);
      } else {
        throw Exception("Error del servidor");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(
    TextEditingController ctrl, 
    String label, 
    {bool isNumber = false, 
    int maxLines = 1, 
    bool readOnly = false, // Para bloquear el teclado
    VoidCallback? onTap,    // Para detectar el toque
    IconData? icon}         // Para el estilo visual
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