import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../hive_model.dart';
import '../services/hive_repository.dart';

// ============================================================================
// DINAMIKUS TÖRZSADAT MODELL (Adatbázis elemekhez)
// ============================================================================
class CatalogItem {
  final String category;
  final String code;
  final String label;
  final String? defaultSize;
  final String iconName;
  final String colorHex;
  final int sortOrder;

  CatalogItem({
    required this.category,
    required this.code,
    required this.label,
    this.defaultSize,
    this.iconName = 'hive',
    this.colorHex = '#FFD740',
    this.sortOrder = 0,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(
      category: json['category'] ?? '',
      code: json['code'] ?? '',
      label: json['label'] ?? '',
      defaultSize: json['default_size'],
      iconName: json['icon_name'] ?? 'hive',
      colorHex: json['color_hex'] ?? '#FFD740',
      sortOrder: json['sort_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'category': category,
    'code': code,
    'label': label,
    'default_size': defaultSize,
    'icon_name': iconName,
    'color_hex': colorHex,
    'sort_order': sortOrder,
  };

  Color get color {
    try {
      final clean = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.amberAccent;
    }
  }

  IconData get icon {
    switch (iconName) {
      case 'breakfast_dining':
        return Icons.breakfast_dining;
      case 'local_florist':
        return Icons.local_florist;
      case 'texture':
        return Icons.texture;
      case 'water_drop':
        return Icons.water_drop;
      case 'workspace_premium':
        return Icons.workspace_premium;
      case 'male':
        return Icons.male;
      case 'bolt':
        return Icons.bolt;
      case 'child_care':
        return Icons.child_care;
      case 'group':
        return Icons.group;
      case 'inventory_2':
        return Icons.inventory_2;
      case 'extension':
        return Icons.extension;
      case 'air':
        return Icons.air;
      case 'medication':
        return Icons.medication;
      case 'roofing':
        return Icons.roofing;
      case 'bug_report':
        return Icons.bug_report;
      case 'cloud':
        return Icons.cloud;
      case 'pest_control':
        return Icons.pest_control;
      case 'opacity':
        return Icons.opacity;
      case 'layers':
        return Icons.layers;
      case 'location_on':
        return Icons.location_on;
      default:
        return Icons.hive;
    }
  }
}

// ============================================================================
// IRODAI VEZÉRLŐPULT KÉPERNYŐ
// ============================================================================
class OfficeDashboardScreen extends StatefulWidget {
  final HiveRepository repository;

  const OfficeDashboardScreen({super.key, required this.repository});

  @override
  State<OfficeDashboardScreen> createState() => _OfficeDashboardScreenState();
}

class _OfficeDashboardScreenState extends State<OfficeDashboardScreen> {
  late String _selectedSiteCode;
  bool _showSiteHiveList = false;

  final List<CatalogItem> _catalogs = [
    CatalogItem(
      category: 'site',
      code: 'site_main',
      label: 'Fő telephely (Időjárás-állomás & Szerver)',
      iconName: 'location_on',
      colorHex: '#FFD740',
    ),
    CatalogItem(
      category: 'site',
      code: 'site_ext_1',
      label: 'Telephely #2 (Külső)',
      iconName: 'location_on',
      colorHex: '#64FFDA',
    ),
    CatalogItem(
      category: 'family_function',
      code: 'meztermeles',
      label: 'Méztermelés',
      iconName: 'breakfast_dining',
      colorHex: '#FFD740',
    ),
    CatalogItem(
      category: 'family_function',
      code: 'viragpor',
      label: 'Virágpor',
      iconName: 'local_florist',
      colorHex: '#FFAB40',
    ),
    CatalogItem(
      category: 'family_function',
      code: 'propolisz',
      label: 'Propolisz',
      iconName: 'texture',
      colorHex: '#A1887F',
    ),
    CatalogItem(
      category: 'family_function',
      code: 'mehpempo',
      label: 'Méhpempő',
      iconName: 'water_drop',
      colorHex: '#40C4FF',
    ),
    CatalogItem(
      category: 'family_function',
      code: 'anyacsalad',
      label: 'Anyacsalád',
      iconName: 'workspace_premium',
      colorHex: '#E040FB',
    ),
    CatalogItem(
      category: 'family_function',
      code: 'apacsalad',
      label: 'Apacsalád',
      iconName: 'male',
      colorHex: '#448AFF',
    ),
    CatalogItem(
      category: 'family_function',
      code: 'starter',
      label: 'Starter',
      iconName: 'bolt',
      colorHex: '#FFFF00',
    ),
    CatalogItem(
      category: 'family_function',
      code: 'dajka',
      label: 'Dajkacsalád',
      iconName: 'child_care',
      colorHex: '#FF4081',
    ),
    CatalogItem(
      category: 'family_function',
      code: 'donor',
      label: 'Donor család',
      iconName: 'group',
      colorHex: '#64FFDA',
    ),
    CatalogItem(
      category: 'box_type',
      code: 'brood_box',
      label: 'Fészekfiók',
      defaultSize: 'dadant',
      iconName: 'inventory_2',
      colorHex: '#64FFDA',
    ),
    CatalogItem(
      category: 'box_type',
      code: 'honey',
      label: 'Méztér',
      defaultSize: '1/2 dadant',
      iconName: 'inventory_2',
      colorHex: '#FFD740',
    ),
    CatalogItem(
      category: 'accessory_type',
      code: 'feeder',
      label: 'Etető',
      defaultSize: 'dadant',
      iconName: 'extension',
      colorHex: '#40C4FF',
    ),
    CatalogItem(
      category: 'accessory_type',
      code: 'escapement',
      label: 'Szöktető',
      defaultSize: 'dadant',
      iconName: 'extension',
      colorHex: '#40C4FF',
    ),
    CatalogItem(
      category: 'accessory_type',
      code: 'vent',
      label: 'Szellőző',
      defaultSize: 'dadant',
      iconName: 'air',
      colorHex: '#40C4FF',
    ),
    CatalogItem(
      category: 'accessory_type',
      code: 'pollen_trap',
      label: 'Virágporgyűjtő',
      defaultSize: 'dadant',
      iconName: 'local_florist',
      colorHex: '#FFAB40',
    ),
    CatalogItem(
      category: 'accessory_type',
      code: 'treatment_strip',
      label: 'Kezelőlap hordozó',
      defaultSize: 'dadant',
      iconName: 'medication',
      colorHex: '#E040FB',
    ),
    CatalogItem(
      category: 'accessory_type',
      code: 'roof',
      label: 'Tető',
      defaultSize: 'dadant',
      iconName: 'roofing',
      colorHex: '#90A4AE',
    ),
    CatalogItem(
      category: 'protocol',
      code: 'none',
      label: 'Nincs aktív kezelés',
      iconName: 'hive',
      colorHex: '#9E9E9E',
    ),
    CatalogItem(
      category: 'protocol',
      code: 'oxalsav_egyszeri',
      label: 'Oxálsav (egyszeri)',
      iconName: 'cloud',
      colorHex: '#40C4FF',
    ),
    CatalogItem(
      category: 'protocol',
      code: 'oxalsav_sorozat',
      label: 'Oxálsav (sorozat)',
      iconName: 'cloud',
      colorHex: '#00B0FF',
    ),
    CatalogItem(
      category: 'protocol',
      code: 'hangyasav',
      label: 'Hangyasav',
      iconName: 'pest_control',
      colorHex: '#FF5252',
    ),
    CatalogItem(
      category: 'protocol',
      code: 'tarto_hordozo',
      label: 'Tartós hordozó (csík)',
      iconName: 'medication',
      colorHex: '#E040FB',
    ),
    CatalogItem(
      category: 'feed_type',
      code: 'szirup_1_1',
      label: 'Cukorszirup 1:1 (Serkentő)',
      defaultSize: 'liter',
      iconName: 'opacity',
      colorHex: '#FFAB40',
    ),
    CatalogItem(
      category: 'feed_type',
      code: 'szirup_3_2',
      label: 'Cukorszirup 3:2 (Téli élelem)',
      defaultSize: 'liter',
      iconName: 'opacity',
      colorHex: '#FF6D00',
    ),
    CatalogItem(
      category: 'feed_type',
      code: 'invert_szirup',
      label: 'Invertszirup',
      defaultSize: 'liter',
      iconName: 'water_drop',
      colorHex: '#FFD740',
    ),
    CatalogItem(
      category: 'feed_type',
      code: 'cukorlepeny',
      label: 'Cukorlepény (Natúr)',
      defaultSize: 'kg',
      iconName: 'layers',
      colorHex: '#FFF59D',
    ),
    CatalogItem(
      category: 'feed_type',
      code: 'pollen_lepeny',
      label: 'Virágporos lepény',
      defaultSize: 'kg',
      iconName: 'local_florist',
      colorHex: '#DCE775',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedSiteCode = _getByCategory('site').first.code;
  }

  List<CatalogItem> _getByCategory(String category) {
    return _catalogs.where((c) => c.category == category).toList();
  }

  CatalogItem _resolveFunctionItem(String? rawCode) {
    final clean = (rawCode ?? 'meztermeles').trim().toLowerCase();
    final functions = _getByCategory('family_function');
    for (final item in functions) {
      if (item.code == clean) return item;
    }
    if (clean == 'gyujto_mez' || clean == 'méz') {
      return functions.firstWhere(
        (e) => e.code == 'meztermeles',
        orElse: () => functions.first,
      );
    }
    if (clean == 'viragpor_termeles' || clean == 'pollen') {
      return functions.firstWhere(
        (e) => e.code == 'viragpor',
        orElse: () => functions.first,
      );
    }
    return functions.first;
  }

  List<HiveData> _getHivesForSelectedSite() {
    if (_selectedSiteCode == 'site_main') {
      return widget.repository.hives;
    }
    return [];
  }

  int _getNextAvailableSerial(String prefix) {
    int maxSerial = 0;
    final RegExp regex = RegExp('^${prefix}_(\\d+)\$');

    for (final hive in widget.repository.hives) {
      for (final box in hive.boxes) {
        final match1 = regex.firstMatch(box.code.trim());
        if (match1 != null) {
          final val = int.tryParse(match1.group(1)!) ?? 0;
          if (val > maxSerial) maxSerial = val;
        }
        if (box.secondaryCode != null) {
          final match2 = regex.firstMatch(box.secondaryCode!.trim());
          if (match2 != null) {
            final val = int.tryParse(match2.group(1)!) ?? 0;
            if (val > maxSerial) maxSerial = val;
          }
        }
      }
    }
    return maxSerial + 1;
  }

  String _formatCode(String prefix, int number) {
    return '${prefix}_${number.toString().padLeft(7, '0')}';
  }

  // ==========================================================================
  // 1. KÓDGENERÁLÁS DIalógus
  // ==========================================================================
  void _showCodeGenerationDialog() {
    String printPrefix = 'B';
    int sheetsCount = 1;
    bool isGenerating = false;
    final TextEditingController sheetsCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final int nextSerial = _getNextAvailableSerial(printPrefix);
            final int validSheets = sheetsCount > 0 ? sheetsCount : 1;
            final int totalLabelsPreview = validSheets * 6;
            final String firstPreview = _formatCode(printPrefix, nextSerial);
            final String lastPreview = _formatCode(
              printPrefix,
              nextSerial + totalLabelsPreview - 1,
            );

            Future<void> generatePdf() async {
              if (sheetsCount <= 0) return;

              setDialogState(() => isGenerating = true);
              try {
                await widget.repository.syncWithSupabase();
                final int startSerial = _getNextAvailableSerial(printPrefix);
                final int totalLabels = sheetsCount * 6;
                final List<String> codesToPrint = List.generate(
                  totalLabels,
                  (index) => _formatCode(printPrefix, startSerial + index),
                );

                final pdf = pw.Document();
                for (int pageIndex = 0; pageIndex < sheetsCount; pageIndex++) {
                  final pageCodes = codesToPrint
                      .skip(pageIndex * 6)
                      .take(6)
                      .toList();
                  pdf.addPage(
                    pw.Page(
                      pageFormat: PdfPageFormat.a4,
                      margin: const pw.EdgeInsets.all(15 * PdfPageFormat.mm),
                      build: (pw.Context context) {
                        return pw.GridView(
                          crossAxisCount: 2,
                          childAspectRatio: 0.98,
                          crossAxisSpacing: 10 * PdfPageFormat.mm,
                          mainAxisSpacing: 10 * PdfPageFormat.mm,
                          children: pageCodes.map((code) {
                            final String typeLabel = printPrefix == 'B'
                                ? 'FIOK (BOX)'
                                : printPrefix == 'A'
                                ? 'KELLEK'
                                : 'HORDÓ / VÖDÖR';
                            return pw.Container(
                              padding: const pw.EdgeInsets.all(
                                6 * PdfPageFormat.mm,
                              ),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(
                                  color: PdfColors.grey700,
                                  width: 1.5,
                                ),
                                borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(8),
                                ),
                              ),
                              child: pw.Column(
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  pw.Text(
                                    typeLabel,
                                    style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.grey700,
                                    ),
                                  ),
                                  pw.SizedBox(height: 3 * PdfPageFormat.mm),
                                  pw.BarcodeWidget(
                                    barcode: pw.Barcode.qrCode(
                                      errorCorrectLevel:
                                          pw.BarcodeQRCorrectionLevel.high,
                                    ),
                                    data: code,
                                    width: 48 * PdfPageFormat.mm,
                                    height: 48 * PdfPageFormat.mm,
                                  ),
                                  pw.SizedBox(height: 3 * PdfPageFormat.mm),
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: const pw.BoxDecoration(
                                      color: PdfColors.grey200,
                                      borderRadius: pw.BorderRadius.all(
                                        pw.Radius.circular(4),
                                      ),
                                    ),
                                    child: pw.Text(
                                      code,
                                      style: pw.TextStyle(
                                        fontSize: 16,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  );
                }

                final Uint8List pdfBytes = await pdf.save();
                if (ctx.mounted) Navigator.pop(ctx);

                await Printing.layoutPdf(
                  onLayout: (PdfPageFormat format) async => pdfBytes,
                  name:
                      'QR_Cimkek_${printPrefix}_${codesToPrint.first}-${codesToPrint.last}.pdf',
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Hiba a PDF generálásakor: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } finally {
                if (ctx.mounted) {
                  setDialogState(() => isGenerating = false);
                }
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF141428),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.amberAccent, width: 1.5),
              ),
              title: const Row(
                children: [
                  Icon(Icons.print, color: Colors.amberAccent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Kódgenerálás (A4 Címkék)',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: printPrefix,
                    dropdownColor: const Color(0xFF0F172A),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Előtag (Típus)',
                      labelStyle: const TextStyle(color: Colors.amber),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'B',
                        child: Text('B_ – Fiók (Box)'),
                      ),
                      DropdownMenuItem(value: 'A', child: Text('A_ – Kellék')),
                      DropdownMenuItem(
                        value: 'C',
                        child: Text('C_ – Hordó / Vödör'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => printPrefix = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sheetsCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: 'A4-es lapok száma (6 matrica / lap)',
                      helperText: 'Összesen: $totalLabelsPreview db matrica',
                      helperStyle: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 11,
                      ),
                      labelStyle: const TextStyle(color: Colors.amber),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val.trim()) ?? 0;
                      setDialogState(() {
                        sheetsCount = parsed;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tartomány:',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          '$firstPreview -> $lastPreview',
                          style: const TextStyle(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Mégse',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: (isGenerating || sheetsCount <= 0)
                      ? null
                      : generatePdf,
                  icon: isGenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf),
                  label: const Text(
                    'PDF Generálása',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================================================
  // 2. MEGLÉVŐ KÓD ÚJRANYOMTATÁSA
  // ==========================================================================
  void _showReprintSingleCodeDialog() {
    final TextEditingController searchCtrl = TextEditingController();
    bool isScanningForReprint = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> executePrint(String codeClean) async {
              final codeUpper = codeClean.trim().toUpperCase();
              if (codeUpper.isEmpty) return;

              final foundElement = widget.repository.findElementByCode(
                codeUpper,
              );
              String labelText = 'FIÓK / KELLÉK / TÁROLÓ';
              String detailsText = 'Azonosító: $codeUpper';

              if (foundElement != null) {
                if (foundElement is BoxElement) {
                  labelText = foundElement.name;
                  detailsText = 'Méret: ${foundElement.size} • Kód: $codeUpper';
                } else if (foundElement is HiveData) {
                  labelText = 'Kaptár: ${foundElement.name}';
                  detailsText = 'Család: ${foundElement.familyFunction}';
                } else if (foundElement is Map &&
                    foundElement.containsKey('hive')) {
                  final HiveData h = foundElement['hive'];
                  final BoxElement? b = foundElement['box'];
                  labelText = b != null ? '${b.name} (${h.name})' : h.name;
                  detailsText = 'Kód: $codeUpper';
                }
              }

              if (ctx.mounted) Navigator.pop(ctx);

              final pdf = pw.Document();
              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat.a4,
                  margin: const pw.EdgeInsets.all(20 * PdfPageFormat.mm),
                  build: (pw.Context context) {
                    return pw.Center(
                      child: pw.Container(
                        width: 100 * PdfPageFormat.mm,
                        height: 120 * PdfPageFormat.mm,
                        padding: const pw.EdgeInsets.all(8 * PdfPageFormat.mm),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            color: PdfColors.black,
                            width: 2,
                          ),
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(12),
                          ),
                        ),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text(
                              labelText,
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey800,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                            pw.SizedBox(height: 5 * PdfPageFormat.mm),
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(
                                errorCorrectLevel:
                                    pw.BarcodeQRCorrectionLevel.high,
                              ),
                              data: codeUpper,
                              width: 65 * PdfPageFormat.mm,
                              height: 65 * PdfPageFormat.mm,
                            ),
                            pw.SizedBox(height: 5 * PdfPageFormat.mm),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: const pw.BoxDecoration(
                                color: PdfColors.grey200,
                                borderRadius: pw.BorderRadius.all(
                                  pw.Radius.circular(4),
                                ),
                              ),
                              child: pw.Text(
                                codeUpper,
                                style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black,
                                ),
                              ),
                            ),
                            pw.SizedBox(height: 3 * PdfPageFormat.mm),
                            pw.Text(
                              detailsText,
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey600,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );

              final Uint8List pdfBytes = await pdf.save();
              await Printing.layoutPdf(
                onLayout: (PdfPageFormat format) async => pdfBytes,
                name: 'QR_Ujranyomtatott_$codeUpper.pdf',
              );
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF141428),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.tealAccent, width: 1.5),
              ),
              title: const Row(
                children: [
                  Icon(Icons.qr_code, color: Colors.tealAccent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Meglévő QR-kód Újranyomtatása',
                      style: TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Olvasd be a meglévő, sérült QR-kódot a kamerával, vagy írd be a kódját (pl. B_, A_ vagy C_). Az app visszahúzza az összerendelést, és generál egy friss nyomtatási képet.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  if (isScanningForReprint) ...[
                    SizedBox(
                      height: 220,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: MobileScanner(
                          onDetect: (capture) {
                            final barcodes = capture.barcodes;
                            if (barcodes.isNotEmpty &&
                                barcodes.first.rawValue != null) {
                              final scanned = barcodes.first.rawValue!;
                              executePrint(scanned);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () =>
                          setDialogState(() => isScanningForReprint = false),
                      child: const Text('Kamera bezárása'),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 44),
                      ),
                      onPressed: () =>
                          setDialogState(() => isScanningForReprint = true),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text(
                        'QR-kód beolvasása kamerával',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: searchCtrl,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        labelText: 'Vagy írd be a kódot (pl. C_0000001)',
                        labelStyle: const TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onSubmitted: (val) => executePrint(val),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => executePrint(searchCtrl.text),
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Kinyomtatás'),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Mégse',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openRegistrationPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemRegistrationScreen(
          repository: widget.repository,
          catalogs: _catalogs,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _showAddCatalogItemDialog() {
    String selectedCategory = 'feed_type';
    final TextEditingController codeCtrl = TextEditingController();
    final TextEditingController labelCtrl = TextEditingController();
    final TextEditingController sizeCtrl = TextEditingController(text: 'liter');
    String selectedColor = '#FFD740';

    final Map<String, String> categoryNames = {
      'feed_type': 'Etetőanyag (Szirup / Lepény)',
      'family_function': 'Család feladata / funkciója',
      'box_type': 'Fiók típusa (B_)',
      'accessory_type': 'Kellék típusa (A_)',
      'protocol': 'Kezelés fajtája (Protokoll)',
      'site': 'Telephely (Időjárás-állomás & Szerver)',
    };

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF141428),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.amberAccent, width: 1.5),
              ),
              title: const Row(
                children: [
                  Icon(Icons.storage, color: Colors.amberAccent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Új Típus Felvétele',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Kategória',
                        labelStyle: const TextStyle(color: Colors.tealAccent),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: categoryNames.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedCategory = val;
                            if (val == 'box_type' || val == 'accessory_type') {
                              sizeCtrl.text = 'dadant';
                            } else if (val == 'feed_type') {
                              sizeCtrl.text = 'liter';
                            } else {
                              sizeCtrl.text = '';
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: labelCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Megnevezés (pl. Gyógynövényes szirup)',
                        labelStyle: const TextStyle(color: Colors.amber),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (val) {
                        final autoCode = val
                            .toLowerCase()
                            .replaceAll('á', 'a')
                            .replaceAll('é', 'e')
                            .replaceAll('í', 'i')
                            .replaceAll('ó', 'o')
                            .replaceAll('ö', 'o')
                            .replaceAll('ő', 'o')
                            .replaceAll('ú', 'u')
                            .replaceAll('ü', 'u')
                            .replaceAll('ű', 'u')
                            .replaceAll(RegExp(r'[^a-z0-9]'), '_');
                        codeCtrl.text = autoCode;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeCtrl,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Adatbázis kulcs (code)',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Mégse',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final label = labelCtrl.text.trim();
                    final code = codeCtrl.text.trim();
                    if (label.isEmpty || code.isEmpty) return;

                    setState(() {
                      _catalogs.add(
                        CatalogItem(
                          category: selectedCategory,
                          code: code,
                          label: label,
                          defaultSize: sizeCtrl.text.trim().isEmpty
                              ? null
                              : sizeCtrl.text.trim(),
                          iconName: selectedCategory == 'feed_type'
                              ? 'opacity'
                              : selectedCategory == 'box_type'
                              ? 'inventory_2'
                              : selectedCategory == 'accessory_type'
                              ? 'extension'
                              : 'hive',
                          colorHex: selectedColor,
                        ),
                      );
                    });

                    widget.repository.syncWithSupabase();
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text(
                    'Mentés',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sites = _getByCategory('site');
    final siteHives = _getHivesForSelectedSite();

    final Map<String, int> functionCounts = {};
    for (final hive in siteHives) {
      final resolved = _resolveFunctionItem(hive.familyFunction);
      functionCounts[resolved.code] = (functionCounts[resolved.code] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141428),
        foregroundColor: Colors.amberAccent,
        title: const Row(
          children: [
            Icon(Icons.desktop_windows, color: Colors.amberAccent, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Iroda',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.tealAccent),
            tooltip: 'Szinkronizálás a Supabase-szel',
            onPressed: () async {
              await widget.repository.syncWithSupabase();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF141428),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Colors.amberAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Telephely:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedSiteCode,
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: sites
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.code,
                              child: Text(s.label),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null)
                          setState(() => _selectedSiteCode = val);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF141428),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.hive,
                        color: Colors.amberAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Családok funkció szerint (${siteHives.length} db)',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (siteHives.isNotEmpty)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.tealAccent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            setState(() {
                              _showSiteHiveList = !_showSiteHiveList;
                            });
                          },
                          icon: Icon(
                            _showSiteHiveList
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 16,
                          ),
                          label: Text(
                            _showSiteHiveList ? 'Elrejtés' : 'Kaptárlista',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (siteHives.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Ezen a telephelyen jelenleg nincs rögzített kaptár.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    )
                  else ...[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const double spacing = 8.0;
                        final double itemWidth =
                            (constraints.maxWidth - (spacing * 2)) / 3;

                        final activeEntries = functionCounts.entries
                            .where((entry) => entry.value > 0)
                            .toList();

                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: activeEntries.map((entry) {
                            final item = _resolveFunctionItem(entry.key);
                            return SizedBox(
                              width: itemWidth,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: item.color.withAlpha(80),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      item.icon,
                                      color: item.color,
                                      size: 18,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${entry.value} db',
                                      style: TextStyle(
                                        color: item.color,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.label,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    if (_showSiteHiveList) ...[
                      const Divider(color: Colors.white12, height: 24),
                      ...siteHives.map((hive) {
                        final item = _resolveFunctionItem(hive.familyFunction);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(item.icon, color: item.color, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    hive.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: item.color.withAlpha(30),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    color: item.color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _showCodeGenerationDialog,
                icon: const Icon(Icons.print, size: 20),
                label: const Text(
                  'Új Kódok Generálása (A4 Lapok)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _showReprintSingleCodeDialog,
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                label: const Text(
                  'Meglévő QR-kód Újranyomtatása',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.amberAccent,
                  side: const BorderSide(color: Colors.amberAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _openRegistrationPage,
                icon: const Icon(Icons.add_task, size: 20),
                label: const Text(
                  'Új elem regisztrációja (Varázsló)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amberAccent,
                  side: const BorderSide(color: Colors.amberAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _showAddCatalogItemDialog,
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text(
                  'Új típus felvétele katalógusba',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DEDIKÁLT KÉPERNYŐ: ÚJ OBJEKTUMOK REGISZTRÁCIÓJA
// ============================================================================
class ItemRegistrationScreen extends StatefulWidget {
  final HiveRepository repository;
  final List<CatalogItem> catalogs;

  const ItemRegistrationScreen({
    super.key,
    required this.repository,
    required this.catalogs,
  });

  @override
  State<ItemRegistrationScreen> createState() => _ItemRegistrationScreenState();
}

class _ItemRegistrationScreenState extends State<ItemRegistrationScreen> {
  int _currentStep = 0;
  bool _isCameraScanning = false;

  String _scannedQr = '';
  String _scannedNfc = '';
  String _detectedCategory = 'box_type';

  final TextEditingController _manualQrCtrl = TextEditingController();
  final TextEditingController _manualNfcCtrl = TextEditingController();

  final List<BoxElement> _sessionRegisteredItems = [];

  @override
  void dispose() {
    _manualQrCtrl.dispose();
    _manualNfcCtrl.dispose();
    super.dispose();
  }

  int _getNextAvailableSerial(String prefix) {
    int maxSerial = 0;
    final RegExp regex = RegExp('^${prefix}_(\\d+)\$');

    for (final hive in widget.repository.hives) {
      for (final box in hive.boxes) {
        final match1 = regex.firstMatch(box.code.trim());
        if (match1 != null) {
          final val = int.tryParse(match1.group(1)!) ?? 0;
          if (val > maxSerial) maxSerial = val;
        }
        if (box.secondaryCode != null) {
          final match2 = regex.firstMatch(box.secondaryCode!.trim());
          if (match2 != null) {
            final val = int.tryParse(match2.group(1)!) ?? 0;
            if (val > maxSerial) maxSerial = val;
          }
        }
      }
    }
    return maxSerial + 1;
  }

  String _formatCode(String prefix, int number) {
    return '${prefix}_${number.toString().padLeft(7, '0')}';
  }

  void _handleQrSelected(String code) {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return;

    final existing = widget.repository.findElementByCode(clean);
    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A(z) "$clean" kód már regisztrálva van!'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    setState(() {
      _scannedQr = clean;
      _isCameraScanning = false;
      _detectedCategory = clean.startsWith('A_')
          ? 'accessory_type'
          : clean.startsWith('C_')
          ? 'site'
          : 'box_type';
      _currentStep = 1;
    });
  }

  void _handleNfcSelected(String nfcId) {
    setState(() {
      _scannedNfc = nfcId.trim();
      _currentStep = 2;
    });
  }

  void _handleTypeSelected(CatalogItem item, {bool closeAfterSave = false}) {
    final newBox = BoxElement(
      name: item.label,
      code: _scannedQr,
      secondaryCode: _scannedNfc.isEmpty ? null : _scannedNfc,
      type: item.code,
      size: item.defaultSize ?? 'dadant',
      status: 'green',
    );

    if (widget.repository.hives.isNotEmpty) {
      widget.repository.addBoxToHive(widget.repository.hives.first, newBox);
    }
    widget.repository.syncWithSupabase();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Mentve: $_scannedQr ${_scannedNfc.isNotEmpty ? "(NFC: $_scannedNfc)" : ""} -> ${item.label}',
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );

    if (closeAfterSave) {
      Navigator.pop(context);
    } else {
      setState(() {
        _sessionRegisteredItems.insert(0, newBox);
        _scannedQr = '';
        _scannedNfc = '';
        _manualQrCtrl.clear();
        _manualNfcCtrl.clear();
        _currentStep = 0;
      });
    }
  }

  Widget _buildStepBadge(int stepIndex, String title, IconData icon) {
    final bool isActive = _currentStep == stepIndex;
    final bool isDone = _currentStep > stepIndex;
    final Color color = isActive
        ? Colors.amberAccent
        : isDone
        ? Colors.tealAccent
        : Colors.white38;

    return Expanded(
      child: InkWell(
        onTap: isDone ? () => setState(() => _currentStep = stepIndex) : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1E293B) : const Color(0xFF141428),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? Colors.amberAccent : Colors.white12,
              width: isActive ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(isDone ? Icons.check_circle : icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String nextB = _formatCode('B', _getNextAvailableSerial('B'));
    final String nextA = _formatCode('A', _getNextAvailableSerial('A'));
    final List<CatalogItem> dynamicOptions = widget.catalogs
        .where((c) => c.category == _detectedCategory)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141428),
        foregroundColor: Colors.tealAccent,
        title: const Text(
          'Új Objektum Regisztrációja',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_currentStep > 0)
            TextButton.icon(
              onPressed: () => setState(() => _currentStep--),
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.amberAccent,
                size: 18,
              ),
              label: const Text(
                'Előző lépés',
                style: TextStyle(color: Colors.amberAccent, fontSize: 12),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                _buildStepBadge(0, '1. QR-kód', Icons.qr_code_scanner),
                const SizedBox(width: 8),
                _buildStepBadge(1, '2. NFC-címke', Icons.nfc),
                const SizedBox(width: 8),
                _buildStepBadge(2, '3. Típus', Icons.category),
              ],
            ),
            const SizedBox(height: 18),

            if (_currentStep == 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141428),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amberAccent.withAlpha(100)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '1. Lépés: Olvasd be vagy válaszd ki a QR-kódot',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'A kód előtagja (B_, A_ vagy C_) automatikusan meghatározza a típust.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 16),

                    if (_isCameraScanning) ...[
                      SizedBox(
                        height: 260,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: MobileScanner(
                            onDetect: (capture) {
                              final List<Barcode> barcodes = capture.barcodes;
                              if (barcodes.isNotEmpty &&
                                  barcodes.first.rawValue != null) {
                                _handleQrSelected(barcodes.first.rawValue!);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () =>
                            setState(() => _isCameraScanning = false),
                        icon: const Icon(Icons.close),
                        label: const Text('Kamera bezárása'),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () =>
                            setState(() => _isCameraScanning = true),
                        icon: const Icon(Icons.camera_alt, size: 22),
                        label: const Text(
                          'QR-kód Beolvasása Kamerával',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.tealAccent,
                                side: const BorderSide(
                                  color: Colors.tealAccent,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onPressed: () => _handleQrSelected(nextB),
                              icon: const Icon(Icons.inventory_2, size: 18),
                              label: Text(
                                'Új Fiók\n$nextB',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.lightBlueAccent,
                                side: const BorderSide(
                                  color: Colors.lightBlueAccent,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onPressed: () => _handleQrSelected(nextA),
                              icon: const Icon(Icons.extension, size: 18),
                              label: Text(
                                'Új Kellék\n$nextA',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _manualQrCtrl,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          labelText: 'Vagy írd be kézzel a QR-kódot',
                          labelStyle: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.arrow_forward,
                              color: Colors.amberAccent,
                            ),
                            onPressed: () =>
                                _handleQrSelected(_manualQrCtrl.text),
                          ),
                        ),
                        onSubmitted: _handleQrSelected,
                      ),
                    ],
                  ],
                ),
              )
            else if (_currentStep == 1)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141428),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.lightBlueAccent.withAlpha(100),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '2. Lépés: NFC-címke párosítása',
                          style: TextStyle(
                            color: Colors.lightBlueAccent,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'QR: $_scannedQr',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlueAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        final mockNfc =
                            'NFC_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                        _handleNfcSelected(mockNfc);
                      },
                      icon: const Icon(Icons.sensors),
                      label: const Text(
                        'NFC Beolvasás Indítása',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amberAccent,
                        side: const BorderSide(color: Colors.amberAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _handleNfcSelected(''),
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Nincs NFC-címke (Tovább)'),
                    ),
                  ],
                ),
              )
            else if (_currentStep == 2)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141428),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.tealAccent.withAlpha(100)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '3. Lépés: Típus kiválasztása',
                      style: TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...dynamicOptions.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            side: BorderSide(color: item.color.withAlpha(140)),
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _handleTypeSelected(item),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(item.icon, color: item.color, size: 22),
                                  const SizedBox(width: 12),
                                  Text(
                                    item.label,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Icon(
                                Icons.add_task,
                                color: Colors.tealAccent,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
