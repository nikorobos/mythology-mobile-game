import 'package:flutter/material.dart';

import '../core/equipment.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../game_content.dart';
import '../l10n/strings.dart';
import 'equipment_screen.dart';
import 'squad_model.dart';
import 'theme.dart';
import 'widgets.dart';

IconData _skillIcon(Skill k) => switch (k.type) {
      SkillType.damageMulti => Icons.bolt,
      SkillType.damageAll => Icons.flash_on,
      SkillType.heal || SkillType.healAll => Icons.add,
      SkillType.taunt || SkillType.shield => Icons.shield_outlined,
      SkillType.stun => Icons.stars_outlined,
      SkillType.buffAtk => Icons.arrow_upward,
      SkillType.reflect => Icons.replay,
      SkillType.silence => Icons.volume_off_outlined,
      SkillType.none => Icons.circle_outlined,
    };

IconData _slotIcon(String slot) => switch (slot) {
      'weapon' => Icons.gavel,
      'armor' => Icons.shield_outlined,
      'helm' => Icons.sports_motorsports_outlined,
      'boots' => Icons.directions_walk,
      'relic' => Icons.auto_awesome_outlined,
      'ring' => Icons.circle_outlined,
      _ => Icons.circle_outlined,
    };

/// Hero detail (board: HeroDetail.dc.html). Pushed over the tabs.
class HeroDetailScreen extends StatelessWidget {
  const HeroDetailScreen({
    super.key,
    required this.session,
    required this.squad,
    required this.heroId,
  });

  final Session session;
  final SquadModel squad;
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
          listenable: Listenable.merge([player, squad]),
          builder: (context, _) {
            final st = player.state;
            final level = st.levelOf(heroId);
            final stars = st.starsOf(heroId);
            final built = unitWithEquipment(hero, level, c.economy,
                stars: stars, bonus: st.bonusFor(heroId, c.equipment));
            final stats = built.baseStats;
            final maxed = level >= c.economy.maxLevel;
            final canUp = st.canLevelUp(heroId, c.economy);
            final canStar = st.canStarUp(heroId, c.economy);
            final starCost = c.economy.starUpCost(stars);
            final (a, b) = mythColors(hero.mythology);
            final skills = [...hero.skills, if (hero.ultimate != null) hero.ultimate!];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SquareIconButton(
                        icon: Icons.chevron_left_rounded,
                        label: s.t('ui.back'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      GoldLabel(s.t('ui.hero')),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      _portrait(context, s, hero, level, a, b),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(s.t(hero.nameKey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: lilita(30)),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              RoleChip(
                                role: hero.role,
                                text: '${s.t('role.${hero.role.name}')} · '
                                        '${s.t('range.${hero.range.name}')}'
                                    .toUpperCase(),
                              ),
                              const SizedBox(height: 6),
                              StarRow(count: stars, size: 20),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              '${s.t('ui.level_long')} $level / ${c.economy.maxLevel}',
                              style: nunito(13)),
                          Text('${s.t('ui.gold')}: ${formatNumber(st.gold)}',
                              style: nunito(13, color: Pal.muted)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Bar(
                          value: level / c.economy.maxLevel,
                          color: Pal.green,
                          height: 8),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _stat(formatNumber(stats.hp), s.t('stat.hp')),
                          const SizedBox(width: 8),
                          _stat(formatNumber(stats.atk), s.t('stat.atk')),
                          const SizedBox(width: 8),
                          _stat(formatNumber(stats.def), s.t('stat.def')),
                          const SizedBox(width: 8),
                          _stat(formatNumber(stats.spd), s.t('stat.spd')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GoldLabel(s.t('ui.skills')),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final k in skills)
                            Expanded(
                                child: _skill(context, s, k,
                                    ult: k == hero.ultimate)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GoldLabel(s.t('ui.equipment')),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final slot in c.equipment.slots)
                            _slot(context, s, slot),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: GoldButton(
                          label: maxed
                              ? s.t('ui.max')
                              : s.t('ui.level_up').toUpperCase(),
                          onPressed: (!maxed && canUp)
                              ? () => player.levelUp(heroId)
                              : null,
                          sub: maxed
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CoinIcon(size: 14),
                                    const SizedBox(width: 5),
                                    Text(
                                        formatNumber(
                                            c.economy.levelUpCost(level)),
                                        style: nunito(13, color: Pal.ink)),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DarkButton(
                          label: starCost == null
                              ? s.t('ui.max')
                              : s.t('ui.star_up').toUpperCase(),
                          onPressed: canStar ? () => player.starUp(heroId) : null,
                          sub: starCost == null
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: SizedBox(
                                    width: 110,
                                    child: Bar(
                                      value: st.shardsOf(heroId) / starCost,
                                      color: Pal.gold,
                                      track: Pal.bg,
                                    ),
                                  ),
                                ),
                        ),
                      ),
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

  Widget _portrait(BuildContext context, Strings s, Unit hero, int level,
      Color a, Color b) {
    final inSquad = squad.contains(heroId);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 236,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.62, 1],
              colors: [a, b, const Color(0xFF241F55)]),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(child: HeroBust(unit: hero, size: 210)),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Pal.bg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: mythAccent(hero.mythology), width: 2),
                ),
                child: Text(s.t('myth.${hero.mythology}').toUpperCase(),
                    style: nunito(11,
                        color: mythAccent(hero.mythology), letterSpacing: 1.5)),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Pal.scrimStrong,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${s.t('ui.level')} $level', style: nunito(13)),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 8,
              child: Text(s.t('ui.placeholder_art'),
                  style: nunito(10, weight: 700, color: Pal.soft)),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Material(
                color: inSquad ? Pal.gold : Pal.scrimStrong,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    if (!squad.toggle(heroId)) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                            SnackBar(content: Text(s.t('ui.squad_full'))));
                    }
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(inSquad ? Icons.check : Icons.add,
                            size: 18, color: inSquad ? Pal.bg : Pal.cream),
                        const SizedBox(width: 6),
                        Text(
                            inSquad
                                ? s.t('ui.in_squad')
                                : s.t('ui.add_to_squad'),
                            style: nunito(13,
                                color: inSquad ? Pal.bg : Pal.cream)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: Pal.panel,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              FittedBox(child: Text(value, style: lilita(19))),
              Text(label, style: nunito(12, color: Pal.muted, letterSpacing: 1.5)),
            ],
          ),
        ),
      );

  Widget _skill(BuildContext context, Strings s, Skill k, {required bool ult}) {
    return Semantics(
      button: true,
      label: s.t(k.nameKey),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          backgroundColor: Pal.bg,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (_) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ult) GoldLabel(s.t('ui.ult')),
                Text(s.t(k.nameKey), style: lilita(24)),
                const SizedBox(height: 8),
                Text(s.t(k.descKey),
                    style: nunito(15, weight: 600, color: Pal.soft)),
              ],
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Pal.panel2,
                  shape: BoxShape.circle,
                  border: Border.all(color: Pal.gold, width: 3),
                ),
                child: Icon(_skillIcon(k), color: Pal.cream, size: 26),
              ),
              const SizedBox(height: 4),
              Text(s.t(k.nameKey),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: nunito(12, weight: 700, color: Pal.soft)),
              if (ult)
                Text(s.t('ui.ult'),
                    style: nunito(11, color: Pal.gold, letterSpacing: 1.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slot(BuildContext context, Strings s, String slot) {
    final item = session.player.state.wornInSlot(heroId, slot);
    final border = item == null ? Pal.dim : rarityColor(item.rarity);
    return Semantics(
      button: true,
      label: '${s.t('slot.$slot')}: ${item == null ? s.t('ui.empty_slot') : itemName(session.content.equipment, item, s)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => EquipmentScreen(session: session, heroId: heroId),
        )),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Pal.panel2,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: border, width: 3),
          ),
          child: Icon(item == null ? Icons.add : _slotIcon(slot),
              size: 24, color: item == null ? Pal.muted : Pal.cream),
        ),
      ),
    );
  }
}
