import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_logbook_app/features/auth/models/user_model.dart';
import 'package:my_logbook_app/features/logbook/log_controller.dart';
import 'package:my_logbook_app/features/logbook/log_editor_page.dart';
import 'package:my_logbook_app/features/logbook/models/log_model.dart';
import 'package:my_logbook_app/features/onboarding/onboarding_view.dart';
import 'package:my_logbook_app/services/access_control_service.dart';

class LogView extends StatefulWidget {
  final UserModel currentUser;
  const LogView({super.key, required this.currentUser});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  late final LogController _controller = LogController(
    widget.currentUser.teamId,
    widget.currentUser.username,
  );

  bool _isLoading = false;
  bool _isOffline = false;
  String? _errorMessage;

  // Listener koneksi internet secara real-time
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _initDatabase());
    _startConnectivityListener();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  /// Mulai listening perubahan koneksi internet secara real-time
  void _startConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final isNowOnline = results.any(
        (r) => r != ConnectivityResult.none,
      );

      if (!isNowOnline && !_isOffline && !_isLoading) {
        // Baru saja offline
        if (mounted) {
          setState(() {
            _isOffline = true;
            _errorMessage = 'Koneksi internet terputus. Menampilkan data lokal.';
          });
          _controller.loadFromHive();
        }
      } else if (isNowOnline && _isOffline) {
        // Baru saja kembali online — sync data pending dulu, lalu reload
        if (mounted) {
          _controller.syncPendingData().then((_) {
            if (mounted) _initDatabase();
          });
        }
      }
    });
  }

  /// Mengubah exception menjadi pesan yang ramah untuk user
  String _getFriendlyError(Object e) {
    // Cek tipe TimeoutException secara eksplisit
    if (e is TimeoutException) {
      return 'Koneksi timeout. Jaringan terlalu lambat atau tidak ada internet.';
    }
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Koneksi timeout. Periksa koneksi internet Anda.';
    } else if (msg.contains('socket') ||
        msg.contains('network') ||
        msg.contains('connection refused') ||
        msg.contains('failed host lookup')) {
      return 'Tidak ada koneksi internet. Menampilkan data lokal.';
    } else if (msg.contains('whitelist') || msg.contains('ip')) {
      return 'Akses ditolak server. Periksa IP Whitelist di MongoDB Atlas.';
    } else if (msg.contains('authentication') || msg.contains('auth')) {
      return 'Autentikasi gagal. Periksa kredensial database.';
    } else {
      return 'Gagal terhubung ke cloud. Menampilkan data lokal.';
    }
  }

  Future<void> _initDatabase() async {
    setState(() {
      _isLoading = true;
      _isOffline = false;
      _errorMessage = null;
    });

    try {
      // Cek konektivitas LEBIH DULU — hemat 20 detik jika sudah offline
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult.any(
        (r) => r != ConnectivityResult.none,
      );

      if (!hasConnection) {
        // Langsung pakai Hive, tidak perlu menunggu timeout cloud
        _controller.loadFromHive();
        if (mounted) {
          setState(() {
            _isOffline = true;
            _errorMessage = 'Tidak ada koneksi internet. Menampilkan data lokal.';
          });
        }
        return;
      }

      // Ada koneksi — coba ambil dari cloud
      final success = await _controller.loadFromDisk(
        widget.currentUser.teamId,
      );

      if (mounted && !success) {
        setState(() {
          _isOffline = true;
          _errorMessage = 'Gagal terhubung ke server. Menampilkan data lokal.';
        });
      }
    } catch (e) {
      _controller.loadFromHive();
      if (mounted) {
        setState(() {
          _isOffline = true;
          _errorMessage = _getFriendlyError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Pull-to-refresh yang aman — tidak crash saat offline
  Future<void> _refresh() async {
    if (_isOffline) {
      // Jika offline, cukup tampilkan data lokal tanpa ke cloud
      _controller.loadFromHive();
      return;
    }
    // Coba sync ke cloud, loadFromDisk sudah aman (tidak throw)
    final success = await _controller.loadFromDisk(
      widget.currentUser.teamId,
    );
    if (mounted) {
      setState(() {
        _isOffline = !success;
        if (!success) {
          _errorMessage =
              'Gagal sinkronisasi. Menampilkan data lokal.';
        }
      });
    }
  }

  // Navigasi ke Halaman Editor
  void _goToEditor({LogModel? log, int? index}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogEditorPage(
          log: log,
          index: index,
          controller: _controller,
          currentUser: widget.currentUser,
          isOnline: !_isOffline, // pass status online ke editor
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
      body: Column(
        children: [
          // Banner offline
          if (_isOffline)
            Container(
              width: double.infinity,
              color: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage ?? 'Anda sedang offline. Menampilkan data lokal.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _initDatabase,
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text(
                      'Coba Lagi',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
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
          Expanded(
            child: ValueListenableBuilder<List<LogModel>>(
              valueListenable: _controller.logsNotifier,
              builder: (context, currentLogs, child) {
                if (_isLoading) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text(
                          'Menghubungkan ke server...',
                          style: TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mohon tunggu sebentar',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (currentLogs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image(image: const AssetImage("assets/images/empty.png")),
                        const SizedBox(height: 16),
                        Text(
                          _isOffline
                              ? 'Tidak ada data lokal tersimpan.'
                              : 'Belum ada catatan di Cloud.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => _goToEditor(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Buat Catatan Pertama'),
                        ),
                      ],
                    ),
                  );
                }


                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    itemCount: currentLogs.length,
                    itemBuilder: (context, index) {
                      final log = currentLogs[index];
                      final isOwn =
                          log.username == widget.currentUser.username;
                      final canEdit = AccessControlService.canPerform(
                        widget.currentUser.role,
                        AccessControlService.actionUpdate,
                        isOwner: isOwn,
                      );
                      final canDelete = AccessControlService.canPerform(
                        widget.currentUser.role,
                        AccessControlService.actionDelete,
                        isOwner: isOwn,
                      );
                      final dateStr = DateFormat('d MMM yyyy').format(log.date);

                      return Card(
                        child: ListTile(
                          leading: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.note, size: 20),
                              const SizedBox(height: 2),
                              // Ikon status sync: oranye = lokal, hijau = cloud
                              Icon(
                                log.isSynced
                                    ? Icons.cloud_done
                                    : Icons.cloud_upload,
                                size: 14,
                                color: log.isSynced
                                    ? Colors.green.shade600
                                    : Colors.orange.shade700,
                              ),
                            ],
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(log.title)),
                              const SizedBox(width: 6),
                              // Badge Public / Private
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: log.isPublic
                                      ? Colors.green.shade100
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      log.isPublic ? Icons.public : Icons.lock,
                                      size: 10,
                                      color: log.isPublic
                                          ? Colors.green.shade700
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      log.isPublic ? 'Publik' : 'Privat',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: log.isPublic
                                            ? Colors.green.shade700
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nama pemilik jika bukan milik sendiri
                              if (!isOwn)
                                Text(
                                  'oleh ${log.username}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              Text(
                                log.category,
                                style: TextStyle(
                                  color: getCategoryColor(log.category),
                                ),
                              ),
                              Text(log.description),
                              Text(
                                dateStr,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          trailing: Wrap(
                            children: [
                              if (canEdit)
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => _goToEditor(
                                    log: log,
                                    index: index,
                                  ),
                                ),
                              if (canDelete)
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
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _goToEditor(),
        child: const Icon(Icons.add),
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
              _controller.removeLog(log, isOnline: !_isOffline);
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
