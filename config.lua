Config = {}

-- Maximum weight a player's bag can hold (kg)
Config.MaxWeightBag = 1000.0

-- Maximum weight the protected container can hold (kg)
Config.MaxWeightContainer = 200.0

-- RECHARGEMENT DES ARMES :
-- true : L'arme est rechargée automatiquement quand on l'équipe (enlever/remettre).
-- false : L'arme garde ses munitions. Il faut utiliser des items "AMMO" pour recharger.
Config.AutoReloadOnEquip = true

-- Items that spawn a vehicle when used.
-- Key = item name in DB, Value = vehicle spawn model name
Config.VehicleItems = {
    -- EXISTANTS
    ['VEHICLE_DELUXO'] = 'deluxo',
    ['VEHICLE_SCARAB'] = 'scarab',

    -- CITADINES ET COMPACTES
    ['VEHICLE_PANTO'] = 'panto',
    ['VEHICLE_BLISTA'] = 'blista',
    ['VEHICLE_BRIOSO'] = 'brioso',
    ['VEHICLE_PRAIRIE'] = 'prairie',
    ['VEHICLE_DILETTANTE'] = 'dilettante',
    ['VEHICLE_ISSI2'] = 'issi2',
    ['VEHICLE_RHAPSODY'] = 'rhapsody',

    -- BERLINES ET LUXE
    ['VEHICLE_FUGITIVE'] = 'fugitive',
    ['VEHICLE_TAILGATER'] = 'tailgater',
    ['VEHICLE_FELON'] = 'felon',
    ['VEHICLE_SCHAFTER2'] = 'schafter2',
    ['VEHICLE_ORACLE2'] = 'oracle2',
    ['VEHICLE_EXEMPLAR'] = 'exemplar',
    ['VEHICLE_WINDSOR'] = 'windsor',

    -- SPORTIVES ET SUPERCARS
    ['VEHICLE_COMET2'] = 'comet2',
    ['VEHICLE_FELTZER2'] = 'feltzer2',
    ['VEHICLE_ELEGY'] = 'elegy',
    ['VEHICLE_JESTER'] = 'jester',
    ['VEHICLE_BANSHEE'] = 'banshee',
    ['VEHICLE_MASSACRO'] = 'massacro',
    ['VEHICLE_KURUMA'] = 'kuruma',
    ['VEHICLE_ZENTORNO'] = 'zentorno',
    ['VEHICLE_ADDER'] = 'adder',
    ['VEHICLE_T20'] = 't20',
    ['VEHICLE_OSIRIS'] = 'osiris',
    ['VEHICLE_NERO'] = 'nero',
    ['VEHICLE_TEMPESTA'] = 'tempesta',

    -- SUV ET 4X4
    ['VEHICLE_DUBSTA'] = 'dubsta',
    ['VEHICLE_GRANGER'] = 'granger',
    ['VEHICLE_BALLER'] = 'baller',
    ['VEHICLE_MESA'] = 'mesa',
    ['VEHICLE_BISON'] = 'bison',
    ['VEHICLE_SANDKING'] = 'sandking',
    ['VEHICLE_PATRIOT'] = 'patriot',
    ['VEHICLE_CONTENDER'] = 'contender',

    -- MOTOS
    ['VEHICLE_FAGGIO'] = 'faggio',
    ['VEHICLE_SANCHEZ'] = 'sanchez',
    ['VEHICLE_AKUMA'] = 'akuma',
    ['VEHICLE_BATI'] = 'bati',
    ['VEHICLE_PCJ'] = 'pcj',
    ['VEHICLE_DAEMON'] = 'daemon',
    ['VEHICLE_SANCTUS'] = 'sanctus',
    ['VEHICLE_BF400'] = 'bf400',

    -- UTILITAIRES
    ['VEHICLE_TAXI'] = 'taxi',
    ['VEHICLE_AMBULANCE'] = 'ambulance',
    ['VEHICLE_FIRETRUK'] = 'firetruk',
    ['VEHICLE_POLICE'] = 'police',
    ['VEHICLE_TOWTRUCK'] = 'towtruck',
    ['VEHICLE_BOXVILLE2'] = 'boxville2',
    ['VEHICLE_RUBBLE'] = 'rubble',

    -- MUSCLE CARS
    ['VEHICLE_DOMINATOR'] = 'dominator',
    ['VEHICLE_GAUNTLET'] = 'gauntlet',
    ['VEHICLE_SABREGT'] = 'sabregt',
    ['VEHICLE_BUCCANEER'] = 'buccaneer',
    ['VEHICLE_DUKES'] = 'dukes',
    ['VEHICLE_HERMES'] = 'hermes',

    -- MILITAIRE ET SPÉCIAUX
    ['VEHICLE_INSURGENT'] = 'insurgent',
    ['VEHICLE_LIMO2'] = 'limo2',
    ['VEHICLE_BARRACKS'] = 'barracks',
    ['VEHICLE_OPPRESSOR2'] = 'oppressor2',
    ['VEHICLE_RUINER2'] = 'ruiner2',
    ['VEHICLE_VIGILANTE'] = 'vigilante',

    -- AÉRIEN
    ['VEHICLE_MAVERICK'] = 'maverick',
    ['VEHICLE_BUZZARD2'] = 'buzzard2',
    ['VEHICLE_FROGGER'] = 'frogger',
    ['VEHICLE_VESTRA'] = 'vestra',
}

-- Items that act as custom weapons (non-native GTA weapons).
-- Key = item name in DB, Value = native weapon hash name
-- Example: ['custom_katana'] = 'WEAPON_KNIFE'
Config.WeaponItems = {}
