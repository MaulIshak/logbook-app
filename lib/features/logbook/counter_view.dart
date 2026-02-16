import 'package:flutter/material.dart';
import 'package:my_logbook_app/features/onboarding/onboarding_view.dart';
import 'counter_controller.dart'; // Pastikan path import ini sesuai struktur folder Anda

class CounterView extends StatefulWidget {
  final String username;
  const CounterView({super.key, required this.username});

  @override
  State<CounterView> createState() => _CounterViewState();
}

class _CounterViewState extends State<CounterView> {
  // Instansiasi controller
  final CounterController _controller = CounterController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // Buat fungsi async terpisah agar kode bersih
  Future<void> _loadInitialData() async {
    await _controller.init(); // Tunggu loading dari disk selesai

    // Cek 'mounted' untuk mencegah error jika user sudah keluar layar sebelum loading selesai
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleIncrement() async {
    await _controller.increment();
    setState(() {});
  }

  Future<void> _handleDecrement() async {
    await _controller.decrement();
    setState(() {});
  }

  Future<void> _handleReset() async {
    await _controller.reset();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Menggunakan Theme data agar konsisten
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.grey[100], // Background abu-abu muda
      appBar: AppBar(
        title: Text("Logbook App: ${widget.username}"),
        elevation: 0,
        backgroundColor: Colors.blueGrey,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Selamat Datang, ${widget.username}",
              style: TextStyle(
                color: Colors.blueGrey,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            // BAGIAN 1: DISPLAY UTAMA
            _buildCounterDisplay(textTheme),

            const SizedBox(height: 20),

            // BAGIAN 2: KONTROL SLIDER
            _buildSliderSection(textTheme),

            const Divider(height: 40, thickness: 1.5),

            // BAGIAN 3: RIWAYAT / LOG
            Text(
              "Riwayat Aktivitas",
              style: textTheme.titleMedium?.copyWith(
                color: Colors.blueGrey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Render histories items
            if (_controller.histories.isEmpty)
              const Center(
                child: Text(
                  "Belum ada data log.",
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ..._controller.histories.reversed
                  .take(5)
                  .map((item) => _CounterHistoriesTile(historiesData: item)),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Tombol Reset (Kiri)
            FloatingActionButton.small(
              heroTag: "btn_reset",
              backgroundColor: Colors.grey,
              onPressed: _confirmReset,
              child: const Icon(Icons.refresh, color: Colors.white),
            ),
            // Grouping tombol aksi utama (Kanan)
            Row(
              children: [
                FloatingActionButton(
                  heroTag: "btn_dec",
                  backgroundColor: Colors.red[400],
                  onPressed: () => _handleDecrement(),
                  child: const Icon(Icons.remove, color: Colors.white),
                ),
                const SizedBox(width: 15),
                FloatingActionButton(
                  heroTag: "btn_inc",
                  backgroundColor: Colors.green[400],
                  onPressed: () => _handleIncrement(),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget Display Utama
  Widget _buildCounterDisplay(TextTheme textTheme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        child: Column(
          children: [
            Text(
              "Total Hitungan",
              style: textTheme.labelLarge?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              '${_controller.value}',
              style: textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget Slider Section
  Widget _buildSliderSection(TextTheme textTheme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Step Increment", style: textTheme.bodyLarge),
            Chip(
              label: Text("${_controller.step}"),
              backgroundColor: Colors.blueGrey[50],
            ),
          ],
        ),
        Slider(
          activeColor: Colors.blueGrey,
          inactiveColor: Colors.blueGrey[100],
          value: _controller.step.toDouble(),
          min: 0.0,
          max: 100.0,
          divisions: 100,
          label: _controller.step.toString(),
          onChanged: (double newValue) {
            setState(() {
              _controller.step = newValue.round();
            });
          },
        ),
      ],
    );
  }

  // Logic Konfirmasi Reset
  Future<void> _confirmReset() async {
    if (_controller.value == 0) return; // Prevent reset jika sudah 0

    final bool? shouldReset = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Konfirmasi Reset"),
          content: const Text(
            "Apakah Anda yakin ingin menghapus semua histories dan mengembalikan hitungan ke 0? Tindakan ini tidak dapat dibatalkan.",
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Batal"),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Ya, Reset"),
            ),
          ],
        );
      },
    );

    if (shouldReset == true) {
      await _handleReset();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Data berhasil di-reset"),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }
}

// Widget Histories Tile
class _CounterHistoriesTile extends StatelessWidget {
  final String historiesData;

  const _CounterHistoriesTile({required this.historiesData});

  @override
  Widget build(BuildContext context) {
    final parts = historiesData.split('|');
    final rawDate = parts.isNotEmpty ? parts.first : "Unknown";
    final action = parts.length > 1 ? parts.last : "?";

    final isIncrement = action.startsWith("+");
    final isDecrement = action.startsWith("-");

    final Color statusColor = isIncrement
        ? Colors.green
        : (isDecrement ? Colors.red : Colors.grey);
    final IconData statusIcon = isIncrement
        ? Icons.arrow_upward
        : (isDecrement ? Icons.arrow_downward : Icons.info_outline);
    final String displayDate = rawDate.replaceFirst('T', ' ').split('.').first;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.3),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Text(
          action,
          style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
        ),
        subtitle: Text(
          displayDate,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        dense: true,
      ),
    );
  }
}
