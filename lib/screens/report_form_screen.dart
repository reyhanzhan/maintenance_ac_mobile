import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:maintenance_ac_mobile/models/rumah_sakit_model.dart';
import 'package:maintenance_ac_mobile/services/api_service.dart';
import 'package:maintenance_ac_mobile/services/sync_manager.dart';
import 'package:maintenance_ac_mobile/widgets/loading_button.dart';

class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _picker = ImagePicker();

  static const _merkOptions = [
    'Daikin',
    'Panasonic',
    'LG',
    'Samsung',
    'Sharp',
    'Mitsubishi',
    'Gree',
    'Midea',
    'Lainnya',
  ];
  static const _typeOptions = [
    'Split',
    'Cassette',
    'Standing Floor',
    'Ceiling',
    'Window',
    'Central',
  ];

  SyncData? _syncData;
  int? _rumahSakitId;
  int? _ruanganId;
  String? _gedung;
  String? _merkAc;
  String? _typeAc;
  DateTime _tanggalService = DateTime.now();
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  final Map<String, bool> _normalValues = {};
  final Map<String, TextEditingController> _keteranganControllers = {};
  final List<XFile> _generalPhotos = [];
  final Map<String, List<XFile>> _itemPhotos = {};
  final TextEditingController _saranController = TextEditingController(
    text:
        'Servis rutin AC selesai, kondisi unit normal dan berfungsi dengan baik.',
  );

  @override
  void initState() {
    super.initState();
    _loadSyncData();
  }

  @override
  void dispose() {
    for (final controller in _keteranganControllers.values) {
      controller.dispose();
    }
    _saranController.dispose();
    super.dispose();
  }

  Future<void> _loadSyncData() async {
    setState(() => _isLoading = true);
    try {
      final data = await SyncManager.getSyncData();
      if (!mounted) return;
      if (data != null) {
        setState(() {
          _syncData = data;
          _isLoading = false;
        });
        _ensureChecklistState();
        return;
      }
      final onlineData = await _apiService.fetchSyncData();
      if (!mounted) return;
      setState(() {
        _syncData = onlineData;
        _isLoading = false;
      });
      _ensureChecklistState();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  List<RuanganModel> get _filteredRuangans {
    final data = _syncData;
    final rumahSakitId = _rumahSakitId;
    if (data == null || rumahSakitId == null) return const [];
    return data.ruangansByRumahSakitId[rumahSakitId] ?? const [];
  }

  RumahSakitModel? get _selectedRumahSakit {
    final data = _syncData;
    final rumahSakitId = _rumahSakitId;
    if (data == null || rumahSakitId == null) return null;
    for (final item in data.rumahSakits) {
      if (item.id == rumahSakitId) return item;
    }
    return null;
  }

  bool get _isSiloam =>
      _selectedRumahSakit?.nama.toLowerCase().contains('siloam') ?? false;

  List<PemeriksaanItemModel> get _activePemeriksaan {
    final data = _syncData;
    if (data == null) return const [];
    final isGedungBaru = (_gedung ?? '').toLowerCase() == 'baru';
    if (_isSiloam && isGedungBaru) {
      return data.pemeriksaanSiloamBaru;
    }
    return data.pemeriksaanDefault;
  }

  void _ensureChecklistState() {
    for (final item in _activePemeriksaan) {
      _normalValues.putIfAbsent(item.nomor, () => true);
      _keteranganControllers.putIfAbsent(
        item.nomor,
        () => TextEditingController(),
      );
      _itemPhotos.putIfAbsent(item.nomor, () => []);
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _tanggalService,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) {
      setState(() => _tanggalService = selected);
    }
  }

  Future<void> _pickGeneralPhoto(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final photos = await _picker.pickMultiImage(imageQuality: 80);
      if (photos.isNotEmpty) {
        setState(() => _generalPhotos.addAll(photos));
      }
      return;
    }

    final photo = await _picker.pickImage(source: source, imageQuality: 80);
    if (photo != null) {
      setState(() => _generalPhotos.add(photo));
    }
  }

  Future<void> _pickItemPhoto(String nomor, ImageSource source) async {
    final photo = await _picker.pickImage(source: source, imageQuality: 80);
    if (photo != null) {
      setState(() => _itemPhotos.putIfAbsent(nomor, () => []).add(photo));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _ensureChecklistState();

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final items = <String, ItemPayload>{};
      final itemPhotos = <String, List<XFile>>{};
      for (final item in _activePemeriksaan) {
        final isNormal = _normalValues[item.nomor] ?? true;
        items[item.nomor] = ItemPayload(
          isNormal: isNormal,
          keterangan:
              isNormal ? '' : (_keteranganControllers[item.nomor]?.text ?? ''),
        );
        if (!isNormal) {
          final photos = _itemPhotos[item.nomor] ?? const <XFile>[];
          if (photos.isNotEmpty) itemPhotos[item.nomor] = photos;
        }
      }

      await _apiService.postMultipartReport(
        fields: {
          'rumah_sakit_id': _rumahSakitId.toString(),
          'ruangan_id': _ruanganId.toString(),
          'gedung': _isSiloam ? (_gedung ?? '') : '',
          'merk_ac': _merkAc ?? '',
          'type_ac': _typeAc ?? '',
          'tanggal_service': DateFormat('yyyy-MM-dd').format(_tanggalService),
          'saran': _saranController.text.trim(),
        },
        items: items,
        generalPhotos: _generalPhotos,
        itemPhotos: itemPhotos,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Laporan berhasil dikirim')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: _ReportAppBar(),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_syncData == null) {
      return Scaffold(
        appBar: const _ReportAppBar(),
        body: _ErrorState(message: _error ?? 'Gagal memuat data sinkron.'),
      );
    }

    _ensureChecklistState();
    final dateText = DateFormat('yyyy-MM-dd').format(_tanggalService);
    final filteredRuangans = _filteredRuangans;

    return Scaffold(
      appBar: const _ReportAppBar(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              _InlineError(message: _error!),
              const SizedBox(height: 12),
            ],
            _Section(
              title: 'Lokasi',
              children: [
                _SearchablePickerField<RumahSakitModel>(
                  label: 'Rumah Sakit',
                  searchHint: 'Cari rumah sakit...',
                  placeholder: '-- Pilih Rumah Sakit --',
                  value: _selectedRumahSakit,
                  options: _syncData!.rumahSakits,
                  optionLabel: (item) => item.nama,
                  onChanged: (value) {
                    setState(() {
                      _rumahSakitId = value?.id;
                      _ruanganId = null;
                      if (value == null ||
                          !value.nama.toLowerCase().contains('siloam')) {
                        _gedung = null;
                      }
                    });
                    _ensureChecklistState();
                  },
                  validator:
                      (value) =>
                          value == null ? 'Rumah sakit wajib dipilih' : null,
                ),
                const SizedBox(height: 12),
                _SearchablePickerField<RuanganModel>(
                  label: 'Ruangan',
                  searchHint: 'Cari ruangan...',
                  placeholder:
                      _rumahSakitId == null
                          ? 'Pilih rumah sakit dulu'
                          : '-- Pilih Ruangan --',
                  value:
                      filteredRuangans
                              .where((item) => item.id == _ruanganId)
                              .isEmpty
                          ? null
                          : filteredRuangans.firstWhere(
                            (item) => item.id == _ruanganId,
                          ),
                  options: filteredRuangans,
                  optionLabel: (item) => item.nama,
                  enabled: _rumahSakitId != null && filteredRuangans.isNotEmpty,
                  emptyText: 'Ruangan belum tersedia',
                  onChanged: (value) => setState(() => _ruanganId = value?.id),
                  validator:
                      (value) => value == null ? 'Ruangan wajib dipilih' : null,
                ),
                if (_isSiloam) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _gedung,
                    decoration: const InputDecoration(labelText: 'Gedung'),
                    items: const [
                      DropdownMenuItem(value: 'Baru', child: Text('Baru')),
                      DropdownMenuItem(value: 'Lama', child: Text('Lama')),
                    ],
                    onChanged: (value) {
                      setState(() => _gedung = value);
                      _ensureChecklistState();
                    },
                    validator:
                        (value) =>
                            value == null ? 'Gedung wajib dipilih' : null,
                  ),
                ],
              ],
            ),
            _Section(
              title: 'Data AC',
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _merkAc,
                  decoration: const InputDecoration(labelText: 'Merk AC'),
                  items:
                      _merkOptions
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _merkAc = value),
                  validator:
                      (value) => value == null ? 'Merk AC wajib dipilih' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _typeAc,
                  decoration: const InputDecoration(labelText: 'Type AC'),
                  items:
                      _typeOptions
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _typeAc = value),
                  validator:
                      (value) => value == null ? 'Type AC wajib dipilih' : null,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tanggal Service',
                      suffixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    child: Text(dateText),
                  ),
                ),
              ],
            ),
            _Section(
              title: 'Checklist Pemeriksaan',
              children:
                  _activePemeriksaan.isEmpty
                      ? [const Text('Checklist pemeriksaan belum tersedia.')]
                      : _activePemeriksaan
                          .map(
                            (item) => _ChecklistItem(
                              item: item,
                              isNormal: _normalValues[item.nomor] ?? true,
                              controller: _keteranganControllers[item.nomor]!,
                              photos: _itemPhotos[item.nomor] ?? const [],
                              onNormalChanged:
                                  (value) => setState(() {
                                    _normalValues[item.nomor] = value;
                                    if (value) {
                                      _keteranganControllers[item.nomor]
                                          ?.clear();
                                      _itemPhotos[item.nomor]?.clear();
                                    }
                                  }),
                              onPickPhoto:
                                  (source) =>
                                      _pickItemPhoto(item.nomor, source),
                              onRemovePhoto:
                                  (index) => setState(
                                    () => _itemPhotos[item.nomor]!.removeAt(
                                      index,
                                    ),
                                  ),
                            ),
                          )
                          .toList(),
            ),
            _Section(
              title: 'Foto Umum',
              children: [
                _PhotoActions(onPick: _pickGeneralPhoto),
                _PhotoChips(
                  photos: _generalPhotos,
                  onRemove:
                      (index) => setState(() => _generalPhotos.removeAt(index)),
                ),
              ],
            ),
            _Section(
              title: 'Uraian Pekerjaan',
              children: [
                TextField(
                  controller: _saranController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Uraian pekerjaan',
                    hintText:
                        'Servis rutin AC selesai, kondisi unit normal dan berfungsi dengan baik.',
                  ),
                ),
              ],
            ),
            LoadingButton(
              isLoading: _isSubmitting,
              onPressed: _submit,
              label: 'Kirim Laporan',
              icon: Icons.cloud_upload_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchablePickerField<T> extends StatelessWidget {
  const _SearchablePickerField({
    super.key,
    required this.label,
    required this.searchHint,
    required this.placeholder,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.emptyText = 'Tidak ditemukan',
  });

  final String label;
  final String searchHint;
  final String placeholder;
  final T? value;
  final List<T> options;
  final String Function(T value) optionLabel;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;
  final bool enabled;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      initialValue: value,
      validator: (_) => validator?.call(value),
      builder: (field) {
        final selected = value;
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap:
              enabled
                  ? () async {
                    final picked = await _showPicker(context);
                    if (picked == null || !context.mounted) return;
                    field.didChange(picked);
                    onChanged(picked);
                  }
                  : null,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              errorText: field.errorText,
              suffixIcon: const Icon(Icons.keyboard_arrow_down_outlined),
            ),
            child: Text(
              selected == null ? placeholder : optionLabel(selected),
              style: TextStyle(
                color:
                    enabled
                        ? selected == null
                            ? Colors.grey.shade600
                            : null
                        : Colors.grey.shade500,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<T?> _showPicker(BuildContext context) async {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (context) => _SearchablePickerSheet<T>(
            searchHint: searchHint,
            options: options,
            optionLabel: optionLabel,
            emptyText: emptyText,
          ),
    );
  }
}

class _SearchablePickerSheet<T> extends StatefulWidget {
  const _SearchablePickerSheet({
    required this.searchHint,
    required this.options,
    required this.optionLabel,
    required this.emptyText,
  });

  final String searchHint;
  final List<T> options;
  final String Function(T value) optionLabel;
  final String emptyText;

  @override
  State<_SearchablePickerSheet<T>> createState() =>
      _SearchablePickerSheetState<T>();
}

class _SearchablePickerSheetState<T> extends State<_SearchablePickerSheet<T>> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase();
    final filtered =
        widget.options
            .where(
              (item) => widget.optionLabel(item).toLowerCase().contains(query),
            )
            .toList();

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.75,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Expanded(
                child:
                    filtered.isEmpty
                        ? Center(child: Text(widget.emptyText))
                        : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return ListTile(
                              title: Text(widget.optionLabel(item)),
                              onTap: () => Navigator.of(context).pop(item),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ReportAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('Buat Laporan'));
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({
    required this.item,
    required this.isNormal,
    required this.controller,
    required this.photos,
    required this.onNormalChanged,
    required this.onPickPhoto,
    required this.onRemovePhoto,
  });

  final PemeriksaanItemModel item;
  final bool isNormal;
  final TextEditingController controller;
  final List<XFile> photos;
  final ValueChanged<bool> onNormalChanged;
  final ValueChanged<ImageSource> onPickPhoto;
  final ValueChanged<int> onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${item.nomor}. ${item.nama}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (item.desc != null && item.desc!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(item.desc!, style: Theme.of(context).textTheme.bodySmall),
          ],
          SwitchListTile(
            value: isNormal,
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(isNormal ? 'Normal' : 'Tidak normal'),
            onChanged: onNormalChanged,
          ),
          if (!isNormal) ...[
            TextField(
              controller: controller,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Keterangan',
                hintText: 'Catatan kondisi tidak normal',
              ),
            ),
            const SizedBox(height: 10),
            _PhotoActions(onPick: onPickPhoto),
            _PhotoChips(photos: photos, onRemove: onRemovePhoto),
          ],
        ],
      ),
    );
  }
}

class _PhotoActions extends StatelessWidget {
  const _PhotoActions({required this.onPick});

  final ValueChanged<ImageSource> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => onPick(ImageSource.camera),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Kamera'),
        ),
        OutlinedButton.icon(
          onPressed: () => onPick(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Galeri'),
        ),
      ],
    );
  }
}

class _PhotoChips extends StatelessWidget {
  const _PhotoChips({required this.photos, required this.onRemove});

  final List<XFile> photos;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < photos.length; i++)
            Chip(label: Text('Foto ${i + 1}'), onDeleted: () => onRemove(i)),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: TextStyle(color: Colors.red.shade800)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
