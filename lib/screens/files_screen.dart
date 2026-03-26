import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../models/operator_file_model.dart';
import '../providers/operator_provider.dart';
import '../services/sync_service.dart';

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  List<OperatorFileModel> _files = [];
  bool _loading = true;
  final Set<int> _downloading = {};
  final Set<int> _deleting = {};

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final operator = ref.read(operatorProvider);
    if (operator == null) return;
    setState(() => _loading = true);
    try {
      final files = await SyncService.fetchFiles(operator: operator);
      if (mounted) setState(() { _files = files; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('Errore caricamento: $e');
      }
    }
  }

  Future<void> _downloadFile(OperatorFileModel file) async {
    final operator = ref.read(operatorProvider);
    if (operator == null) return;
    setState(() => _downloading.add(file.id));
    try {
      final dir = await getTemporaryDirectory();
      final path = await SyncService.downloadFile(
        operator: operator,
        fileId: file.id,
        filename: file.filename,
        saveDir: dir.path,
      );
      if (mounted) {
        setState(() => _downloading.remove(file.id));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✓ Scaricato: ${file.filename}'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Apri',
            textColor: Colors.white,
            onPressed: () => OpenFilex.open(path),
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloading.remove(file.id));
        _showError('Errore download: $e');
      }
    }
  }

  Future<void> _deleteFile(OperatorFileModel file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina file'),
        content: Text('Eliminare "${file.filename}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final operator = ref.read(operatorProvider);
    if (operator == null) return;
    setState(() => _deleting.add(file.id));
    try {
      await SyncService.deleteFile(operator: operator, fileId: file.id);
      if (mounted) setState(() { _files.removeWhere((f) => f.id == file.id); _deleting.remove(file.id); });
    } catch (e) {
      if (mounted) {
        setState(() => _deleting.remove(file.id));
        _showError('Errore eliminazione: $e');
      }
    }
  }

  Future<void> _uploadFile(String path, String filename, String mimeType) async {
    final operator = ref.read(operatorProvider);
    if (operator == null) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Row(children: [
        SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        SizedBox(width: 12),
        Text('Upload in corso…'),
      ]),
      duration: Duration(seconds: 60),
    ));
    try {
      await SyncService.uploadFile(
        operator: operator,
        filePath: path,
        filename: filename,
        mimeType: mimeType,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ File caricato'),
          backgroundColor: Colors.green,
        ));
        _loadFiles();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showError('Errore upload: $e');
      }
    }
  }

  Future<void> _showUploadSheet() async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF1565C0),
                child: Icon(Icons.folder_open, color: Colors.white),
              ),
              title: const Text('Seleziona file'),
              subtitle: const Text('PDF, Excel, immagini…'),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf', 'xlsx', 'xls', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
                );
                if (result != null && result.files.single.path != null) {
                  final f = result.files.single;
                  await _uploadFile(f.path!, f.name, f.extension ?? '');
                }
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF1565C0),
                child: Icon(Icons.camera_alt, color: Colors.white),
              ),
              title: const Text('Scatta foto'),
              subtitle: const Text('Usa la fotocamera'),
              onTap: () async {
                Navigator.pop(ctx);
                final img = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
                if (img != null) {
                  await _uploadFile(img.path, img.name, 'image/jpeg');
                }
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF1565C0),
                child: Icon(Icons.photo_library, color: Colors.white),
              ),
              title: const Text('Galleria foto'),
              subtitle: const Text('Scegli dalla libreria'),
              onTap: () async {
                Navigator.pop(ctx);
                final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
                if (img != null) {
                  await _uploadFile(img.path, img.name, 'image/jpeg');
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 5),
    ));
  }

  IconData _fileIcon(String mimeType, String filename) {
    final ext = filename.split('.').last.toLowerCase();
    if (mimeType.startsWith('image/') || ['jpg','jpeg','png','gif','webp'].contains(ext)) {
      return Icons.image_outlined;
    }
    if (mimeType.contains('pdf') || ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet') || ['xlsx','xls'].contains(ext)) {
      return Icons.table_chart_outlined;
    }
    if (mimeType.contains('word') || mimeType.contains('document') || ['doc','docx'].contains(ext)) {
      return Icons.description_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  Color _fileColor(String mimeType, String filename) {
    final ext = filename.split('.').last.toLowerCase();
    if (mimeType.startsWith('image/') || ['jpg','jpeg','png'].contains(ext)) return Colors.teal;
    if (mimeType.contains('pdf') || ext == 'pdf') return Colors.red.shade700;
    if (['xlsx','xls'].contains(ext)) return Colors.green.shade700;
    if (['doc','docx'].contains(ext)) return const Color(0xFF1565C0);
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final operator = ref.watch(operatorProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Documenti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (operator != null)
              Text(operator.fullName, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Aggiorna', onPressed: _loadFiles),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file),
        label: const Text('Carica'),
        onPressed: _showUploadSheet,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open, size: 72, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('Nessun documento', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('Premi il pulsante + per caricare un file',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFiles,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: _files.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
                    itemBuilder: (context, i) => _buildFileRow(_files[i]),
                  ),
                ),
    );
  }

  Widget _buildFileRow(OperatorFileModel file) {
    final isDownloading = _downloading.contains(file.id);
    final isDeleting = _deleting.contains(file.id);
    final dateLabel = DateFormat('dd/MM/yyyy HH:mm').format(file.createdAt.toLocal());

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _fileColor(file.mimeType, file.filename).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(_fileIcon(file.mimeType, file.filename),
            color: _fileColor(file.mimeType, file.filename), size: 26),
      ),
      title: Text(file.filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$dateLabel · ${file.fileSizeLabel}',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Row(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: file.isFromAdmin
                      ? const Color(0xFF1565C0).withValues(alpha: 0.15)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  file.isFromAdmin ? 'Admin' : 'Tu',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: file.isFromAdmin ? const Color(0xFF1565C0) : Colors.grey.shade700,
                  ),
                ),
              ),
              if (file.description.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(file.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic)),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Download
          isDownloading
              ? const SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  icon: const Icon(Icons.download_outlined, color: Color(0xFF1565C0)),
                  tooltip: 'Scarica',
                  onPressed: () => _downloadFile(file),
                ),
          // Delete (solo file propri)
          if (!file.isFromAdmin)
            isDeleting
                ? const SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                : IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                    tooltip: 'Elimina',
                    onPressed: () => _deleteFile(file),
                  ),
        ],
      ),
    );
  }
}
