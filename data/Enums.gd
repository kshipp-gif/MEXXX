## Shared enumerations for the MEXXX Mech Deckbuilder.
## Registered as an autoload so these enums are accessible globally via Enums.Rarity, etc.
extends Node

enum Rarity    { COMMON, UNCOMMON, RARE, LEGENDARY }
enum CardType  { ATTACK, DEFENSE, MOVEMENT, UTILITY, COMBO }
enum SlotType  { ARM, LEG, BACK, HEAD }
