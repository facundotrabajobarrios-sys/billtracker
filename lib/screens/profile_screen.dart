import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/gamification_provider.dart';
import '../providers/theme_provider.dart';
import '../services/bill_service.dart';
import '../utils/app_navigator.dart';
import '../widgets/user_avatar.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _billService = BillService();
  final _imagePicker = ImagePicker();
  int _totalBills = 0;
  bool _isLoading = true;
  bool _isSavingAvatar = false;
  Uint8List? _previewBytes;
  XFile? _pickedImage;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final userId = context.read<AuthProvider>().user?.id;
    _loadError = null;
    try {
      if (userId != null) {
        await context.read<GamificationProvider>().loadGamification(userId);
        final summary = await _billService.getSummary(userId);
        _totalBills = summary['total'] ?? 0;
      }
    } catch (error) {
      _loadError = 'No se pudo cargar el perfil: $error';
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (_loadError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_loadError!)));
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La imagen debe pesar menos de 5 MB.')),
        );
        return;
      }
      setState(() {
        _pickedImage = image;
        _previewBytes = bytes;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar la imagen: $error')),
      );
    }
  }

  Future<void> _saveAvatar() async {
    final image = _pickedImage;
    final bytes = _previewBytes;
    if (image == null || bytes == null) return;
    setState(() => _isSavingAvatar = true);
    try {
      final result = await context.read<AuthProvider>().uploadAvatar(
        bytes,
        image.name,
      );
      if (!mounted) return;
      setState(() {
        _pickedImage = null;
        _previewBytes = null;
        _isSavingAvatar = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.previousImageRemoved
                ? 'Foto de perfil actualizada.'
                : 'Foto actualizada. No se pudo limpiar la imagen anterior.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSavingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la foto: $error')),
      );
    }
  }

  Future<void> _deleteAvatar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitar foto de perfil'),
        content: const Text(
          'Tu perfil volverá a mostrar la imagen predeterminada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Quitar foto'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSavingAvatar = true);
    try {
      final result = await context.read<AuthProvider>().deleteAvatar();
      if (!mounted) return;
      setState(() => _isSavingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.previousImageRemoved
                ? 'Foto de perfil eliminada.'
                : 'Foto eliminada del perfil, pero no se pudo limpiar el archivo.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSavingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la foto: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final user = auth.user;
    final gamification = context.watch<GamificationProvider>().gamification;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                _previewBytes == null
                                    ? UserAvatar(
                                        name: user?.name,
                                        imageUrl: user?.avatarUrl,
                                        radius: 56,
                                      )
                                    : CircleAvatar(
                                        radius: 56,
                                        backgroundImage: MemoryImage(
                                          _previewBytes!,
                                        ),
                                      ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).scaffoldBackgroundColor,
                                      width: 3,
                                    ),
                                  ),
                                  child: IconButton(
                                    onPressed: _isSavingAvatar
                                        ? null
                                        : _pickAvatar,
                                    icon: const Icon(
                                      Icons.photo_camera_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    tooltip: 'Cambiar foto',
                                    constraints: const BoxConstraints.tightFor(
                                      width: 40,
                                      height: 40,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              user?.name ?? 'Usuario',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? '',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 18),
                            if (_previewBytes != null)
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: _isSavingAvatar
                                        ? null
                                        : () => setState(() {
                                            _pickedImage = null;
                                            _previewBytes = null;
                                          }),
                                    child: const Text('Cancelar'),
                                  ),
                                  FilledButton.icon(
                                    onPressed: _isSavingAvatar
                                        ? null
                                        : _saveAvatar,
                                    icon: _isSavingAvatar
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.cloud_upload_outlined,
                                          ),
                                    label: const Text('Guardar foto'),
                                  ),
                                ],
                              )
                            else
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                children: [
                                  TextButton.icon(
                                    onPressed: _pickAvatar,
                                    icon: const Icon(
                                      Icons.add_a_photo_outlined,
                                    ),
                                    label: const Text('Cambiar foto'),
                                  ),
                                  if (user?.avatarUrl != null)
                                    TextButton.icon(
                                      onPressed: _isSavingAvatar
                                          ? null
                                          : _deleteAvatar,
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('Quitar foto'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: colorScheme.error,
                                      ),
                                    ),
                                ],
                              ),
                            const SizedBox(height: 4),
                            Text(
                              'JPG, PNG o WEBP · Máximo 5 MB',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: SwitchListTile(
                        secondary: Icon(
                          theme.isDarkMode
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined,
                        ),
                        title: const Text('Modo oscuro'),
                        subtitle: const Text(
                          'Personaliza la apariencia de la aplicación',
                        ),
                        value: theme.isDarkMode,
                        onChanged: theme.setDarkMode,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _stat(
                              context,
                              'Nivel',
                              '${gamification?.currentLevel ?? user?.level ?? 0}',
                            ),
                            _stat(
                              context,
                              'Puntos',
                              '${gamification?.totalPoints ?? user?.points ?? 0}',
                            ),
                            _stat(context, 'Facturas', '$_totalBills'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: user == null ? null : _confirmDeleteAccount,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Eliminar cuenta'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        String? warning;
                        try {
                          await auth.logout();
                        } catch (error) {
                          warning =
                              'La sesión local se cerró, pero hubo un problema al invalidarla: $error';
                        }
                        returnToLogin(message: warning);
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) => Column(
    children: [
      Text(
        value,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar tu cuenta? Esta acción no se puede deshacer',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AuthProvider>().deleteAccount();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la cuenta: $error')),
      );
    }
  }
}
