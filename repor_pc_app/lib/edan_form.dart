import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'footer.dart';

const int _maxCensoPorCampo = 10;
const int _maxEdad = 130;
final RegExp _cedulaRegex = RegExp(r'^[VJE]\d{6,10}$', caseSensitive: false);
final RegExp _telefonoRegex = RegExp(r'^04\d{2}-\d{7}$');

class _CedulaVeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.toUpperCase();
    if (raw.isEmpty) return newValue;
    final first = raw[0];
    if (!RegExp(r'^[VJE]$').hasMatch(first)) return oldValue;
    final digits = raw.length > 1 ? raw.substring(1) : '';
    if (digits.isNotEmpty && !RegExp(r'^\d*$').hasMatch(digits)) return oldValue;
    final text = first + digits;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _SoloDigitosFormatter extends TextInputFormatter {
  final int? maxLength;
  const _SoloDigitosFormatter({this.maxLength});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final text = maxLength != null && digits.length > maxLength!
        ? digits.substring(0, maxLength!)
        : digits;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

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

class _TelefonoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll('-', ''); // Quitar guiones existentes
    if (text.length > 11) text = text.substring(0, 11); // Limitar longitud

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 4) buffer.write('-'); // Insertar guion en la posición correcta
      buffer.write(text[i]);
    }

    final String formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
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
  //final _nroPlanillaCtrl = TextEditingController();
  //final _nroInformeCtrl = TextEditingController();
  final _propietarioCtrl = TextEditingController();
  final _cedulaCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  // 2. UBICACIÓN (Algunos vienen de datosIniciales)
  final _sectorCtrl = TextEditingController();
  final _nroCasaCtrl = TextEditingController();
  final _urbCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _fechaAfectacionCtrl = TextEditingController();
  final _fechaSolicitudCtrl = TextEditingController();
  final _descAfectacionCtrl = TextEditingController();
  final _afectacionOtrosCtrl = TextEditingController();
  final _descViviendaCtrl = TextEditingController();
  String? _tipoAfectacion; 
  String? _condicionVivienda;
  String? _tipoVivienda;
  int lactFem = 0, lactMasc = 0, ninosFem = 0, ninosMasc = 0;
  int adultosFem = 0, adultosMasc = 0, terceraFem = 0, terceraMasc = 0;
  int discapacitados = 0, nroFamilias = 1;
  List<Map<String, dynamic>> _familiares = [];
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
  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade800),
    );
  }

  DateTime? _parseFecha(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return DateTime.tryParse(t);
  }

  String? _validarOrdenFechas() {
    final afectacion = _parseFecha(_fechaAfectacionCtrl.text);
    final solicitud = _parseFecha(_fechaSolicitudCtrl.text);
    if (afectacion == null || solicitud == null) return null;
    if (solicitud.isBefore(afectacion)) {
      return 'La fecha de solicitud no puede ser anterior a la fecha de afectación.';
    }
    return null;
  }

  Future<void> _seleccionarFecha(BuildContext context, TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) {
      setState(() {
        controller.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
      final err = _validarOrdenFechas();
      if (err != null) _mostrarError(err);
    }
  }

  String? _validarCedula(String? v, {String campo = 'cédula'}) {
    final t = (v ?? '').trim().toUpperCase();
    if (t.isEmpty) return 'Indique la $campo.';
    if (!_cedulaRegex.hasMatch(t)) {
      return 'La $campo debe iniciar con V, J o E y luego solo números (ej: V12345678).';
    }
    return null;
  }

  String? _validarTelefono(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Indique el teléfono.';
    if (!_telefonoRegex.hasMatch(t)) {
      return 'Formato inválido. Debe ser 04XX-XXXXXXX';
    }
    return null;
  }

  String? _validarEdad(String? v, {bool obligatoria = false}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return obligatoria ? 'Indique la edad.' : null;
    final n = int.tryParse(t);
    if (n == null) return 'La edad debe ser un número entero.';
    if (n < 0 || n > _maxEdad) return 'La edad debe estar entre 0 y $_maxEdad años.';
    return null;
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
                final err = _validarPaso(_currentStep);
                if (err != null) {
                  _mostrarError(err);
                  return;
                }
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
       bottomNavigationBar: const Footer(),   
    );
  }
  Step _stepIdentificacion() => Step(
    title: const Text("Identificación"),
    content: Column(children: [
      ///Row(children: [
      ///  Expanded(child: _buildTextField(_nroPlanillaCtrl, "Nº Planilla")),
      ///  const SizedBox(width: 10),
      /// Expanded(child: _buildTextField(_nroInformeCtrl, "Nº Informe")),
      ///]),
      const Divider(),
      _buildTextField(_propietarioCtrl, "Nombre del Propietario"),
      _buildTextField(
        _cedulaCtrl,
        "Cédula del Propietario",
        hint: "V12345678 (V, J o E + números)",
        inputFormatters: [_CedulaVeFormatter()],
        textCapitalization: TextCapitalization.characters,
      ),
      Row(children: [
        Expanded(
          child: _buildTextField(
            _edadCtrl,
            "Edad",
            hint: "0–$_maxEdad",
            inputFormatters: [_SoloDigitosFormatter(maxLength: 3)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildTextField(
            _telefonoCtrl,
            "Teléfono",
            hint: "04XX-XXXXXXX",
  inputFormatters: [_TelefonoFormatter()],
          ),
        ),
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
        _fechaAfectacionCtrl,
        "Fecha de la Afectación",
        readOnly: true,
        icon: Icons.event_note,
        onTap: () => _seleccionarFecha(context, _fechaAfectacionCtrl),
      ),
      _buildTextField(
        _fechaSolicitudCtrl,
        "Fecha de Solicitud",
        readOnly: true,
        icon: Icons.calendar_today,
        onTap: () => _seleccionarFecha(context, _fechaSolicitudCtrl),
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
      Text(
        "Al sumar (+) debe registrar los datos de cada persona. Máx. $_maxCensoPorCampo por categoría.",
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
      const SizedBox(height: 8),
      _buildContador("Lactantes Fem.", 'lact_fem', lactFem),
      _buildContador("Lactantes Masc.", 'lact_masc', lactMasc),
      _buildContador("Niños Fem.", 'ninos_fem', ninosFem),
      _buildContador("Niños Masc.", 'ninos_masc', ninosMasc),
      _buildContador("Adultos Fem.", 'adultos_fem', adultosFem),
      _buildContador("Adultos Masc.", 'adultos_masc', adultosMasc),
      _buildContador("3era Edad Fem.", 'tercera_fem', terceraFem),
      _buildContador("3era Edad Masc.", 'tercera_masc', terceraMasc),
      _buildContador("Discapacitados", 'discapacitados', discapacitados),
      _buildContadorFamilias(),
      const SizedBox(height: 10),
      Text("Total Personas: $_totalPersonas", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
      const Divider(),
      const Text("Detalle de Cédulas Familiares", style: TextStyle(fontWeight: FontWeight.bold)),
      ..._familiares.asMap().entries.map((e) {
        final f = e.value;
        final grupoLabel = _labelGrupo(f['grupo']?.toString() ?? '');
        return ListTile(
          title: Text(f['nombre_completo'] ?? "Familiar"),
          subtitle: Text("${f['cedula'] ?? ''} · $grupoLabel"),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _eliminarFamiliar(e.key),
          ),
        );
      }),
      if (_familiares.length < _totalPersonas)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            "Faltan ${_totalPersonas - _familiares.length} persona(s) por registrar en el censo.",
            style: const TextStyle(color: Colors.orange, fontSize: 12),
          ),
        ),
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
  String _labelGrupo(String grupo) {
    const labels = {
      'lact_fem': 'Lactante Fem.',
      'lact_masc': 'Lactante Masc.',
      'ninos_fem': 'Niño Fem.',
      'ninos_masc': 'Niño Masc.',
      'adultos_fem': 'Adulto Fem.',
      'adultos_masc': 'Adulto Masc.',
      'tercera_fem': '3era Edad Fem.',
      'tercera_masc': '3era Edad Masc.',
      'discapacitados': 'Discapacitado',
    };
    return labels[grupo] ?? grupo;
  }

  void _setContadorGrupo(String grupo, int value) {
    switch (grupo) {
      case 'lact_fem': lactFem = value; break;
      case 'lact_masc': lactMasc = value; break;
      case 'ninos_fem': ninosFem = value; break;
      case 'ninos_masc': ninosMasc = value; break;
      case 'adultos_fem': adultosFem = value; break;
      case 'adultos_masc': adultosMasc = value; break;
      case 'tercera_fem': terceraFem = value; break;
      case 'tercera_masc': terceraMasc = value; break;
      case 'discapacitados': discapacitados = value; break;
    }
  }

  int _getContadorGrupo(String grupo) {
    switch (grupo) {
      case 'lact_fem': return lactFem;
      case 'lact_masc': return lactMasc;
      case 'ninos_fem': return ninosFem;
      case 'ninos_masc': return ninosMasc;
      case 'adultos_fem': return adultosFem;
      case 'adultos_masc': return adultosMasc;
      case 'tercera_fem': return terceraFem;
      case 'tercera_masc': return terceraMasc;
      case 'discapacitados': return discapacitados;
      default: return 0;
    }
  }

  Future<void> _incrementarCenso(String grupo, String label) async {
    final actual = _getContadorGrupo(grupo);
    if (actual >= _maxCensoPorCampo) {
      _mostrarError('Máximo $_maxCensoPorCampo personas en "$label".');
      return;
    }
    final persona = await _addFamiliarDialog(grupo: grupo, titulo: label);
    if (persona != null) {
      setState(() {
        _familiares.add(persona);
        _setContadorGrupo(grupo, actual + 1);
      });
    }
  }

  void _decrementarCenso(String grupo) {
    final actual = _getContadorGrupo(grupo);
    if (actual <= 0) return;
    setState(() {
      final idx = _familiares.lastIndexWhere((f) => f['grupo'] == grupo);
      if (idx >= 0) _familiares.removeAt(idx);
      _setContadorGrupo(grupo, actual - 1);
    });
  }

  void _eliminarFamiliar(int index) {
    if (index < 0 || index >= _familiares.length) return;
    final grupo = _familiares[index]['grupo']?.toString();
    setState(() {
      _familiares.removeAt(index);
      if (grupo != null) {
        final actual = _getContadorGrupo(grupo);
        if (actual > 0) _setContadorGrupo(grupo, actual - 1);
      }
    });
  }

  Future<Map<String, dynamic>?> _addFamiliarDialog({
    required String grupo,
    required String titulo,
  }) async {
    final nombreCtrl = TextEditingController();
    final cedulaCtrl = TextEditingController();
    final edadCtrl = TextEditingController();
    String gen = 'Masculino';

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text("Datos — $titulo"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: "Nombre completo"),
                textCapitalization: TextCapitalization.words,
              ),
              TextField(
                controller: cedulaCtrl,
                decoration: const InputDecoration(
                  labelText: "Cédula",
                  hintText: "V12345678",
                ),
                inputFormatters: [_CedulaVeFormatter()],
                textCapitalization: TextCapitalization.characters,
              ),
              TextField(
                controller: edadCtrl,
                decoration: InputDecoration(labelText: "Edad (0–$_maxEdad)"),
                keyboardType: TextInputType.number,
                inputFormatters: [_SoloDigitosFormatter(maxLength: 3)],
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Género"),
                initialValue: gen,
                items: ['Masculino', 'Femenino', 'Otro']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => gen = v ?? gen,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              final nombre = nombreCtrl.text.trim();
              final cedula = cedulaCtrl.text.trim().toUpperCase();
              final errCed = _validarCedula(cedula, campo: 'cédula del familiar');
              final errEdad = _validarEdad(edadCtrl.text, obligatoria: true);
              if (nombre.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text("Indique el nombre del familiar.")),
                );
                return;
              }
              if (errCed != null) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(errCed)));
                return;
              }
              if (errEdad != null) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(errEdad)));
                return;
              }
              Navigator.pop(ctx, {
                'nombre_completo': nombre,
                'cedula': cedula,
                'edad': int.parse(edadCtrl.text.trim()),
                'genero': gen,
                'grupo': grupo,
              });
            },
            child: const Text("Añadir"),
          ),
        ],
      ),
    );
  }

  String? _validarPaso(int paso) {
    switch (paso) {
      case 0:
        ///if (_nroPlanillaCtrl.text.trim().isEmpty) return 'Indique el Nº de planilla.';
        ///if (_nroInformeCtrl.text.trim().isEmpty) return 'Indique el Nº de informe.';
        if (_propietarioCtrl.text.trim().isEmpty) return 'Indique el nombre del propietario.';
        final errCed = _validarCedula(_cedulaCtrl.text);
        if (errCed != null) return errCed;
        final errEdad = _validarEdad(_edadCtrl.text, obligatoria: true);
        if (errEdad != null) return errEdad;
        final errTel = _validarTelefono(_telefonoCtrl.text);
        if (errTel != null) return errTel;
        return null;
      case 1:
        if (_municipioCanonico(widget.datosIniciales['municipio']?.toString()) == null) {
          return 'Municipio no válido para Carabobo. Vuelva a tomar la ubicación GPS.';
        }
        if (_sectorCtrl.text.trim().isEmpty) return 'Indique el sector.';
        if (_direccionCtrl.text.trim().isEmpty) return 'Indique la dirección exacta.';
        if (widget.datosIniciales['parroquia']?.toString().trim().isEmpty ?? true) {
          return 'Falta la parroquia (vuelva a obtener ubicación GPS).';
        }
        return null;
      case 2:
        if (_fechaAfectacionCtrl.text.trim().isEmpty) return 'Seleccione la fecha de afectación.';
        if (_fechaSolicitudCtrl.text.trim().isEmpty) return 'Seleccione la fecha de solicitud.';
        final errFechas = _validarOrdenFechas();
        if (errFechas != null) return errFechas;
        if (_tipoAfectacion == null) return 'Seleccione el tipo de afectación.';
        if (_tipoAfectacion == 'otros' && _afectacionOtrosCtrl.text.trim().isEmpty) {
          return 'Especifique el tipo de afectación (otros).';
        }
        if (_condicionVivienda == null) return 'Seleccione la condición de la vivienda.';
        if (_tipoVivienda == null) return 'Seleccione el tipo de vivienda.';
        if (_descAfectacionCtrl.text.trim().isEmpty) return 'Describa la afectación.';
        if (_descViviendaCtrl.text.trim().isEmpty) return 'Describa la vivienda.';
        return null;
      case 3:
        if (_totalPersonas < 1) return 'Registre al menos una persona afectada en el censo.';
        if (nroFamilias < 1) return 'Indique al menos 1 familia.';
        if (nroFamilias > _maxCensoPorCampo) return 'Máximo $_maxCensoPorCampo familias.';
        if (_familiares.length != _totalPersonas) {
          return 'Debe registrar los datos de las $_totalPersonas persona(s) del censo (faltan ${_totalPersonas - _familiares.length}).';
        }
        return null;
      case 4:
        if (_requerimientosCtrl.text.trim().isEmpty) return 'Indique los requerimientos por afectación.';
        if (_enseresTotalCtrl.text.trim().isEmpty) {
          return 'Indique pérdidas de enseres TOTAL (use "Ninguna" si aplica).';
        }
        if (_enseresParcialCtrl.text.trim().isEmpty) {
          return 'Indique pérdidas de enseres PARCIAL (use "Ninguna" si aplica).';
        }
        if (_enseresNoCtrl.text.trim().isEmpty) return 'Indique enseres no afectados u observaciones.';
        final idOficial = int.tryParse(widget.datosIniciales['id_usuario']?.toString() ?? '');
        if (idOficial == null || idOficial < 1) {
          return 'Sesión inválida: vuelva a iniciar sesión como oficial.';
        }
        return null;
      default:
        return null;
    }
  }

  String? _validarAntesDeEnviar() {
    for (var paso = 0; paso <= 4; paso++) {
      final err = _validarPaso(paso);
      if (err != null) return err;
    }
    return null;
  }

  Future<void> _enviarEdan() async {
    final errorValidacion = _validarAntesDeEnviar();
    if (errorValidacion != null) {
      _mostrarError(errorValidacion);
      return;
    }

    setState(() => _isLoading = true);
    final municipio = _municipioCanonico(widget.datosIniciales['municipio']?.toString())!;
    final idOficial = int.parse(widget.datosIniciales['id_usuario'].toString());
    final edanData = {
        'id_oficial': idOficial,
        /// 'numero_planilla': _nroPlanillaCtrl.text.trim(),
        'propetario': _propietarioCtrl.text.trim(),
        'p_cedula': _cedulaCtrl.text.trim().toUpperCase(),
        'P_edad': int.parse(_edadCtrl.text.trim()),
        'P_telefono': _telefonoCtrl.text.trim(),
        'municipio': municipio,
        'parroquia': widget.datosIniciales['parroquia'].toString().trim(),
        'sector': _sectorCtrl.text.trim(),
        'nro_casa': _nroCasaCtrl.text.trim(),
        'urbanizacion': _urbCtrl.text.trim(),
        'direccion': _direccionCtrl.text.trim(),
        'lat': widget.datosIniciales['lat'],
        'lng': widget.datosIniciales['lng'],
        ///'nro_informe': _nroInformeCtrl.text.trim(),
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
        'detalles_familiares': _familiares.map((f) => {
          'nombre_completo': f['nombre_completo'],
          'cedula': f['cedula'],
          'edad': f['edad'],
          'genero': f['genero'],
        }).toList(),
      };
      
    try {
      print("Payload enviado a registrar: ${json.encode(edanData)}");
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
    String label, {
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    IconData? icon,
    String? hint,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: ctrl,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        keyboardType: inputFormatters != null && inputFormatters.any((f) => f is _SoloDigitosFormatter)
            ? TextInputType.number
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, color: Colors.orange.shade900) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildContador(String label, String grupo, int value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(child: Text(label)),
      Row(children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: value > 0 ? () => setState(() => _decrementarCenso(grupo)) : null,
        ),
        Text("$value"),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: value < _maxCensoPorCampo
              ? () => _incrementarCenso(grupo, label)
              : null,
        ),
      ]),
    ]);
  }

  Widget _buildContadorFamilias() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Expanded(child: Text("Nro. de Familias")),
      Row(children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: nroFamilias > 1 ? () => setState(() => nroFamilias--) : null,
        ),
        Text("$nroFamilias"),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: nroFamilias < _maxCensoPorCampo ? () => setState(() => nroFamilias++) : null,
        ),
      ]),
    ]);
  }
}