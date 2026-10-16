import 'package:flutter/material.dart';

import '../hive_model.dart';

class HiveDetailSheet extends StatelessWidget {
  final HiveData hive;
  final Animation<double> redFlashOpacityAnim;
  final VoidCallback? onConfigurePressed;

  const HiveDetailSheet({
    super.key,
    required this.hive,
    required this.redFlashOpacityAnim,
    this.onConfigurePressed,
  });

  String _getFunctionName(String func) {
    switch (func) {
      case 'gyujto_mez':
        return 'Gyűjtő - Méz';
      case 'gyujto_propolisz':
        return 'Gyűjtő - Propolisz';
      case 'gyujto_viragpor':
        return 'Gyűjtő - Virágpor';
      case 'gyujto_mehmereg':
        return 'Gyűjtő - Méhméreg';
      case 'szaporitas_donor':
        return 'Szaporítás - Donor';
      case 'szaporitas_starter':
        return 'Szaporítás - Starter';
      case 'szaporitas_anya':
        return 'Szaporítás - Anya család';
      case 'szaporitas_apa':
        return 'Szaporítás - Apa (hernevelő)';
      case 'kiselejtezendo':
        return 'Kiselejtezendő';
      case 'hans':
        return '🔥 HANS PROTOKOLL (Karantén)';
      default:
        return func;
    }
  }

  String _getSizeLabel(String size) {
    switch (size) {
      case 'dadant':
        return 'Dadant';
      case 'fel_dadant':
        return '1/2 Dadant';
      case 'nb':
        return 'NB';
      case 'hunor':
        return 'Hunor';
      case 'fel_nb':
        return '1/2 NB';
      default:
        return '';
    }
  }

  Color _getQueenColor(String? vintage) {
    if (vintage == null) return Colors.grey;
    final lower = vintage.toLowerCase();
    if (lower.contains('fehér') ||
        lower.contains('2021') ||
        lower.contains('2026'))
      return Colors.white;
    if (lower.contains('sárga') ||
        lower.contains('2022') ||
        lower.contains('2027'))
      return Colors.yellowAccent;
    if (lower.contains('piros') ||
        lower.contains('2023') ||
        lower.contains('2028'))
      return Colors.redAccent;
    if (lower.contains('zöld') ||
        lower.contains('2024') ||
        lower.contains('2029'))
      return Colors.greenAccent;
    if (lower.contains('kék') ||
        lower.contains('2025') ||
        lower.contains('2030'))
      return Colors.lightBlueAccent;
    return Colors.amber;
  }

  Color _statusToIconColor(String status) {
    switch (status) {
      case 'green':
        return Colors.greenAccent;
      case 'yellow':
        return Colors.yellowAccent;
      case 'red':
      case 'flashing_red':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  Color _statusToBoxFillColor(String status) {
    switch (status) {
      case 'green':
        return Colors.green.shade700;
      case 'yellow':
        return Colors.amber.shade700;
      case 'red':
      case 'flashing_red':
        return Colors.red.shade800;
      default:
        return Colors.green.shade700;
    }
  }

  Color _statusToBoxBorderColor(String status) {
    switch (status) {
      case 'green':
        return Colors.greenAccent;
      case 'yellow':
        return Colors.yellowAccent;
      case 'red':
      case 'flashing_red':
        return Colors.redAccent;
      default:
        return Colors.greenAccent;
    }
  }

  Widget _buildStatusIcon({
    required IconData icon,
    required String status,
    required String tooltip,
    double size = 22,
  }) {
    final color = _statusToIconColor(status);
    Widget iconWidget = Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(140),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(180), width: 1.5),
      ),
      child: Icon(icon, color: color, size: size),
    );

    if (status == 'flashing_red') {
      iconWidget = FadeTransition(
        opacity: redFlashOpacityAnim,
        child: iconWidget,
      );
    }

    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.tap,
      child: iconWidget,
    );
  }

  // --- 1. RÉSZLETEK DIÁLÓGUS ---
  void _showDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(
            '📊 Részletek & Szenzorok (${hive.id})',
            style: const TextStyle(color: Colors.amberAccent, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fészek & Kaptármonitor adatok:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                _buildSensorDetailRow(
                  'Belső Hőmérséklet',
                  '${hive.temp} °C',
                  hive.tempStatus,
                  'Ideális: 32 - 36 °C',
                ),
                _buildSensorDetailRow(
                  'Fészek Páratartalom',
                  '${hive.humidity} %',
                  'green',
                  'Normál klíma',
                ),
                _buildSensorDetailRow(
                  'Kaptár Súlya',
                  '${hive.weight} kg',
                  hive.weightStatus,
                  'Min: 30 kg',
                ),
                _buildSensorDetailRow(
                  'Akusztika (ZCR)',
                  '${hive.zcr.toInt()} Hz',
                  hive.micStatus,
                  'Zajszint OK',
                ),
                _buildSensorDetailRow(
                  'Akkumulátor Feszültség',
                  '${hive.batteryVoltage} V',
                  hive.batteryStatus,
                  'Feszültség rendben',
                ),
                const Divider(color: Colors.grey, height: 24),
                const Text(
                  '📡 Szerver & Hálózat:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                _buildSensorDetailRow(
                  'Kapcsolat állapota',
                  hive.serverConnection,
                  hive.signalStatus,
                  'Szerver / ESP-NOW',
                ),
                _buildSensorDetailRow(
                  'Külső Hőmérséklet',
                  '${hive.extTemp} °C (${hive.extHumidity}%)',
                  hive.extTempStatus,
                  'Időjárás-állomás',
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Bezárás'),
            ),
          ],
        );
      },
    );
  }

  // --- 3. KEZELÉS DIÁLÓGUS ---
  void _showManagementDialog(BuildContext context) {
    String selectedAction = 'Atkairtás';
    double amount = 1.0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Text(
                '💉 Kezelés & Beavatkozás\n(${hive.id})',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Művelet típusa:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButton<String>(
                    value: selectedAction,
                    dropdownColor: const Color(0xFF2C2C2C),
                    style: const TextStyle(color: Colors.white),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'Atkairtás',
                        child: Text('🛡️ Atkairtás (kezelés)'),
                      ),
                      DropdownMenuItem(
                        value: 'Etetés',
                        child: Text('🍯 Etetés (szirup / lepény)'),
                      ),
                      DropdownMenuItem(
                        value: 'Gyógyszerezés',
                        child: Text('💊 Gyógyszerezés'),
                      ),
                      DropdownMenuItem(
                        value: 'Lángszórózás',
                        child: Text('🔥 Lángszórózás (fertőtlenítés)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null)
                        setDialogState(() => selectedAction = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Mennyiség / Dózis: ${amount.toStringAsFixed(1)} liter / egység',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Slider(
                    value: amount,
                    min: 0.5,
                    max: 10.0,
                    divisions: 19,
                    activeColor: Colors.amber,
                    onChanged: (val) => setDialogState(() => amount = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Mégse',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Rögzítve: $selectedAction (${amount.toStringAsFixed(1)} egység)',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text('Rögzítés'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- 4. OSZTÁLYOZÁS DIÁLÓGUS ---
  void _showClassificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Text(
                '⭐ Család Osztályzása\n(${hive.id})',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScoreRow(
                      '🍯 Hordási kedv (Gyűjtés)',
                      hive.evaluation.gathering,
                      (val) =>
                          setDialogState(() => hive.evaluation.gathering = val),
                    ),
                    _buildScoreRow(
                      '🐝 Vérmérséklet (Nyugalom)',
                      hive.evaluation.temperament,
                      (val) => setDialogState(
                        () => hive.evaluation.temperament = val,
                      ),
                    ),
                    _buildScoreRow(
                      '🛡️ Higiénia & Ellenállás',
                      hive.evaluation.hygiene,
                      (val) =>
                          setDialogState(() => hive.evaluation.hygiene = val),
                    ),
                    _buildScoreRow(
                      '🍞 Takarmányigény ("Zabagép")',
                      hive.evaluation.consumption,
                      (val) => setDialogState(
                        () => hive.evaluation.consumption = val,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Mégse',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Osztályozás sikeresen mentve!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text('Mentés'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNestActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.60,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Text(
                    'Fészek műveletek (${hive.id})',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: _buildHugeMenuButton(
                      context,
                      icon: Icons.analytics,
                      title: 'Részletek & Szenzorok',
                      subtitle: 'Belső klíma, súly, akusztika és térerő',
                      color: Colors.lightBlueAccent,
                      onTap: () {
                        Navigator.pop(context);
                        _showDetailsDialog(context);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    child: _buildHugeMenuButton(
                      context,
                      icon: Icons.tune,
                      title: 'Konfiguráció & Torony',
                      subtitle: 'Fiókok hozzáadása, elvétele, anyacsere',
                      color: Colors.amber,
                      onTap: () {
                        Navigator.pop(context);
                        if (onConfigurePressed != null) onConfigurePressed!();
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    child: _buildHugeMenuButton(
                      context,
                      icon: Icons.medical_services,
                      title: 'Kezelés & Beavatkozás',
                      subtitle:
                          'Atkairtás, etetés, gyógyszerezés, lángszórózás',
                      color: Colors.greenAccent,
                      onTap: () {
                        Navigator.pop(context);
                        _showManagementDialog(context);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    child: _buildHugeMenuButton(
                      context,
                      icon: Icons.star,
                      title: 'Család Osztályzása',
                      subtitle:
                          'Hordás, vérmérséklet, higiénia pontozása (-- / ++)',
                      color: Colors.orangeAccent,
                      onTap: () {
                        Navigator.pop(context);
                        _showClassificationDialog(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHugeMenuButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withAlpha(180), width: 2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: color, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSensorDetailRow(
    String label,
    String value,
    String status,
    String hint,
  ) {
    final color = _statusToIconColor(status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  hint,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(
    String title,
    String currentValue,
    Function(String) onChanged,
  ) {
    const options = ['--', '-', '+', '++'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: options.map((opt) {
              bool isSelected = (currentValue == opt);
              return ChoiceChip(
                label: Text(
                  opt,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                selected: isSelected,
                selectedColor: Colors.amber,
                backgroundColor: const Color(0xFF2C2C2C),
                onSelected: (selected) {
                  if (selected) onChanged(opt);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBoxWidget(
    BoxElement box,
    BuildContext context, {
    double? flexFactor,
  }) {
    double aspectRatio;
    Color boxColor;
    Color borderColor;

    bool isHansQuarantine =
        (hive.status == 'flashing_red' || hive.protocol == 'hans');
    String effectiveStatus = box.status;

    if (box.type == 'nest') {
      aspectRatio = 1.2; // Kicsit rugalmasabb arány
      effectiveStatus = hive.nestCalculatedStatus;
      boxColor = isHansQuarantine
          ? Colors.red.shade900
          : _statusToBoxFillColor(effectiveStatus);
      borderColor = isHansQuarantine
          ? Colors.redAccent
          : _statusToBoxBorderColor(effectiveStatus);
    } else if (box.type == 'honey') {
      aspectRatio = 2.2;
      boxColor = isHansQuarantine
          ? Colors.red.shade800
          : _statusToBoxFillColor(effectiveStatus);
      borderColor = isHansQuarantine
          ? Colors.redAccent
          : _statusToBoxBorderColor(effectiveStatus);
    } else {
      aspectRatio = 4.0;
      if (isHansQuarantine) {
        boxColor = Colors.red.shade900;
        borderColor = Colors.redAccent;
      } else {
        switch (box.type) {
          case 'feeder':
            boxColor = Colors.blue.shade700;
            borderColor = Colors.lightBlueAccent;
            break;
          case 'escapement':
            boxColor = Colors.purple.shade700;
            borderColor = Colors.purpleAccent;
            break;
          case 'vent':
            boxColor = Colors.teal.shade700;
            borderColor = Colors.tealAccent;
            break;
          case 'pollen_trap':
            boxColor = Colors.orange.shade800;
            borderColor = Colors.orangeAccent;
            break;
          case 'roof':
            boxColor = Colors.blueGrey.shade800;
            borderColor = Colors.blueGrey.shade300;
            break;
          default:
            boxColor = Colors.grey.shade700;
            borderColor = Colors.grey.shade400;
        }
      }
    }

    Widget boxContainer = Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: InkWell(
          onTap: box.type == 'nest' ? () => _showNestActionMenu(context) : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: boxColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: borderColor,
                width: (isHansQuarantine || effectiveStatus == 'flashing_red')
                    ? 2.5
                    : 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: box.type == 'nest'
                ? _buildNestContent(box)
                : _buildUpperBoxContent(box),
          ),
        ),
      ),
    );

    if (isHansQuarantine || effectiveStatus == 'flashing_red') {
      return FadeTransition(opacity: redFlashOpacityAnim, child: boxContainer);
    }

    return boxContainer;
  }

  Widget _buildNestContent(BoxElement box) {
    final queenColor = _getQueenColor(hive.queen?.vintage);
    final sizeText = _getSizeLabel(box.size);
    final bool needsReplacement = hive.queen?.needsReplacement ?? false;
    final bool isHans =
        (hive.protocol == 'hans' || hive.status == 'flashing_red');

    Widget queenWidget = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: queenColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black87, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
      ),
      child: Center(
        child: Text(
          hive.queen != null ? hive.queen!.vintage.substring(0, 4) : '?',
          style: TextStyle(
            color:
                queenColor == Colors.white ||
                    queenColor == Colors.yellowAccent ||
                    queenColor == Colors.greenAccent
                ? Colors.black
                : Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );

    if (hive.queen != null && needsReplacement) {
      queenWidget = FadeTransition(
        opacity: redFlashOpacityAnim,
        child: queenWidget,
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Fészek ($sizeText)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.touch_app, color: Colors.white38, size: 12),
              ],
            ),
            if (isHans)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.redAccent, width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.local_fire_department,
                      color: Colors.orangeAccent,
                      size: 14,
                    ),
                    SizedBox(width: 2),
                    Text(
                      'HANS',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              )
            else if (hive.protocol != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  hive.protocol == 'hans' ? '🔥 HANS' : '🐱 DON\'T TOUCH',
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Text(
                box.code,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            queenWidget,
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getFunctionName(hive.familyFunction),
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'H:${hive.evaluation.gathering} | V:${hive.evaluation.temperament} | H:${hive.evaluation.hygiene}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatusIcon(
              icon: Icons.scale,
              status: hive.weightStatus,
              tooltip: 'Súly: ${hive.weight} kg',
              size: 18,
            ),
            _buildStatusIcon(
              icon: Icons.mic,
              status: hive.micStatus,
              tooltip: 'Akusztika: ${hive.zcr.toInt()} Hz',
              size: 18,
            ),
            _buildStatusIcon(
              icon: Icons.thermostat,
              status: hive.tempStatus,
              tooltip: 'Fészek: ${hive.temp} °C',
              size: 18,
            ),
            _buildStatusIcon(
              icon: Icons.signal_cellular_alt,
              status: hive.signalStatus,
              tooltip: hive.serverConnection,
              size: 18,
            ),
            _buildStatusIcon(
              icon: Icons.battery_full,
              status: hive.batteryStatus,
              tooltip: 'Akku: ${hive.batteryVoltage} V',
              size: 18,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpperBoxContent(BoxElement box) {
    final sizeLabel = box.type == 'honey'
        ? ' (${_getSizeLabel(box.size)})'
        : '';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${box.name}$sizeLabel',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        Text(
          box.code,
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomBoxes = hive.boxes
        .where((b) => b.type == 'pollen_trap')
        .toList();
    final upperAndNestBoxes = hive.boxes
        .where((b) => b.type != 'pollen_trap')
        .toList();
    final renderedBoxes = [...upperAndNestBoxes.reversed, ...bottomBoxes];

    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: true,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161616),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Intelligens adaptív nézet: ha kevesebb fiók van, kitölti a képernyőt görgetés nélkül; ha sok, scrollozható.
                return SingleChildScrollView(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 48,
                                height: 5,
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white30,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          hive.name,
                                          style: const TextStyle(
                                            color: Colors.amberAccent,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          _getFunctionName(hive.familyFunction),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (onConfigurePressed != null)
                                    IconButton(
                                      onPressed: onConfigurePressed,
                                      icon: const Icon(
                                        Icons.tune,
                                        color: Colors.amberAccent,
                                      ),
                                      tooltip: 'Konfiguráció',
                                    ),
                                ],
                              ),
                              const Divider(color: Colors.white24, height: 16),
                            ],
                          ),

                          // A torony, ami pontosan a rendelkezésre álló térhez igazodik
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...renderedBoxes.map(
                                  (box) => _buildBoxWidget(box, context),
                                ),
                              ],
                            ),
                          ),

                          // Külső hőmérséklet kártya alul
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF222222),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildStatusIcon(
                                      icon: Icons.thermostat,
                                      status: hive.extTempStatus,
                                      tooltip:
                                          'Külső: ${hive.extTemp} °C / ${hive.extHumidity}%',
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Külső: ${hive.extTemp} °C  (${hive.extHumidity}%)',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
