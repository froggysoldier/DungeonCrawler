# Datenexport für Godot

Erzeugt von `npm run export:godot`. Nicht von Hand bearbeiten.

## achievement_families
Exporte: –
Nicht exportierbar (Funktionen, in GDScript nachbauen):
- familyAchievements
- nextGoals

## achievements
Exporte: ACHIEVEMENT_CATEGORIES, ACHIEVEMENTS
Nicht exportierbar (Funktionen, in GDScript nachbauen):
- ACHIEVEMENTS[].check
- categoryOf

## achievements_moments
Exporte: MOMENT_ACHIEVEMENTS
Nicht exportierbar (Funktionen, in GDScript nachbauen):
- MOMENT_ACHIEVEMENTS[].check

## achievements_more
Exporte: MORE_ACHIEVEMENTS
Nicht exportierbar (Funktionen, in GDScript nachbauen):
- MORE_ACHIEVEMENTS[].check

## achievements_social
Exporte: SOCIAL_ACHIEVEMENTS
Nicht exportierbar (Funktionen, in GDScript nachbauen):
- SOCIAL_ACHIEVEMENTS[].check

## classes
Exporte: ABILITIES, ARCHETYPE_NAMES, CLASS_RARITY_NAMES, CLASSES
Nicht exportierbar (Funktionen, in GDScript nachbauen):
- CLASSES[].*.check
- CLASSES[].score

## crafting
Exporte: RECIPES

## crawlers
Exporte: FIRST_NAMES, LAST_NAMES, BACKGROUNDS, PERSONALITIES, TIP_LINES, PARTY_BARKS, DEATH_LINES, START_POPULATION, FLOOR_LOSS, COLLAPSE_LOSS, ANNOUNCE_EVERY, PARTY_MAX

## facets
Exporte: PART_PLURAL, MOVE_PLURAL, PART_BOX, TARGET_FACETS, SELF_FACETS, STAGES, STAGE_NUMERALS, PATTERN_COMMENTS, SKILL_UNLOCK_HITS

## interview
Exporte: INTERVIEW, LEGACY_ORDER, INTERVIEW_COMBOS, BASE_STATS
Nicht exportierbar (Funktionen, in GDScript nachbauen):
- INTERVIEW[].when
- INTERVIEW_COMBOS[].when
- visibleQuestions

## items
Exporte: RARITY_ORDER, RARITY_NAMES, RARITY_COLORS, SLOT_NAMES, BASE_ITEMS, FOOD_IDS, UNIQUE_ITEMS, AFFIXES, RARITY_AFFIXES, ITEM_QUIPS
Nicht exportierbar (Funktionen, in GDScript nachbauen):
- AFFIXES[].bonuses

## monsters
Exporte: MONSTERS, HOOD_BOSSES, GHOST_DEF

## mounts
Exporte: MOUNTS, MOUNT_ITEMS

## pets
Exporte: PET_SPECIES, EGG_SPECIES, TAMEABLE, HATCH_TURNS, PET_ABILITIES, PET_FORMS, PET_PATHS, EVOLVE_LEVELS

## quests
Exporte: HUNT_TEXTS, FETCH_ITEMS, DELIVER_WANTS, RESCUE_TEXTS, BOSS_TEXTS, QUEST_THANKS, MAX_ACTIVE_QUESTS

## races
Exporte: RACES
Nicht exportierbar (Funktionen, in GDScript nachbauen):
- RACES[].*.check

## skills
Exporte: SKILL_CATEGORY_NAMES, SKILLS
Nicht exportierbar (Funktionen, in GDScript nachbauen):
- SKILLS[].effect
- skillXpNeeded

## specials
Exporte: SPECIAL_TEXT

## spells
Exporte: SPELLS, SPELL_MAX_LEVEL
Nicht exportierbar (Funktionen, in GDScript nachbauen):
- spellXpNeeded

## sponsors
Exporte: MAX_SPONSORS, SPONSORS

## talkshow
Exporte: SHOW_TITLE, SHOW_HOST, SHOW_INTRO, TONE_NAMES, SHOW_QUESTIONS, SHOW_OUTRO_GOOD, SHOW_OUTRO_OK, SHOW_OUTRO_BAD
Nicht exportierbar (Funktionen, in GDScript nachbauen):
- SHOW_QUESTIONS[].when

## traits
Exporte: TRAITS, TRAIT_KIND_NAMES
Nicht exportierbar (Funktionen, in GDScript nachbauen):
- TRAITS[].*.check

## viewers
Exporte: FAN_THRESHOLDS, VIEWER_NAMES, VIEWER_COMMENTS, FAN_GIFTS

## world
Exporte: SHOW_NAME, SYSTEM_NAME, HOOD_NAMES, MINUTES_PER_TURN, FLOORS, LAST_PLAYABLE_FLOOR, ARRIVAL_ROOM, ROOM_FLAVORS, START_ROOM, GUILD_ROOM, SAFE_ROOM_FREEBIE, SAFE_ROOM_RESTAURANT, RESTAURANT_HOSTS, RESTAURANT_MENU, BOX_TIER_NAMES, BOX_TIER_COLORS, BOX_TIERS, BOX_TYPE_NAMES, BOX_CONTENTS, DEFAULT_GUIDE, LEVEL_UP_QUIPS, DEATH_QUIPS, COLLAPSE_WARNINGS
Nicht exportierbar (Funktionen, in GDScript nachbauen):
- tutorialPages
