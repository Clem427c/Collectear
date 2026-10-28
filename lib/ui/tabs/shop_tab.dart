import 'package:flutter/material.dart';

import '../../app_data.dart';
import '../../core/collection.dart';
import '../../core/economy.dart';
import '../theme.dart';
import '../widgets.dart';

/// Article de boutique (prototype : aucun achat réel).
class _Item {
  const _Item(this.name, this.price, this.gems, this.colors, {this.icon, this.tag});
  final String name;
  final String price; // prix affiché
  final bool gems; // payé en gemmes (sinon en euros)
  final List<Color> colors; // aperçu
  final IconData? icon;
  final String? tag;
}

const _skins = [
  _Item('Éclaireur azur', '120', true, [Color(0xFF4DD6FF), Color(0xFF1E6BFF)], tag: 'Nouveau'),
  _Item('Braise', '120', true, [Color(0xFFFFB627), Color(0xFFFF4E2A)]),
  _Item('Sylve', '120', true, [Color(0xFF7BE07B), Color(0xFF1E8A4C)]),
  _Item('Nuit étoilée', '250', true, [Color(0xFF6B5BFF), Color(0xFF16104A)], tag: 'Rare'),
  _Item('Corail', '120', true, [Color(0xFFFF8FA3), Color(0xFFE84A5F)]),
  _Item('Or royal', '500', true, [Color(0xFFFFF1A8), Color(0xFFE0A100)], tag: 'Épique'),
];

const _frames = [
  _Item('Cadre givré', '80', true, [Color(0xFFE6F7FF), Color(0xFF7FD3FF)], icon: Icons.ac_unit),
  _Item('Cadre de lave', '80', true, [Color(0xFFFFC46B), Color(0xFFD6331F)], icon: Icons.local_fire_department),
  _Item('Cadre holographique', '200', true, [Color(0xFFFF8FF5), Color(0xFF6BE3FF)], icon: Icons.auto_awesome, tag: 'Rare'),
];

const _gems = [
  _Item('Poignée de gemmes', '1,99 €', false, [Color(0xFF4DD6FF), Color(0xFF1E6BFF)], icon: Icons.diamond),
  _Item('Sac de gemmes', '4,99 €', false, [Color(0xFF4DD6FF), Color(0xFF6B5BFF)], icon: Icons.diamond, tag: '+10 %'),
  _Item('Coffre de gemmes', '9,99 €', false, [Color(0xFF7FE9FF), Color(0xFF7B5CFF)], icon: Icons.diamond, tag: '+25 %'),
];

/// Onglet Boutique : cosmétiques uniquement (pas de pay-to-win).
class ShopTab extends StatelessWidget {
  const ShopTab({super.key, required this.data, required this.onChanged});
  final AppData data;
  final VoidCallback onChanged;

  Future<void> _buyEnergy(BuildContext context) async {
    final col = data.collection;
    final price = col.nextEnergyPrice;
    final String msg;
    if (price == null) {
      msg = 'Limite atteinte : ${Economy.maxEnergyPurchasesPerDay} énergies achetées aujourd\'hui. Reviens demain !';
    } else if (!col.energyMissing) {
      msg = 'Tes énergies sont au maximum (${Collection.maxEnergy}) : joue une run d\'abord !';
    } else if (col.coins < price) {
      msg = 'Pas assez de pièces : il t\'en faut $price (tu en as ${col.coins}).';
    } else {
      await col.buyEnergy();
      msg = 'Énergie achetée : +1 run aujourd\'hui !';
      onChanged();
    }
    if (context.mounted) showPrototypeSnack(context, msg);
  }

  void _buy(BuildContext context, String what) =>
      showPrototypeSnack(context, 'Prototype : les achats arriveront avec l\'étape Monétisation ($what).');

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        const SectionTitle('Énergies'),
        _WideOffer(
          icon: Icons.bolt,
          title: 'Énergie : +1 run aujourd\'hui',
          subtitle: 'Avec les pièces ramassées en run. '
              '${data.collection.energyBoughtToday} / ${Economy.maxEnergyPurchasesPerDay} achetées aujourd\'hui'
              ' · ${data.collection.runsLeftToday} / ${Collection.maxEnergy} énergies'
              '${data.collection.energyMissing ? '' : ' (maximum atteint)'}.',
          price: data.collection.nextEnergyPrice == null ? 'Demain' : '${data.collection.nextEnergyPrice} pièces',
          onBuy: () => _buyEnergy(context),
        ),
        const SizedBox(height: 4),
        _DailyOffer(onBuy: () => _buy(context, 'Pack Explorateur')),
        SectionTitle('Skins d\'explorateur', trailing: _Timer(text: 'Renouvelé dans 7 h')),
        _Grid(items: _skins, preview: (i) => _SkinPreview(item: i), onBuy: (i) => _buy(context, i.name)),
        const SectionTitle('Cadres de cartes'),
        _Grid(items: _frames, preview: (i) => _FramePreview(item: i), onBuy: (i) => _buy(context, i.name)),
        const SectionTitle('Confort'),
        _WideOffer(
          icon: Icons.block,
          title: 'Sans publicité',
          subtitle: 'Plus aucune pub interstitielle. Les pubs bonus restent au choix.',
          price: '3,99 €',
          onBuy: () => _buy(context, 'Sans publicité'),
        ),
        const SizedBox(height: 10),
        _WideOffer(
          icon: Icons.ondemand_video,
          title: 'Run bonus',
          subtitle: 'Regarde une vidéo pour une run de plus aujourd\'hui.',
          price: 'Gratuit',
          onBuy: () => _buy(context, 'Run bonus'),
        ),
        const SectionTitle('Gemmes'),
        _Grid(items: _gems, preview: (i) => _GemPreview(item: i), onBuy: (i) => _buy(context, i.name)),
        const SizedBox(height: 12),
        const Text(
          'Uniquement des cosmétiques : aucun achat ne donne d\'avantage en jeu.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }
}

class _Timer extends StatelessWidget {
  const _Timer({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.schedule, size: 14, color: Colors.white54),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    ]);
  }
}

class _DailyOffer extends StatelessWidget {
  const _DailyOffer({required this.onBuy});
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFF7B5CFF)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(children: [
        const _SkinPreview(
          item: _Item('Pack', '', true, [Color(0xFFFFF1A8), Color(0xFFE0A100)]),
          size: 80,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(8)),
              child: const Text('OFFRE DU JOUR',
                  style: TextStyle(color: AppColors.ink, fontSize: 11, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 6),
            const Text('Pack Explorateur',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const Text('Skin Or royal + cadre holographique + 300 gemmes',
                style: TextStyle(color: Colors.white, fontSize: 12)),
            const SizedBox(height: 10),
            ChunkyButton(label: '4,99 €', fontSize: 16, onPressed: onBuy, color: const Color(0xFF6BE36B)),
          ]),
        ),
      ]),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items, required this.preview, required this.onBuy});
  final List<_Item> items;
  final Widget Function(_Item) preview;
  final void Function(_Item) onBuy;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        childAspectRatio: 0.78,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _ShopCell(item: items[i], preview: preview(items[i]), onTap: () => onBuy(items[i])),
    );
  }
}

class _ShopCell extends StatelessWidget {
  const _ShopCell({required this.item, required this.preview, required this.onTap});
  final _Item item;
  final Widget preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF3A2D86),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: Stack(children: [
          Column(children: [
            Expanded(child: Center(child: preview)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: item.gems ? const Color(0xFF1E6BFF) : const Color(0xFF3FBF5A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black26, width: 1.5),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (item.gems) const Icon(Icons.diamond, size: 14, color: Color(0xFFBFF3FF)),
                if (item.gems) const SizedBox(width: 4),
                Text(item.price, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ]),
            ),
          ]),
          if (item.tag != null)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.coral, borderRadius: BorderRadius.circular(6)),
                child: Text(item.tag!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Aperçu d'un skin : le personnage (un rond pour l'instant) aux couleurs du skin.
class _SkinPreview extends StatelessWidget {
  const _SkinPreview({required this.item, this.size = 58});
  final _Item item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: item.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: AppColors.ink, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Align(
        alignment: const Alignment(0.45, -0.1),
        child: Container(
          width: size * 0.2,
          height: size * 0.2,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _FramePreview extends StatelessWidget {
  const _FramePreview({required this.item});
  final _Item item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 62,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: item.colors),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: BoxDecoration(color: AppColors.night, borderRadius: BorderRadius.circular(5)),
        child: Icon(item.icon, color: item.colors.last, size: 22),
      ),
    );
  }
}

class _GemPreview extends StatelessWidget {
  const _GemPreview({required this.item});
  final _Item item;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => LinearGradient(colors: item.colors).createShader(r),
      child: const Icon(Icons.diamond, size: 52, color: Colors.white),
    );
  }
}

class _WideOffer extends StatelessWidget {
  const _WideOffer({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.onBuy,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String price;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2D86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: Row(children: [
        CircleAvatar(radius: 24, backgroundColor: AppColors.ink, child: Icon(icon, color: AppColors.gold)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        const SizedBox(width: 8),
        ChunkyButton(label: price, fontSize: 14, onPressed: onBuy, color: const Color(0xFF6BE36B)),
      ]),
    );
  }
}
