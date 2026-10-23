import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../core/models.dart';
import 'neighborhood_art.dart';

const ink = Color(0xFF173E36);
const cream = Color(0xFFFAF8F2);
const accent = Color(0xFFF1C66D);

String friendlyError(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'El correo o la contraseña no son correctos.',
      'email-already-in-use' =>
        'Este correo ya tiene una cuenta. Inicia sesión.',
      'weak-password' =>
        'Usa una contraseña más segura, de al menos 8 caracteres.',
      'network-request-failed' => 'No hay conexión. Inténtalo nuevamente.',
      'too-many-requests' => 'Hay demasiados intentos. Espera unos minutos.',
      _ => 'No se pudo completar el acceso. Revisa tus datos y la configuración de Authentication.',
    };
  }
  if (error is FirebaseFunctionsException) {
    return error.message ?? 'No se pudo guardar. Inténtalo nuevamente.';
  }
  if (error is StateError) return error.message;
  return 'No se pudo completar la operación. Comprueba tu conexión e inténtalo nuevamente.';
}

Future<bool> perform(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(e)),
          backgroundColor: const Color(0xFF8D342A),
        ),
      );
    }
    return false;
  }
}

class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.action,
    this.icon = Icons.check,
    this.success,
  });
  final String label;
  final IconData icon;
  final Future<void> Function() action;
  final String? success;
  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: busy
        ? null
        : () async {
            setState(() => busy = true);
            await perform(context, widget.action, success: widget.success);
            if (mounted) setState(() => busy = false);
          },
    icon: busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(widget.icon, size: 18),
    label: Text(widget.label),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1160),
      child: ListView(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 20 : 32,
        ),
        children: children,
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w600, color: ink),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: const Color(0xFF67746C)),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.title,
    this.message, {
    super.key,
    this.icon = Icons.storefront_outlined,
  });
  final String title, message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
    child: Column(
      children: [
        Container(padding: const EdgeInsets.all(22), decoration: const BoxDecoration(color: Color(0xFFECF0E5), shape: BoxShape.circle), child: Icon(icon, color: ink, size: 36)),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class InputField extends StatelessWidget {
  const InputField(
    this.controller,
    this.label, {
    super.key,
    this.lines = 1,
    this.max = 150,
    this.obscure = false,
    this.validator,
    this.keyboard,
  });
  final TextEditingController controller;
  final String label;
  final int lines, max;
  final bool obscure;
  final String? Function(String?)? validator;
  final TextInputType? keyboard;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      maxLines: lines,
      maxLength: max,
      obscureText: obscure,
      keyboardType: keyboard,
      validator: validator ?? requiredText,
      decoration: InputDecoration(labelText: label, counterText: ''),
    ),
  );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) => Chip(
    visualDensity: VisualDensity.compact,
    label: Text(
      status.isEmpty
          ? 'Borrador'
          : '${status[0].toUpperCase()}${status.substring(1)}',
    ),
    backgroundColor: switch (status) {
      'aprobada' => const Color(0xFFDDEDE1),
      'rechazada' => const Color(0xFFF7DFD8),
      'pendiente' => const Color(0xFFF8EAC7),
      _ => const Color(0xFFE8EAE5),
    },
    side: BorderSide.none,
  );
}

Widget imageOrArt(
  List<String> images, {
  double height = 180,
  IconData icon = Icons.storefront_outlined,
}) {
  final fallback = SizedBox(height: height, child: Stack(fit: StackFit.expand, children: [
    NeighborhoodArt(variant: icon == Icons.local_cafe_outlined ? 0 : 1),
    Positioned(bottom: 10, right: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: cream.withValues(alpha: .94), borderRadius: BorderRadius.circular(6)), child: const Text('Imagen ilustrativa', style: TextStyle(fontFamily: 'Manrope', fontSize: 9, color: ink)))),
  ]));
  return ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: images.isEmpty
        ? fallback
        : Image.network(
            images.first,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          ),
  );
}

Future<String?> askText(
  BuildContext context,
  String title, {
  String initial = '',
  bool required = true,
}) async {
  final controller = TextEditingController(text: initial);
  final key = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: key,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          maxLength: 1000,
          validator: required ? requiredText : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (key.currentState!.validate()) {
              Navigator.pop(ctx, controller.text.trim());
            }
          },
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );
  // The route's exit animation may still use its controller.
  Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
  return result;
}
