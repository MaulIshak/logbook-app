import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:my_logbook_app/features/auth/models/user_model.dart';
import 'package:my_logbook_app/features/logbook/log_controller.dart';
import 'package:my_logbook_app/features/logbook/log_editor_page.dart';
import 'package:my_logbook_app/features/logbook/models/log_model.dart';
import 'package:my_logbook_app/features/onboarding/onboarding_view.dart';
import 'package:my_logbook_app/helper/log_helper.dart';
import 'package:my_logbook_app/services/mongo_service.dart';

class LogView extends StatefulWidget {
  final UserModel currentUser;
  const LogView({super.key, required this.currentUser});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  // Instansiasi controller
  late final LogController _controller = LogController(
    widget.currentUser.teamId,
  );
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Memberikan kesempatan UI merender widget awal sebelum proses berat dimulai
    Future.microtask(() => _initDatabase());
  }

  Future<void> _initDatabase() async {
    setState(() => _isLoading = true);
    try {
      await LogHelper.writeLog(
        "UI: Memulai inisialisasi database...",
        source: "log_view.dart",
      );

      // Mencoba koneksi ke MongoDB Atlas (Cloud)
      await LogHelper.writeLog(
        "UI: Menghubungi MongoService.connect()...",
        source: "log_view.dart",
      );

      // Mengaktifkan kembali koneksi dengan timeout 15 detik (lebih longgar untuk sinyal HP)
      await MongoService().connect().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception(
          "Koneksi Cloud Timeout. Periksa sinyal/IP Whitelist.",
        ),
      );

      await LogHelper.writeLog(
        "UI: Koneksi MongoService BERHASIL.",
        source: "log_view.dart",
      );

      // Mengambil data log dari Cloud
      await LogHelper.writeLog(
        "UI: Memanggil controller.loadFromDisk()...",
        source: "log_view.dart",
      );

      await _controller.loadFromDisk(widget.currentUser.username);

      await LogHelper.writeLog(
        "UI: Data berhasil dimuat ke Notifier.",
        source: "log_view.dart",
      );
    } catch (e) {
      await LogHelper.writeLog(
        "UI: Error - $e",
        source: "log_view.dart",
        level: 1,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Masalah: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      // 2. INILAH FINALLY: Apapun yang terjadi (Sukses/Gagal/Data Kosong), loading harus mati
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Navigasi ke Halaman Editor (Gantikan Dialog Lama)
  void _goToEditor({LogModel? log, int? index}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogEditorPage(
          log: log,
          index: index,
          controller: _controller,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white, // Background abu-abu muda
      appBar: AppBar(
        title: Text(
          "Logbook App: ${widget.currentUser.username}",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // 1. Munculkan Dialog Konfirmasi
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Konfirmasi Logout"),
                    content: const Text(
                      "Apakah Anda yakin? Data yang belum disimpan mungkin akan hilang.",
                    ),
                    actions: [
                      // Tombol Batal
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context), // Menutup dialog saja
                        child: const Text("Batal"),
                      ),
                      // Tombol Ya, Logout
                      TextButton(
                        onPressed: () {
                          // Menutup dialog
                          Navigator.pop(context);

                          // 2. Navigasi kembali ke Onboarding (Membersihkan Stack)
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OnboardingView(),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          "Ya, Keluar",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Expanded(
        child: Column(
          children: [
            SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: CupertinoTextField(
                      onChanged: (value) => _controller.searchLog(value),
                      placeholder: "Cari Catatan...",
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.search, color: Colors.grey),
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _controller.filterCategory,
                      onChanged: (value) {
                        if (value != null) {
                          _controller.filterLogByCategory(value);
                          setState(() {});
                        }
                      },
                      items: _controller.categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(
                                category,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: "Kategori",
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<List<LogModel>>(
              valueListenable: _controller.logsNotifier,
              builder: (context, currentLogs, child) {
                if (_isLoading) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Menghubungkan ke MongoDB Atlas..."),
                      ],
                    ),
                  );
                }
                if (currentLogs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image(image: AssetImage("assets/images/empty.png")),
                        const SizedBox(height: 16),
                        const Text("Belum ada catatan di Cloud."),
                        ElevatedButton(
                          onPressed: () => _goToEditor(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Buat Catatan Pertama"),
                        ),
                      ],
                    ),
                  );
                }

                // if (currentLogs.isEmpty) {
                //   return Center(
                //     child: Column(
                //       mainAxisAlignment: MainAxisAlignment.center,
                //       children: [
                //         Image(image: AssetImage("assets/images/empty.png")),
                //         Text(
                //           "Belum ada catatan",
                //           style: textTheme.headlineSmall,
                //         ),
                //       ],
                //     ),
                //   );
                // }
                return Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await _controller.loadFromDisk(
                        widget.currentUser.username,
                      );
                    },
                    child: ListView.builder(
                      itemCount: currentLogs.length,
                      itemBuilder: (context, index) {
                        final log = currentLogs[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.note),
                            title: Text(log.title),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log.category,
                                  style: TextStyle(
                                    color: getCategoryColor(log.category),
                                  ),
                                ),
                                Text(log.description),
                                Text(log.date.toString()),
                              ],
                            ),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => _goToEditor(
                                    log: log,
                                    index: index,
                                  ), // Fungsi edit
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _showDeleteLogDialog(log),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        // onPressed: _showAddLogDialog,
        onPressed: () =>
            _goToEditor(), // Panggil fungsi dialog yang baru dibuat
        child: const Icon(Icons.add),
      ),
    );
  }

  // 1. Tambahkan Controller untuk menangkap input di dalam State
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String? selectedCategory;

  void _showAddLogDialog() {
    selectedCategory = null;
    _titleController.clear();
    _contentController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tambah Catatan Baru"),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min, // Agar dialog tidak memenuhi layar
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: "Judul Catatan"),
                validator: (value) => value == null || value.isEmpty
                    ? "Judul tidak boleh kosong"
                    : null,
              ),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(hintText: "Isi Deskripsi"),
                validator: (value) => value == null || value.isEmpty
                    ? "Deskripsi tidak boleh kosong"
                    : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                onChanged: (value) => setState(() => selectedCategory = value),
                items: _controller.categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                decoration: const InputDecoration(hintText: "Kategori"),
                validator: (value) =>
                    value == null ? "Kategori harus dipilih" : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Tutup tanpa simpan
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;

              // Jalankan fungsi tambah di Controller
              _controller.addLog(
                _titleController.text,
                _contentController.text,
                selectedCategory!,
                widget.currentUser.username,
                widget.currentUser.teamId,
              );

              // Trigger UI Refresh
              setState(() {});

              // Bersihkan input dan tutup dialog
              _titleController.clear();
              _contentController.clear();
              Navigator.pop(context);
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  void _showEditLogDialog(int index, LogModel log) {
    _titleController.text = log.title;
    _contentController.text = log.description;
    selectedCategory = log.category;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Catatan"),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: "Judul Catatan"),
                validator: (value) => value == null || value.isEmpty
                    ? "Judul tidak boleh kosong"
                    : null,
              ),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(hintText: "Isi Deskripsi"),
                validator: (value) => value == null || value.isEmpty
                    ? "Deskripsi tidak boleh kosong"
                    : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                onChanged: (value) => setState(() => selectedCategory = value),
                items: _controller.categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                decoration: const InputDecoration(hintText: "Kategori"),
                validator: (value) =>
                    value == null ? "Kategori harus dipilih" : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              _controller.updateLog(
                index,
                _titleController.text,
                _contentController.text,
                selectedCategory!,
                widget.currentUser.username,
                widget.currentUser.teamId,
              );
              _titleController.clear();
              _contentController.clear();
              Navigator.pop(context);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  void _showDeleteLogDialog(LogModel log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Catatan"),
        content: const Text("Yakin ingin menghapus catatan ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              _controller.removeLog(log);
              Navigator.pop(context);
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color getCategoryColor(String category) {
    switch (category) {
      case 'Personal':
        return Colors.blue;
      case 'Work':
        return Colors.green;
      case 'Study':
        return Colors.orange;
      case 'Health':
        return Colors.purple;
      case 'Travel':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }
}
