import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:my_logbook_app/features/logbook/models/log_model.dart';
import 'package:my_logbook_app/features/logbook/log_controller.dart';

class LogEditorPage extends StatefulWidget {
  final LogModel? log;
  final int? index;
  final LogController controller;
  final dynamic currentUser;
  final bool isOnline;

  const LogEditorPage({
    super.key,
    this.log,
    this.index,
    required this.controller,
    required this.currentUser,
    this.isOnline = true,
  });

  @override
  State<LogEditorPage> createState() => _LogEditorPageState();
}

class _LogEditorPageState extends State<LogEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late String _selectedCategory;
  late bool _isPublic;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.log?.title ?? '');
    _descController = TextEditingController(
      text: widget.log?.description ?? '',
    );
    _selectedCategory = widget.log?.category ?? 'Personal';
    _isPublic = widget.log?.isPublic ?? false;

    _descController.addListener(() {
      setState(() {});
    });
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) return;

    if (widget.log == null) {
      widget.controller.addLog(
        _titleController.text,
        _descController.text,
        _selectedCategory,
        widget.currentUser.username,
        widget.currentUser.teamId,
        isOnline: widget.isOnline,
        isPublic: _isPublic,
      );
    } else {
      widget.controller.updateLog(
        widget.index!,
        _titleController.text,
        _descController.text,
        _selectedCategory,
        widget.currentUser.username,
        widget.currentUser.teamId,
        isOnline: widget.isOnline,
        isPublic: _isPublic,
      );
    }
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.log == null ? 'Catatan Baru' : 'Edit Catatan'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Editor'), Tab(text: 'Pratinjau')],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.save), onPressed: _save),
          ],
        ),
        body: TabBarView(
          children: [
            // Tab 1: Editor
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Judul'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    items: widget.controller.categories
                        .where((c) => c != 'All')
                        .map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat));
                        })
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategory = value!);
                    },
                    decoration: const InputDecoration(labelText: 'Kategori'),
                  ),
                  const SizedBox(height: 10),
                  // Toggle Public / Private
                  Row(
                    children: [
                      Icon(
                        _isPublic ? Icons.public : Icons.lock,
                        size: 20,
                        color: _isPublic ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isPublic ? 'Publik (bisa dilihat tim)' : 'Privat (hanya saya)',
                        style: TextStyle(
                          color: _isPublic ? Colors.green.shade700 : Colors.grey.shade600,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: _isPublic,
                        activeThumbColor: Colors.green,
                        onChanged: (val) => setState(() => _isPublic = val),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: TextField(
                      controller: _descController,
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        hintText: 'Tulis laporan dengan format Markdown...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Tab 2: Markdown Preview
            Markdown(data: _descController.text),
          ],
        ),
      ),
    );
  }
}
