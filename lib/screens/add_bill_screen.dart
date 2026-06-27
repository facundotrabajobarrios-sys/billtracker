import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/bill_service.dart';
import '../models/bill.dart';

// 📄 Pantalla para agregar factura
class AddBillScreen extends StatefulWidget {
  const AddBillScreen({super.key});

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _billService = BillService();

  // 🔤 Controladores de texto
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  // 🏢 Controladores para nuevo servicio
  final _newServiceController = TextEditingController();

  // 📅 Variables para selecciones
  String? _selectedServiceId;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'pending';
  bool _isRecurring = false;
  int _reminderDays = 3;
  bool _isLoading = false;
  bool _isAddingService = false;

  // 📋 Listas para los dropdowns
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _newServiceController.dispose();
    super.dispose();
  }

  // 📥 Cargar servicios y categorías
  Future<void> _loadData() async {
    setState(() {
      _isLoadingData = true;
    });

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId != null) {
      final services = await _billService.getServices();
      final categories = await _billService.getCategories();

      setState(() {
        _services = services;
        _categories = categories;
        _isLoadingData = false;

        if (_services.isNotEmpty) {
          _selectedServiceId = _services[0]['id'];
        }
        if (_categories.isNotEmpty) {
          _selectedCategoryId = _categories[0]['id'];
        }
      });
    } else {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  // 🏢 Agregar nuevo servicio
  Future<void> _addNewService() async {
    final name = _newServiceController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Ingresa el nombre del servicio'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isAddingService = true;
    });

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId == null) {
      setState(() {
        _isAddingService = false;
      });
      return;
    }

    try {
      final newService = await _billService.createService(
        userId,
        name,
        null, // Sin descripción por ahora
      );

      setState(() {
        _isAddingService = false;
        _newServiceController.clear();
      });

      if (newService != null && mounted) {
        // ✅ Recargar servicios y seleccionar el nuevo
        await _loadData();

        // Seleccionar el servicio recién creado
        setState(() {
          _selectedServiceId = newService['id'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Servicio "$name" creado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isAddingService = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Error al crear el servicio'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 📝 Guardar factura
  Future<void> _saveBill() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedServiceId == null) {
        _showError('Selecciona un servicio');
        return;
      }
      if (_selectedCategoryId == null) {
        _showError('Selecciona una categoría');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.id;

      if (userId == null) {
        _showError('Usuario no autenticado');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      // Crear objeto Bill y enviarlo al servicio
      final bill = Bill(
        id: '',
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

      final createdBill = await _billService.createBill(bill);

      setState(() {
        _isLoading = false;
      });

      if (createdBill != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Factura creada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(
          context,
          true,
        ); // Regresar a la pantalla anterior indicando que se creó una factura
      } else if (mounted) {
        _showError('Error al crear la factura');
      }
    }
  }

  // ❌ Mostrar error
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ $message'), backgroundColor: Colors.red),
    );
  }

  // 📅 Seleccionar fecha
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Factura'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Recargar',
          ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🏢 Servicio (con opción de agregar nuevo)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                            items: _services.map((service) {
                              return DropdownMenuItem<String>(
                                value: service['id'],
                                child: Text(service['name']),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedServiceId = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Selecciona un servicio';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ➕ Botón para agregar nuevo servicio
                        Expanded(
                          flex: 1,
                          child: Tooltip(
                            message: 'Agregar nuevo servicio',
                            child: IconButton(
                              icon: const Icon(
                                Icons.add_circle,
                                color: Colors.green,
                                size: 40,
                              ),
                              onPressed: _isAddingService
                                  ? null
                                  : () {
                                      _showAddServiceDialog();
                                    },
                            ),
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
                      items: _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category['id'],
                          child: Row(
                            children: [
                              Text(category['icon'] ?? '📌'),
                              const SizedBox(width: 8),
                              Text(category['name']),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Selecciona una categoría';
                        }
                        return null;
                      },
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
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa el monto';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Ingresa un número válido';
                        }
                        if (double.parse(value) <= 0) {
                          return 'El monto debe ser mayor a 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 📅 Fecha de vencimiento
                    InkWell(
                      onTap: () => _selectDate(context),
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
                              style: const TextStyle(fontSize: 16),
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

                    // 🔄 Factura recurrente
                    SwitchListTile(
                      title: const Text('Factura recurrente'),
                      subtitle: const Text('Se repite cada mes'),
                      value: _isRecurring,
                      onChanged: (value) {
                        setState(() {
                          _isRecurring = value;
                        });
                      },
                      activeColor: Colors.green,
                    ),
                    const SizedBox(height: 8),

                    // 🔔 Días de recordatorio
                    Row(
                      children: [
                        const Text('Recordatorio: '),
                        Expanded(
                          child: Slider(
                            value: _reminderDays.toDouble(),
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: '$_reminderDays días antes',
                            activeColor: Colors.green,
                            onChanged: (value) {
                              setState(() {
                                _reminderDays = value.round();
                              });
                            },
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
                        DropdownMenuItem(
                          value: 'pending',
                          child: Row(
                            children: [
                              Icon(Icons.pending, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Pendiente'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
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
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value!;
                        });
                      },
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
                            : const Text(
                                'Guardar Factura',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // 🏢 Dialog para agregar nuevo servicio
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
}
