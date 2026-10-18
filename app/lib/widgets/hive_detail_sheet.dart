import 'package:flutter/material.dart';

import '../hive_model.dart';
import '../services/hive_repository.dart';
import '../screens/brood_box_control_screen.dart';

class HiveDetailSheet extends StatefulWidget {
  final HiveData hive;
  final Animation<double> redFlashOpacityAnim;
  final VoidCallback onConfigurePressed;

  const HiveDetailSheet({
    super.key,
    required this.hive,
    required this.redFlashOpacityAnim,
    required this.onConfigurePressed,
  });

  @override
  State<HiveDetailSheet> createState() => _HiveDetailSheetState();
}

class _HiveDetailSheetState extends State<HiveDetailSheet> {
  // Segédfüggvény az aljdeszka hátralévő napjainak kiszámításához
  String _getBottomBoardStatusText(BoxElement box) {
    if (!box.isActive) {
      return 'Aljdeszka kihúzva';
    }
    if (box.statusUpdatedAt == null) {
      return 'Aljdeszka betolva (3 napos kontroll)';
    }

    final difference = DateTime.now().difference(box.statusUpdatedAt!);
    final elapsedDays = difference.inDays;
    final remainingDays = 3 - elapsedDays;

    if (remainingDays >= 3) {
      return 'Ellenőrzés: 3 nap múlva';
    } else if (remainingDays == 2) {
      return 'Ellenőrzés: 2 nap múlva';
    } else if (remainingDays == 1) {
      return 'Ellenőrzés: Holnap (1 nap)';
    } else {
      return 'Ellenőrzés: MA esedékes!';
    }
  }

  // Segédfüggvény: ha az adatbázisból "Elem" névvel jön a fiók, típus alapján elnevezzük
  String _getBoxDisplayName(BoxElement box) {
    final lowerName = box.name.trim().toLowerCase();
    final lowerType = box.type.trim().toLowerCase();

    if (lowerType == 'broodbox' ||
        lowerType == 'brood_box' ||
        lowerType == '8' ||
        lowerName.contains('fészek') ||
        (lowerName == 'elem' && box.size.toLowerCase() == 'dadant')) {
      return 'Fészek';
    }
    if (lowerType == 'honey' ||
        lowerType == '9' ||
        lowerName.contains('méztér') ||
        lowerName.contains('meztér')) {
      return 'Méztér';
    }
    if (lowerType == 'feeder' ||
        lowerType == '10' ||
        lowerName.contains('etető')) {
      return 'Etető';
    }
    if (lowerType == 'escapement' || lowerType == '13') return 'Szöktető';
    if (lowerType == 'vent' || lowerType == '12') return 'Szellőző';
    if (lowerType == 'pollen_trap' || lowerType == '11') return 'Pollengyűjtő';
    if (lowerType == 'bottom' || lowerType == '15') return 'Aljdeszka';
    if (lowerType == 'roof') return 'Tető';

    if (lowerName == 'elem' || lowerName.isEmpty) {
      return 'Fészek';
    }
    return box.name;
  }

  // Segédfüggvény a pontos méret kiírásához (Dadant / 1/2 Dadant)
  String _getBoxDisplaySize(BoxElement box, String displayName) {
    if (displayName == 'Fészek') {
      return 'DADANT';
    }
    if (displayName == 'Méztér') {
      return '1/2 DADANT';
    }
    return box.size.toUpperCase();
  }

  // Segédfüggvény a QR és NFC azonosítók tiszta megjelenítéséhez
  String _getBoxCodesText(BoxElement box) {
    if (box.secondaryCode != null && box.secondaryCode!.trim().isNotEmpty) {
      return 'QR: ${box.code} | NFC: ${box.secondaryCode}';
    }
    return 'QR: ${box.code}';
  }

  @override
  Widget build(BuildContext context) {
    final HiveRepository repository = HiveRepository.instance;
    final displayedBoxes = widget.hive.boxes.reversed.toList();

    // Megkeressük a legalsó fészekfiókot
    BoxElement? bottomBroodBox;
    for (var b in widget.hive.boxes) {
      if (_getBoxDisplayName(b) == 'Fészek') {
        bottomBroodBox = b;
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.hive.name,
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Család ID: ${widget.hive.id} | Kapott szirup: ${widget.hive.syrupLiters.toStringAsFixed(1)} L',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      if (widget.hive.serverConnection.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Kaptármonitor: ${widget.hive.serverConnection}',
                          style: const TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.tune, color: Colors.amberAccent),
                  tooltip: 'Torony Konfiguráció',
                  onPressed: widget.onConfigurePressed,
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 24),

            if (widget.hive.queen != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Méhanya: ${widget.hive.queen!.vintage}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Származás: ${widget.hive.queen!.origin} (${widget.hive.queen!.id})',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            const Text(
              'Torony felépítése (Kattints bármelyik fiókra a vezérléshez):',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            ...displayedBoxes.map((box) {
              final displayName = _getBoxDisplayName(box);
              final displaySize = _getBoxDisplaySize(box, displayName);

              if (box.type == 'bottom' || displayName == 'Aljdeszka') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: box.isActive
                            ? Colors.deepOrange
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Aljdeszka',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _getBottomBoardStatusText(box),
                              style: TextStyle(
                                color:
                                    box.isActive &&
                                        box.statusUpdatedAt != null &&
                                        DateTime.now()
                                                .difference(
                                                  box.statusUpdatedAt!,
                                                )
                                                .inDays >=
                                            3
                                    ? Colors.amberAccent
                                    : Colors.white60,
                                fontSize: 11,
                                fontWeight:
                                    box.isActive &&
                                        box.statusUpdatedAt != null &&
                                        DateTime.now()
                                                .difference(
                                                  box.statusUpdatedAt!,
                                                )
                                                .inDays >=
                                            3
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: box.isActive,
                          activeThumbColor: Colors.deepOrange,
                          onChanged: (val) {
                            setState(() {
                              repository.toggleBoxActiveState(
                                widget.hive,
                                box,
                                val,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              } else if (box.type == 'pollen_trap' ||
                  displayName == 'Pollengyűjtő') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: box.isActive ? Colors.orange : Colors.white12,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pollengyűjtő',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _getBoxCodesText(box),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const Text(
                              'Virágporgyűjtés aktív / inaktív',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: box.isActive,
                          activeThumbColor: Colors.orange,
                          onChanged: (val) {
                            setState(() {
                              repository.toggleBoxActiveState(
                                widget.hive,
                                box,
                                val,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                final bool isBottomBroodBox =
                    (bottomBroodBox != null && box.code == bottomBroodBox.code);
                final bool isFeeder = (displayName == 'Etető');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => BroodBoxControlScreen(
                            hive: widget.hive,
                            broodBox: box,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amberAccent.withAlpha(140),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isFeeder ? Icons.water_drop : Icons.hive,
                                color: isFeeder
                                    ? Colors.lightBlueAccent
                                    : Colors.amberAccent,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$displayName ($displaySize)',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _getBoxCodesText(box),
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.open_in_full,
                                color: Colors.amberAccent,
                                size: 18,
                              ),
                            ],
                          ),

                          if (isBottomBroodBox) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(color: Colors.white24, height: 1),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSensorBadge(
                                  Icons.thermostat,
                                  '${widget.hive.temp.toStringAsFixed(1)} °C',
                                  Colors.amber,
                                ),
                                _buildSensorBadge(
                                  Icons.water_drop,
                                  '${widget.hive.humidity.toStringAsFixed(0)} %',
                                  Colors.lightBlueAccent,
                                ),
                                _buildSensorBadge(
                                  Icons.mic,
                                  '${widget.hive.zcr.toStringAsFixed(0)} Hz',
                                  Colors.purpleAccent,
                                ),
                                _buildSensorBadge(
                                  Icons.battery_full,
                                  '${widget.hive.batteryVoltage.toStringAsFixed(2)} V',
                                  Colors.tealAccent,
                                ),
                                _buildSensorBadge(
                                  Icons.scale,
                                  '${widget.hive.weight.toStringAsFixed(1)} kg',
                                  Colors.greenAccent,
                                ),
                              ],
                            ),
                          ] else if (isFeeder) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(color: Colors.white24, height: 1),
                            ),
                            Row(
                              children: [
                                _buildSensorBadge(
                                  Icons.waves,
                                  'Szirupszint / Kapott szirup: ${widget.hive.syrupLiters.toStringAsFixed(1)} L',
                                  Colors.lightBlueAccent,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }
            }),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wb_sunny, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Időjárás-állomás: ${widget.hive.extTemp} °C (${widget.hive.extHumidity}%)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorBadge(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
