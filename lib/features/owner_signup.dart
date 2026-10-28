import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../core/models.dart';
import 'shared.dart';

class OwnerSignupDialog extends StatefulWidget {
  final List<Item> categories;

  const OwnerSignupDialog({required this.categories});

  @override
  State<OwnerSignupDialog> createState() => _OwnerSignupDialogState();
}

class _OwnerSignupDialogState extends State<OwnerSignupDialog> {
  final formKey = GlobalKey<FormState>();
  final nombreController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordConfirmController = TextEditingController();
  final negocioNombreController = TextEditingController();
  final descripcionController = TextEditingController();
  final direccionController = TextEditingController();
  final telefonoController = TextEditingController();
  final horariosController = TextEditingController();
  String? categoriaSeleccionada;
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Registrarse como dueño',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),

                const Text('Datos personales', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                TextFormField(
                  controller: nombreController,
                  decoration: const InputDecoration(labelText: 'Tu nombre', border: OutlineInputBorder()),
                  validator: (v) => requiredText(v),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder()),
                  validator: (v) => validEmail(v),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                  obscureText: true,
                  validator: (v) => requiredText(v),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: passwordConfirmController,
                  decoration: const InputDecoration(labelText: 'Confirmar contraseña', border: OutlineInputBorder()),
                  obscureText: true,
                  validator: (v) {
                    if (v != passwordController.text) {
                      return 'Las contraseñas no coinciden.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                const Text('Datos del negocio', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                TextFormField(
                  controller: negocioNombreController,
                  decoration: const InputDecoration(labelText: 'Nombre del negocio', border: OutlineInputBorder()),
                  validator: (v) => requiredText(v),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: categoriaSeleccionada,
                  decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                  items: widget.categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat.id,
                      child: Text(cat.text('nombre')),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => categoriaSeleccionada = v),
                  validator: (v) => v == null ? 'Selecciona una categoría.' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: descripcionController,
                  decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
                  maxLines: 3,
                  validator: (v) => requiredText(v),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: direccionController,
                  decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder()),
                  validator: (v) => requiredText(v),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: telefonoController,
                  decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()),
                  validator: (v) => validPhone(v),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: horariosController,
                  decoration: const InputDecoration(labelText: 'Horarios', border: OutlineInputBorder()),
                  maxLines: 2,
                  validator: (v) => requiredText(v),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: loading ? null : _register,
                    child: loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Registrarse'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => loading = true);
    try {
      final result = await FirebaseFunctions.instance
        .httpsCallable('registrarComoDueno')
        .call<Map>({
          'nombre': nombreController.text.trim(),
          'email': emailController.text.trim(),
          'password': passwordController.text,
          'negocio': {
            'nombre': negocioNombreController.text.trim(),
            'descripcion': descripcionController.text.trim(),
            'categoria': categoriaSeleccionada,
            'direccion': direccionController.text.trim(),
            'telefono': telefonoController.text.trim(),
            'horarios': horariosController.text.trim(),
            'zona': '', // Se puede dejar vacío o pedir como parámetro adicional
            'imagenes': [],
          },
        });

      if (!mounted) return;

      // Auto-login
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Bienvenido! Tu negocio se ha registrado.')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    emailController.dispose();
    passwordController.dispose();
    passwordConfirmController.dispose();
    negocioNombreController.dispose();
    descripcionController.dispose();
    direccionController.dispose();
    telefonoController.dispose();
    horariosController.dispose();
    super.dispose();
  }
}
