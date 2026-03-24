----------------------------------------------------------------------
-- Gimme - Class Reagent Database
-- TBC Classic 2.5.x
----------------------------------------------------------------------
local addonName, ns = ...

-- Each entry: { itemName, itemID, defaultCount, description }
-- defaultCount = suggested stock quantity

ns.ClassReagents = {
    PALADIN = {
        { itemName = "Symbol of Kings",    itemID = 21177, defaultCount = 0, description = "Greater Blessing of Kings" },
        { itemName = "Symbol of Divinity", itemID = 21177, defaultCount = 0, description = "Divine Intervention" },
    },
    MAGE = {
        { itemName = "Arcane Powder",         itemID = 17020, defaultCount = 0, description = "Arcane Brilliance, Remove Curse (r)" },
        { itemName = "Rune of Teleportation", itemID = 17031, defaultCount = 0, description = "Teleport spells" },
        { itemName = "Rune of Portals",       itemID = 17032, defaultCount = 0, description = "Portal spells" },
    },
    PRIEST = {
        { itemName = "Sacred Candle",  itemID = 17029, defaultCount = 0, description = "Prayer of Fortitude, Prayer of Shadow Protection, Prayer of Spirit" },
        { itemName = "Holy Candle",    itemID = 17028, defaultCount = 0, description = "Backup lower rank" },
    },
    DRUID = {
        { itemName = "Wild Quillvine",     itemID = 22148, defaultCount = 0, description = "Gift of the Wild" },
        { itemName = "Maple Seed",         itemID = 17034, defaultCount = 0, description = "Rebirth (Rank 5)" },
    },
    SHAMAN = {
        { itemName = "Ankh",              itemID = 17030, defaultCount = 0, description = "Reincarnation" },
        { itemName = "Fish Oil",          itemID = 8383,  defaultCount = 0, description = "Water Walking, Water Breathing" },
        { itemName = "Shiny Fish Scales", itemID = 17057, defaultCount = 0, description = "Water Breathing" },
    },
    WARLOCK = {
        { itemName = "Infernal Stone",    itemID = 5565,  defaultCount = 0, description = "Inferno" },
        { itemName = "Demonic Figurine",  itemID = 16583, defaultCount = 0, description = "Ritual of Doom" },
        { itemName = "Soul Shard",        itemID = 6265,  defaultCount = 0, description = "Various (tracked only, not purchased)" },
    },
    ROGUE = {
        -- Track actual poisons, not mats
        { itemName = "Instant Poison VII",      itemID = 21927, defaultCount = 0, description = "Instant damage on hit" },
        { itemName = "Deadly Poison VII",       itemID = 22054, defaultCount = 0, description = "Stacking nature DoT" },
        { itemName = "Crippling Poison",        itemID = 3775,  defaultCount = 0, description = "Slows target" },
        { itemName = "Mind-Numbing Poison III", itemID = 9186,  defaultCount = 0, description = "Increases cast time" },
        { itemName = "Wound Poison V",          itemID = 22055, defaultCount = 0, description = "Reduces healing" },
        { itemName = "Anesthetic Poison",       itemID = 21835, defaultCount = 0, description = "Removes enrage" },
        { itemName = "Flash Powder",            itemID = 5140,  defaultCount = 0, description = "Vanish" },
    },
    HUNTER = {
        -- Ammo can vary; we track common types
        { itemName = "Warden's Arrow",         itemID = 31737, defaultCount = 0, description = "Arrows (TBC)" },
        { itemName = "Halaani Razorshaft",     itemID = 28056, defaultCount = 0, description = "Arrows" },
        { itemName = "Timeless Arrow",         itemID = 34581, defaultCount = 0, description = "Arrows (high-end)" },
        { itemName = "Warden's Slug",          itemID = 31735, defaultCount = 0, description = "Bullets (TBC)" },
        { itemName = "Halaani Grimshot",       itemID = 28061, defaultCount = 0, description = "Bullets" },
        { itemName = "Timeless Shell",         itemID = 34582, defaultCount = 0, description = "Bullets (high-end)" },
    },
    WARRIOR = {},
}

-- Rogue poisons: highest ranks only for the HUD
-- Organized by weapon slot
ns.RoguePoisonsMH = {
    { displayName = "Deadly VII",  itemName = "Deadly Poison VII",  itemID = 22054 },
    { displayName = "Wound V",     itemName = "Wound Poison V",     itemID = 22055 },
}

ns.RoguePoisonsOH = {
    { displayName = "Crippling",     itemName = "Crippling Poison",        itemID = 3775  },
    { displayName = "Instant VII",   itemName = "Instant Poison VII",      itemID = 21927 },
    { displayName = "Mind-Numb III", itemName = "Mind-Numbing Poison III", itemID = 9186  },
}

-- Mats that rogues need to craft poisons (for smart alert logic)
-- If they have mats, they can make more poisons — don't alert
ns.RoguePoisonMats = {
    "Deathweed",           -- Crippling, Mind-Numbing
    "Essence of Pain",     -- Instant Poison
    "Essence of Agony",    -- Deadly Poison
    "Dust of Deterioration", -- Wound Poison
}
