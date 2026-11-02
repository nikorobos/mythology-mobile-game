import 'package:flutter/material.dart';

import '../core/equipment.dart';
import '../core/format.dart';
import '../game_content.dart';
import '../l10n/strings.dart';
import 'theme.dart';
import 'widgets.dart';

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
/// (Board-styled: same layout language as Hero Detail.)
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
    return Scaffold(
      backgroundColor: Pal.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: player,
          builder: (context, _) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Row(
                    children: [
                      SquareIconButton(
                        icon: Icons.chevron_left_rounded,
                        label: s.t('ui.back'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      PortraitSquare(unit: hero, size: 44),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.t(hero.nameKey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: lilita(22)),
                            GoldLabel(s.t('ui.equipment')),
                          ],
                        ),
                      ),
                      CurrencyPill(
                          currency: Currency.gold,
                          text: formatNumber(player.state.gold),
                          semanticLabel: s.t('ui.gold')),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      for (final slot in c.equipment.slots)
                        _slotCard(context, slot),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _slotCard(BuildContext context, String slot) {
    final c = session.content;
    final player = session.player;
    final s = c.strings;
    final cfg = c.equipment;
    final item = player.state.wornInSlot(heroId, slot);
    final cost = item == null ? null : cfg.upgradeCost(item);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Pal.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _SlotTile(slot: slot, item: item),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('slot.$slot').toUpperCase(),
                    style: nunito(11, color: Pal.muted, letterSpacing: 1.5)),
                if (item == null)
                  Text(s.t('ui.empty_slot'),
                      style: nunito(16, weight: 700, color: Pal.muted))
                else ...[
                  Text(
                    '${itemName(cfg, item, s)}'
                    '${item.level > 0 ? ' +${item.level}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: nunito(16, color: rarityColor(item.rarity)),
                  ),
                  Text(
                    '${s.t('rarity.${item.rarity.name}')}  '
                    '${itemBonusText(cfg, item, s)}',
                    style: nunito(12, weight: 700, color: Pal.soft),
                  ),
                ],
              ],
            ),
          ),
          if (item != null) ...[
            if (cost != null)
              _UpgradeButton(
                cost: cost,
                onPressed: player.state.gold >= cost
                    ? () => player.upgradeItem(item.id)
                    : null,
              )
            else
              Text(s.t('ui.max'), style: nunito(14, color: Pal.gold)),
            const SizedBox(width: 6),
            SquareIconButton(
              icon: Icons.close,
              label: s.t('ui.unequip'),
              color: Pal.muted,
              onPressed: () => player.unequipSlot(heroId, slot),
            ),
          ],
          const SizedBox(width: 6),
          SquareIconButton(
            icon: Icons.swap_horiz,
            label: s.t('ui.equip'),
            onPressed: () => _pick(context, slot),
          ),
        ],
      ),
    );
  }

  void _pick(BuildContext context, String slot) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Pal.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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

/// Rarity-bordered square with the slot icon (same look as Hero Detail).
class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot, required this.item});

  final String slot;
  final Equipment? item;

  @override
  Widget build(BuildContext context) {
    final it = item;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Pal.panel2,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
            color: it == null ? Pal.dim : rarityColor(it.rarity), width: 3),
      ),
      child: Icon(slotIcon(slot),
          size: 24, color: it == null ? Pal.muted : Pal.cream),
    );
  }
}

class _UpgradeButton extends StatelessWidget {
  const _UpgradeButton({required this.cost, required this.onPressed});

  final int cost;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Pal.goldLight, Pal.goldDark],
          ),
          boxShadow: const [
            BoxShadow(color: Pal.goldShadow, offset: Offset(0, 3))
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_upward, size: 16, color: Pal.ink),
                  const SizedBox(width: 4),
                  Text(formatNumber(cost), style: nunito(13, color: Pal.ink)),
                ],
              ),
            ),
          ),
        ),
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
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(s.t('slot.$slot'), style: lilita(22)),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(s.t('ui.no_items'),
                            textAlign: TextAlign.center,
                            style: nunito(14, weight: 700, color: Pal.muted)),
                      ),
                    )
                  : ListView(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        for (final item in items) _row(context, item, cfg, s),
                      ],
                    ),
            ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: Pal.panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _SlotTile(slot: slot, item: item),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${itemName(cfg, item, s)}'
                  '${item.level > 0 ? ' +${item.level}' : ''}',
                  style: nunito(15, color: rarityColor(item.rarity)),
                ),
                Text(
                  '${s.t('rarity.${item.rarity.name}')}  '
                  '${itemBonusText(cfg, item, s)}',
                  style: nunito(12, weight: 700, color: Pal.soft),
                ),
                if (wearerName != null)
                  Text('${s.t('ui.worn_by')} $wearerName',
                      style: nunito(11, weight: 600, color: Pal.muted)),
              ],
            ),
          ),
          if (cost != null)
            IconButton(
              tooltip: '${s.t('ui.upgrade')} (${formatNumber(cost)})',
              color: Pal.gold,
              icon: const Icon(Icons.arrow_upward),
              onPressed: session.player.state.gold >= cost
                  ? () => session.player.upgradeItem(item.id)
                  : null,
            ),
          IconButton(
            tooltip: s.t('ui.sell'),
            color: Pal.muted,
            icon: const Icon(Icons.sell_outlined),
            onPressed: wearer == null
                ? () => session.player.sellItem(item.id)
                : null,
          ),
          IconButton(
            tooltip: s.t('ui.equip'),
            color: worn ? Pal.muted : Pal.cream,
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
    );
  }
}
