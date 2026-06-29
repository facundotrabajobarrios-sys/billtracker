import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/bill_service.dart';
import '../models/bill.dart';

// 📄 Pantalla para agregar/editar factura
class AddBillScreen extends StatefulWidget {
  final Bill? bill; // ✅ Si viene con datos, es edición

  const AddBillScreen({super.key, this.bill});

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _billService = BillService();

  // 🔤 Controladores
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  // 🏢 Controlador para nuevo servicio
  final _newServiceController = TextEditingController();
  // 📅 Variables
  String? _selectedServiceId;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'pending';
  bool _isRecurring = false;
  int _reminderDays = 3;
  bool _isLoading = false;
  bool _isAddingService = false;
  bool _isEditing = false; // ✅ Bandera para saber si es edición

  // 📋 Listas
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.bill != null;
    if (_isEditing) {
      _loadBillData(); // ✅ Cargar datos de la factura a editar
    }
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _newServiceController.dispose();
    super.dispose();
  }

  // 📥 Cargar datos de la factura a editar
  void _loadBillData() {
    final bill = widget.bill!;
    _selectedServiceId = bill.serviceId;
    _selectedCategoryId = bill.categoryId;
    _amountController.text = bill.amount.toString();
    _selectedDate = bill.dueDate;
    _selectedStatus = bill.status;
    _isRecurring = bill.isRecurring;
    _reminderDays = bill.reminderDays ?? 3;
    if (bill.description != null) {
      _descriptionController.text = bill.description!;
    }
  }

  // 📥 Cargar servicios y categorías
  Future<void> _loadData() async {
    setState(() => _isLoadingData = true);

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId != null) {
      final services = await _billService.getServices();
      final categories = await _billService.getCategories();

      setState(() {
        _services = services;
        _categories = categories;
        _isLoadingData = false;

        // ✅ Si es edición, mantener el servicio/categoría seleccionado
        if (!_isEditing) {
          if (_services.isNotEmpty) {
            _selectedServiceId = _services[0]['id'];
          }
          if (_categories.isNotEmpty) {
            _selectedCategoryId = _categories[0]['id'];
          }
        }
      });
    } else {
      setState(() => _isLoadingData = false);
    }
  }

  // 🏢 Agregar nuevo servicio
  Future<void> _addNewService() async {
    final name = _newServiceController.text.trim();
    if (name.isEmpty) {
      _showError('Ingresa el nombre del servicio');
      return;
    }

    setState(() => _isAddingService = true);

    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) {
      setState(() => _isAddingService = false);
      return;
    }

    try {
      final newService = await _billService.createService(userId, name, null);
      setState(() {
        _isAddingService = false;
        _newServiceController.clear();
      });

      if (newService != null && mounted) {
        // 🔄 Recargar servicios y seleccionar el nuevo
        await _loadData();
        setState(() => _selectedServiceId = newService['id']);
        _showSuccess('Servicio "$name" creado');
      }
    } catch (e) {
      setState(() => _isAddingService = false);
      _showError('Error al crear el servicio');
    }
  }

  // 📝 Guardar factura (crear o actualizar)
  Future<void> _saveBill() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedServiceId == null) {
      _showError('Selecciona un servicio');
      return;
    }
    if (_selectedCategoryId == null) {
      _showError('Selecciona una categoría');
      return;
    }

    setState(() => _isLoading = true);

    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) {
      _showError('Usuario no autenticado');
      setState(() => _isLoading = false);
      return;
    }

    // 🔄 Crear objeto Bill (con o sin ID)
    final bill = Bill(
      id: _isEditing ? widget.bill!.id : '', // ✅ Si edita, usa ID existente
      userId: userId,
      serviceId: _selectedServiceId!,
      categoryId: _selectedCategoryId!,
      amount: double.parse(_amountController.text),
      dueDate: _selectedDate,
      status: _selectedStatus,
      description: _descriptionController.text.isNotEmpty
          ? _descriptionController.text
          : null,
      isRecurring: _isRecurring,
      reminderDays: _reminderDays,
    );

    // ✅ Guardar o actualizar
    final result = _isEditing
        ? await _billService.updateBill(bill) // ✏️ Editar
        : await _billService.createBill(bill); // 📝 Crear

    setState(() => _isLoading = false);

    if (result != null && mounted) {
      _showSuccess(_isEditing ? 'Factura actualizada' : 'Factura creada');
      Navigator.pop(context, true);
    } else if (mounted) {
      _showError('Error al ${_isEditing ? 'actualizar' : 'crear'} la factura');
    }
  }

  // ✅ Mostrar éxito
  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ $msg'), backgroundColor: Colors.green),
    );
  }

  // ❌ Mostrar error
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ $msg'), backgroundColor: Colors.red),
    );
  }

  // 📅 Seleccionar fecha
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Factura' : 'Agregar Factura'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveBill,
          ),
        ],
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch, // ✅ Alineación de los campos
                  children: [
                    // 🏢 Servicio
                    Row(
                      crossAxisAlignment: CrossAxisAlignment
                          .start, // ✅ Alineación superior para el botón
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Servicio *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.business),
                            ),
                            value: _selectedServiceId,
                            items: _services
                                .map(
                                  (s) => DropdownMenuItem<String>(
                                    // ✅ Especificar tipo
                                    value: s['id'],
                                    child: Text(s['name']),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedServiceId = v),
                            validator: (v) =>
                                v == null ? 'Selecciona un servicio' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: Colors.green,
                              size: 40,
                            ),
                            onPressed: _isAddingService
                                ? null
                                : _showAddServiceDialog,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 📂 Categoría
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Categoría *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      value: _selectedCategoryId,
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem<String>(
                              // ✅ Especificar tipo
                              value: c['id'],
                              child: Row(
                                children: [
                                  Text(c['icon'] ?? '📌'),
                                  const SizedBox(width: 8),
                                  Text(c['name']),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                      validator: (v) =>
                          v == null ? 'Selecciona una categoría' : null,
                    ),
                    const SizedBox(height: 16),

                    // 💰 Monto
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Monto *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                        suffixText: '₲',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Ingresa el monto';
                        final n = double.tryParse(v);
                        if (n == null) return 'Número inválido';
                        if (n <= 0) return 'Monto mayor a 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 📅 Fecha
                    InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha de vencimiento *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 📝 Descripción
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // 🔄 Recurrente
                    SwitchListTile(
                      title: const Text('Factura recurrente'),
                      subtitle: const Text('Se repite cada mes'),
                      value: _isRecurring,
                      onChanged: (v) => setState(() => _isRecurring = v),
                      activeColor: Colors.green,
                    ),

                    // 🔔 Recordatorio
                    Row(
                      children: [
                        const Text('Recordatorio: '),
                        Expanded(
                          child: Slider(
                            value: _reminderDays.toDouble(),
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: '$_reminderDays días',
                            activeColor: Colors.green,
                            onChanged: (v) =>
                                setState(() => _reminderDays = v.round()),
                          ),
                        ),
                        Text(
                          '$_reminderDays días',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 📊 Estado
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.info),
                      ),
                      value: _selectedStatus,
                      items: const [
                        DropdownMenuItem<String>(
                          // ✅ Especificar tipo
                          value: 'pending',
                          child: Row(
                            children: [
                              Icon(Icons.pending, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Pendiente'),
                            ],
                          ),
                        ),
                        DropdownMenuItem<String>(
                          // ✅ Especificar tipo
                          value: 'paid',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Pagada'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedStatus = v!),
                    ),
                    const SizedBox(height: 24),

                    // 🔘 Botón Guardar
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveBill,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                _isEditing
                                    ? 'Actualizar Factura'
                                    : 'Guardar Factura',
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // 🏢 Dialog para agregar servicio
  void _showAddServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.business, color: Colors.green),
            SizedBox(width: 8),
            Text('Nuevo Servicio'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa el nombre del nuevo servicio',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newServiceController,
              decoration: const InputDecoration(
                hintText: 'Ej: Starlink, Disney+, ...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              autofocus: true,
              onFieldSubmitted: (_) => _addNewService(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isAddingService
                ? null
                : () {
                    _newServiceController.clear();
                    Navigator.pop(context);
                  },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _isAddingService ? null : _addNewService,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
            ),
            child: _isAddingService
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Agregar'),
          ),
        ],
      ),
    );
  }
} // aqui termina la clase AddBillScreen
