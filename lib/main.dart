import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:io';

void main() {
  runApp(const VisitaTecnicaApp());
}

class VisitaTecnicaApp extends StatelessWidget {
  const VisitaTecnicaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visita Técnica v1.0',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// BANCO DE DADOS SQLITE
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('visitas.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    const dbName = 'visitas.db';
    final path = join(dbPath, dbName);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE visitas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        equipamento TEXT,
        numeroSerie TEXT,
        numeroSIOM TEXT,
        tipoEquipamento TEXT,
        tipoMidia TEXT,
        dataBateria TEXT,
        dataValidade TEXT,
        statusBateria TEXT,
        dataVisita TEXT,
        latitude TEXT,
        longitude TEXT,
        observacao TEXT
      )
    ''');
  }

  Future<int> insertVisita(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('visitas', row);
  }

  Future<List<Map<String, dynamic>>> queryAllVisitas() async {
    final db = await instance.database;
    return await db.query('visitas', orderBy: 'id DESC');
  }
}

// TELA INICIAL
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visita Técnica v1.0')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Novo Cadastro de Visita'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CadastroScreen())),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('Consultar Equipamentos'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsultaScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

// TELA DE CADASTRO
class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _equipamentoController = TextEditingController();
  final _serieController = TextEditingController();
  final _siomController = TextEditingController();
  final _obsController = TextEditingController();

  String _tipoEquipamento = 'Regulador';
  String _tipoMidia = 'Rádio';
  DateTime _dataBateria = DateTime.now();
  DateTime _dataVisita = DateTime.now();
  String _lat = '';
  String _lng = '';

  Future<void> _capturarLocalizacao() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _lat = position.latitude.toString();
      _lng = position.longitude.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    DateTime validade = DateTime(_dataBateria.year + 2, _dataBateria.month, _dataBateria.day);
    int diffDays = validade.difference(DateTime.now()).inDays;
    
    String status = 'EM DIA';
    Color statusColor = Colors.green;
    if (diffDays < 0) {
      status = 'VENCIDA';
      statusColor = Colors.red;
    } else if (diffDays <= 90) {
      status = 'VENCE EM ATÉ 90 DIAS';
      statusColor = Colors.amber;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nova Visita Técnica')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(controller: _equipamentoController, decoration: const InputDecoration(labelText: 'Equipamento')),
              TextFormField(controller: _serieController, decoration: const InputDecoration(labelText: 'Número de Série')),
              TextFormField(controller: _siomController, decoration: const InputDecoration(labelText: 'Número SIOM')),
              DropdownButtonFormField(
                value: _tipoEquipamento,
                items: const [DropdownMenuItem(value: 'Regulador', child: Text('Regulador')), DropdownMenuItem(value: 'Religador', child: Text('Religador'))],
                onChanged: (val) => setState(() => _tipoEquipamento = val!),
                decoration: const InputDecoration(labelText: 'Tipo de Equipamento'),
              ),
              DropdownButtonFormField(
                value: _tipoMidia,
                items: const [DropdownMenuItem(value: 'Rádio', child: Text('Rádio')), DropdownMenuItem(value: 'Modem', child: Text('Modem')), DropdownMenuItem(value: 'Satélite', child: Text('Satélite'))],
                onChanged: (val) => setState(() => _tipoMidia = val!),
                decoration: const InputDecoration(labelText: 'Tipo de Mídia'),
              ),
              ListTile(
                title: Text('Data da Bateria: ${DateFormat('dd/MM/yyyy').format(_dataBateria)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  DateTime? picked = await showDatePicker(context: context, initialDate: _dataBateria, firstDate: DateTime(2015), lastDate: DateTime(2035));
                  if (picked != null) setState(() => _dataBateria = picked);
                },
              ),
              Text('Validade: ${DateFormat('dd/MM/yyyy').format(validade)}'),
              Container(padding: const EdgeInsets.all(8), color: statusColor.withOpacity(0.2), child: Text('Status: $status', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold))),
              TextFormField(controller: _obsController, maxLength: 200, decoration: const InputDecoration(labelText: 'Observação')),
              ElevatedButton.icon(icon: const Icon(Icons.gps_fixed), label: Text(_lat.isEmpty ? 'Capturar Localização' : 'GPS Capturado'), onPressed: _capturarLocalizacao),
              ElevatedButton(
                child: const Text('Salvar'),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    await DatabaseHelper.instance.insertVisita({
                      'equipamento': _equipamentoController.text,
                      'numeroSerie': _serieController.text,
                      'numeroSIOM': _siomController.text,
                      'tipoEquipamento': _tipoEquipamento,
                      'tipoMidia': _tipoMidia,
                      'dataBateria': DateFormat('dd/MM/yyyy').format(_dataBateria),
                      'dataValidade': DateFormat('dd/MM/yyyy').format(validade),
                      'statusBateria': status,
                      'dataVisita': DateFormat('dd/MM/yyyy').format(_dataVisita),
                      'latitude': _lat,
                      'longitude': _lng,
                      'observacao': _obsController.text,
                    });
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// TELA DE CONSULTA
class ConsultaScreen extends StatelessWidget {
  const ConsultaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consultar Equipamentos')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper.instance.queryAllVisitas(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final visitas = snapshot.data!;
          if (visitas.isEmpty) return const Center(child: Text('Nenhuma visita cadastrada.'));
          return ListView.builder(
            itemCount: visitas.itemsCount, // ajuste simples
            itemBuilder: (context, index) {
              final v = visitas[index];
              return ListTile(
                title: Text('${v['equipamento']} - SIOM: ${v['numeroSIOM']}'),
                subtitle: Text('Data: ${v['dataVisita']} | Status: ${v['statusBateria']}'),
              );
            },
          );
        },
      ),
    );
  }
}
