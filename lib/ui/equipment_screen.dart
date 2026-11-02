import 'package:flutter/material.dart';

import '../core/equipment.dart';
import '../core/format.dart';
import '../game_content.dart';
import '../l10n/strings.dart';
import 'theme.dart' show rarityColor;

const _bg = Color(0xFF14122B);
const _panel = Color(0xFF1D1A3D);
const _gold = Color(0xFFF2C14E);
const _cream = Color(0xFFF3EEDC);
const _muted = Color(0xFFB9B4D6);

/// "+12% ATK" / "+5 DEF" for one item.
String itemBonusText(EquipmentConfig cfg, Equipment item, Strings s) {
  final stat = cfg.statOf(item);
  if (stat == null) return '';
  final v = cfg.rawValue(item);
  final name = s.t('stat.${stat.name}');
  return switch (stat) {
    BonusStat.hp || BonusStat.atk => '+${(v * 100).round()}% $name',
    BonusStat.def || BonusStat.spd => '+${v.round()} $name',
  };
}

String itemName(EquipmentConfig cfg, Equipment item, Strings s) {
  final t = cfg.templateById(item.templateId);
  return t == null ? item.templateId : s.t(t.nameKey);
}

/// The six equipment slots of one hero, plus a picker for each slot.
class EquipmentScreen extends StatelessWidget {
  const EquipmentScreen(
      {super.key, required this.session, required this.heroId});

  final Session session;
  final String heroId;

  @override
  Widget build(BuildContext context) {
    final c = session.content;
    final player = session.player;
    final s = c.strings;
    final hero = c.heroes.firstWhere((h) => h.id == heroId);
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bg,
            foregroundColor: _cream,
            title: Text('${s.t(hero.nameKey)} - ${s.t('ui.equipment')}'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    '${s.t('ui.gold')}: ${formatNumber(player.state.gold)}',
                    style: const TextStyle(
                        color: _gold, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final slot in c.equipment.slots) _slotCard(context, slot),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _slotCard(BuildContext context, String slot) {
    final c = session.content;
    final player = session.player;
    final s = c.strings;
    final cfg = c.equipment;
    final item = player.state.wornInSlot(heroId, slot);
    final cost = item == null ? null : cfg.upgradeCost(item);
    return Card(
      color: _panel,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.t('slot.$slot'),
                      style: const TextStyle(color: _muted, fontSize: 12)),
                  if (item == null)
                    Text(s.t('ui.empty_slot'),
                        style: const TextStyle(color: _muted, fontSize: 16))
                  else ...[
                    Text(
                      '${itemName(cfg, item, s)}'
                      '${item.level > 0 ? ' +${item.level}' : ''}',
                      style: TextStyle(
                          color: rarityColor(item.rarity),
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                    Text(
                      '${s.t('rarity.${item.rarity.name}')}  '
                      '${itemBonusText(cfg, item, s)}',
                      style: const TextStyle(color: _cream, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            if (item != null) ...[
              if (cost != null)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: _bg,
                    minimumSize: const Size(72, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: player.state.gold >= cost
                      ? () => player.upgradeItem(item.id)
                      : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_upward, size: 16),
                      const SizedBox(width: 4),
                      Text(formatNumber(cost)),
                    ],
                  ),
                )
              else
                Text(s.t('ui.max'),
                    style: const TextStyle(
                        color: _gold, fontWeight: FontWeight.w900)),
              const SizedBox(width: 4),
              IconButton(
                tooltip: s.t('ui.unequip'),
                color: _muted,
                icon: const Icon(Icons.close),
                onPressed: () => player.unequipSlot(heroId, slot),
              ),
            ],
            IconButton(
              tooltip: s.t('ui.equip'),
              color: _cream,
              icon: const Icon(Icons.swap_horiz),
              onPressed: () => _pick(context, slot),
            ),
          ],
        ),
      ),
    );
  }

  void _pick(BuildContext context, String slot) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _bg,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, scroll) => _PickerList(
            session: session,
            heroId: heroId,
            slot: slot,
            controller: scroll),
      ),
    );
  }
}

class _PickerList extends StatelessWidget {
  const _PickerList({
    required this.session,
    required this.heroId,
    required this.slot,
    required this.controller,
  });

  final Session session;
  final String heroId;
  final String slot;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final c = session.content;
    final player = session.player;
    final s = c.strings;
    final cfg = c.equipment;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final items = [
          for (final i in player.state.inventory)
            if (i.slot == slot) i
        ]..sort((a, b) {
            final r = b.rarity.index.compareTo(a.rarity.index);
            return r != 0 ? r : b.level.compareTo(a.level);
          });
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(s.t('ui.no_items'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted)),
            ),
          );
        }
        return ListView(
          controller: controller,
          padding: const EdgeInsets.all(12),
          children: [
            for (final item in items) _row(context, item, cfg, s),
          ],
        );
      },
    );
  }

  Widget _row(
      BuildContext context, Equipment item, EquipmentConfig cfg, Strings s) {
    final wearer = session.player.state.wearerOf(item.id);
    final worn = wearer == heroId;
    final cost = cfg.upgradeCost(item);
    final wearerName = wearer == null || worn
        ? null
        : s.t(session.content.heroes
            .firstWhere((h) => h.id == wearer)
            .nameKey);
    return Card(
      color: _panel,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${itemName(cfg, item, s)}'
                    '${item.level > 0 ? ' +${item.level}' : ''}',
                    style: TextStyle(
                        color: rarityColor(item.rarity),
                        fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${s.t('rarity.${item.rarity.name}')}  '
                    '${itemBonusText(cfg, item, s)}',
                    style: const TextStyle(color: _cream, fontSize: 12),
                  ),
                  if (wearerName != null)
                    Text('${s.t('ui.worn_by')} $wearerName',
                        style: const TextStyle(color: _muted, fontSize: 11)),
                ],
              ),
            ),
            if (cost != null)
              IconButton(
                tooltip: '${s.t('ui.upgrade')} (${formatNumber(cost)})',
                color: _gold,
                icon: const Icon(Icons.arrow_upward),
                onPressed: session.player.state.gold >= cost
                    ? () => session.player.upgradeItem(item.id)
                    : null,
              ),
            IconButton(
              tooltip: s.t('ui.sell'),
              color: _muted,
              icon: const Icon(Icons.sell_outlined),
              onPressed: wearer == null
                  ? () => session.player.sellItem(item.id)
                  : null,
            ),
            IconButton(
              tooltip: s.t('ui.equip'),
              color: worn ? _muted : _cream,
              icon: Icon(worn ? Icons.check : Icons.add_circle_outline),
              onPressed: worn
                  ? null
                  : () {
                      session.player.equipItem(heroId, item.id);
                      Navigator.of(context).pop();
                    },
            ),
          ],
        ),
      ),
    );
  }
}
