import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/models.dart';
import '../data/repository.dart';
import 'shared.dart';
import 'public_pages.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({
    super.key,
    required this.repository,
    required this.kind,
    this.business,
    this.previous,
  });
  final AppRepository repository;
  final String kind;
  final Item? business, previous;
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  late String id;
  String? category;
  List<String> images = [];
  DateTime expires = DateTime.now().add(const Duration(days: 30));
  bool busy = false;
  bool get ad => widget.kind == 'anuncio';
  @override
  void initState() {
    super.initState();
    final source =
        widget.previous?.proposal ??
        (ad
            ? <String, dynamic>{}
            : widget.business?.data ?? <String, dynamic>{});
    id = widget.previous?.text('estado') == 'borrador'
        ? widget.previous!.id
        : widget.repository.newId();
    for (final key in [
      'nombre',
      'descripcion',
      'direccion',
      'zona',
      'telefono',
      'horarios',
      'titulo',
    ]) {
      fields[key] = TextEditingController(text: source[key]?.toString() ?? '');
    }
    category = source['categoria'] as String?;
    if (!widget.repository.categories.any(
      (c) => c.id == category && c.flag('activa'),
    )) {
      category = null;
    }
    images = List<String>.from(source['imagenes'] as List? ?? []);
    expires = DateTime.tryParse(source['vence']?.toString() ?? '') ?? expires;
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Json proposal() => ad
      ? {
          'titulo': fields['titulo']!.text.trim(),
          'descripcion': fields['descripcion']!.text.trim(),
          'negocioId':
              widget.business?.id ?? widget.previous?.text('negocioId'),
          'vence': expires.toUtc().toIso8601String(),
        }
      : {
          for (final key in [
            'nombre',
            'descripcion',
            'direccion',
            'zona',
            'telefono',
            'horarios',
          ])
            key: fields[key]!.text.trim(),
          'categoria': category,
          'imagenes': images,
        };
  Future<void> save(bool draft) async {
    if (!form.currentState!.validate()) return;
    if (ad && !expires.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una fecha de vencimiento futura.'),
        ),
      );
      return;
    }
    setState(() => busy = true);
    final ok = await perform(
      context,
      () => widget.repository.submit({
        'id': id,
        'tipo': widget.kind,
        'negocioId': widget.business?.id ?? widget.previous?.text('negocioId'),
        'propuesta': proposal(),
        'borrador': draft,
        'anteriorId': widget.previous?.text('estado') == 'borrador'
            ? widget.previous?.text('anteriorId')
            : widget.previous?.id,
      }),
      success: draft ? 'Borrador guardado.' : 'Solicitud enviada. El contenido se publicará después de su aprobación.',
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (ok) Navigator.pop(context);
  }

  Future<void> addImage() async {
    setState(() => busy = true);
    await perform(context, () async {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      String? mime;
      if (bytes.length > 3 &&
          bytes[0] == 0xFF &&
          bytes[1] == 0xD8 &&
          bytes[2] == 0xFF) {
        mime = 'image/jpeg';
      }
      if (bytes.length > 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        mime = 'image/png';
      }
      if (bytes.length > 12 &&
          String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
          String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
        mime = 'image/webp';
      }
      if (mime == null) {
        throw StateError('Selecciona una imagen JPEG, PNG o WebP.');
      }
      final url = await widget.repository.uploadImage(bytes, mime);
      if (mounted) setState(() => images.add(url));
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        ad
            ? 'Solicitar anuncio'
            : widget.kind == 'cambio'
            ? 'Proponer cambios'
            : 'Solicitar un negocio',
      ),
    ),
    body: PageBody(
      children: [
        SectionTitle(
          ad ? 'Comparte una novedad' : 'Dale un lugar a tu negocio',
          'Guarda un borrador o envía tu propuesta a revisión.',
        ),
        if (widget.previous?.text('motivo').isNotEmpty ?? false)
          Card(
            color: const Color(0xFFF7DFD8),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Revisión anterior: ${widget.previous!.text('motivo')}',
              ),
            ),
          ),
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ad)
                InputField(fields['titulo']!, 'Título')
              else ...[
                InputField(fields['nombre']!, 'Nombre del negocio'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: [
                      for (final c in widget.repository.categories.where(
                        (c) => c.flag('activa'),
                      ))
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(c.text('nombre')),
                        ),
                    ],
                    onChanged: (v) => category = v,
                    validator: (v) =>
                        v == null ? 'Selecciona una categoría.' : null,
                  ),
                ),
              ],
              InputField(
                fields['descripcion']!,
                'Descripción',
                lines: 4,
                max: ad ? 4000 : 2000,
              ),
              if (!ad) ...[
                InputField(fields['direccion']!, 'Dirección'),
                InputField(fields['zona']!, 'Zona'),
                InputField(
                  fields['telefono']!,
                  'Teléfono con código de país',
                  keyboard: TextInputType.phone,
                  max: 30,
                  validator: validPhone,
                ),
                InputField(
                  fields['horarios']!,
                  'Horarios de atención',
                  lines: 2,
                  max: 500,
                ),
                const Text(
                  'Imágenes · La primera será la portada',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < images.length; i++)
                  ListTile(
                    leading: SizedBox(
                      width: 56,
                      child: imageOrArt([images[i]], height: 48),
                    ),
                    title: Text('Imagen ${i + 1}'),
                    trailing: IconButton(
                      tooltip: 'Quitar imagen',
                      onPressed: busy
                          ? null
                          : () => setState(() => images.removeAt(i)),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                if (images.length < 6)
                  Wrap(
                    spacing: 8,
                    children: [
                      if (!widget.repository.demo)
                        OutlinedButton.icon(
                          onPressed: busy ? null : addImage,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Subir imagen'),
                        ),
                      if (widget.repository.demo)
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  final url = await askText(
                                    context,
                                    'Dirección HTTPS de la imagen',
                                  );
                                  if (url == null || !context.mounted) return;
                                  final parsed = Uri.tryParse(url);
                                  if (parsed?.scheme != 'https' ||
                                      (parsed?.host.isEmpty ?? true)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Usa una dirección HTTPS válida.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() => images.add(url));
                                },
                          child: const Text('Añadir imagen por URL'),
                        ),
                    ],
                  ),
                const SizedBox(height: 22),
              ] else ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Vencimiento del anuncio'),
                  subtitle: Text(expires.toIso8601String().split('T').first),
                  trailing: TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final now = DateTime.now();
                            final first = DateTime(
                              now.year,
                              now.month,
                              now.day,
                            ).add(const Duration(days: 1));
                            final value = await showDatePicker(
                              context: context,
                              initialDate: expires.isAfter(first)
                                  ? expires
                                  : first,
                              firstDate: first,
                              lastDate: now.add(const Duration(days: 730)),
                            );
                            if (value != null) {
                              setState(
                                () => expires = DateTime(
                                  value.year,
                                  value.month,
                                  value.day,
                                  23,
                                  59,
                                ),
                              );
                            }
                          },
                    child: const Text('Elegir'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : () => save(false),
                    icon: const Icon(Icons.send_outlined),
                    label: Text(busy ? 'Guardando…' : 'Enviar a revisión'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : () => save(true),
                    child: const Text('Guardar borrador'),
                  ),
                  if (!ad)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              if (form.currentState!.validate()) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => BusinessDetail(
                                      repository: widget.repository,
                                      business: Item(id, proposal()),
                                      preview: true,
                                    ),
                                  ),
                                );
                              }
                            },
                      child: const Text('Vista previa'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
