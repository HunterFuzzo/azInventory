USE ESXLegacy_A8489B;

INSERT IGNORE INTO items (name, label, weight, rare, can_remove) VALUES 
-- ===============================
-- VÉHICULES
-- ===============================
('VEHICLE_DELUXO', 'Deluxo', 20.0, 0, 1),

-- ===============================
-- PISTOLETS
-- ===============================
('WEAPON_PISTOL', 'Pistolet', 5, 0, 1),
('WEAPON_COMBATPISTOL', 'Pistolet de combat', 5, 0, 1),
('WEAPON_APPISTOL', 'Pistolet perforant', 5, 0, 1),
('WEAPON_PISTOL50', 'Pistolet .50', 6, 0, 1),
('WEAPON_SNSPISTOL', 'Pistolet pétoire', 4, 0, 1),
('WEAPON_HEAVYPISTOL', 'Pistolet lourd', 6, 0, 1),
('WEAPON_VINTAGEPISTOL', 'Pistolet vintage', 5, 0, 1),
('WEAPON_FLAREGUN', 'Pistolet de détresse', 2, 0, 1),
('WEAPON_MARKSMANPISTOL', 'Pistolet de précision', 5, 0, 1),
('WEAPON_REVOLVER', 'Revolver lourd', 6, 0, 1),
('WEAPON_DOUBLEACTION', 'Revolver double action', 5, 0, 1),
('WEAPON_CERAMICPISTOL', 'Pistolet en céramique', 4, 0, 1),
('WEAPON_GADGETPISTOL', 'Pistolet Perico', 5, 0, 1),
('WEAPON_PISTOL_MK2', 'Pistolet Mk II', 5, 0, 1),
('WEAPON_SNSPISTOL_MK2', 'Pistolet pétoire Mk II', 4, 0, 1),
('WEAPON_REVOLVER_MK2', 'Revolver lourd Mk II', 6, 0, 1),

-- ===============================
-- MITRAILLETTES & SMG
-- ===============================
('WEAPON_MICROSMG', 'Micro SMG', 5, 0, 1),
('WEAPON_SMG', 'SMG', 8, 0, 1),
('WEAPON_ASSAULTSMG', 'SMG d''Assaut', 8, 0, 1),
('WEAPON_COMBATPDW', 'PDW de Combat', 8, 0, 1),
('WEAPON_MACHINEPISTOL', 'Pistolet mitrailleur', 6, 0, 1),
('WEAPON_MINISMG', 'Mini SMG', 5, 0, 1),
('WEAPON_SMG_MK2', 'SMG Mk II', 8, 0, 1),

-- ===============================
-- FUSILS A POMPE
-- ===============================
('WEAPON_PUMPSHOTGUN', 'Fusil à Pompe', 10, 0, 1),
('WEAPON_SAWNOFFSHOTGUN', 'Fusil à canon scié', 8, 0, 1),
('WEAPON_ASSAULTSHOTGUN', 'Fusil à pompe d''assaut', 12, 0, 1),
('WEAPON_BULLPUPSHOTGUN', 'Fusil à pompe Bullpup', 10, 0, 1),
('WEAPON_MUSKET', 'Mousquet', 10, 0, 1),
('WEAPON_HEAVYSHOTGUN', 'Fusil à pompe lourd', 12, 0, 1),
('WEAPON_DBLSHOTGUN', 'Fusil à double canon', 8, 0, 1),
('WEAPON_AUTOSHOTGUN', 'Fusil à pompe automatique', 12, 0, 1),
('WEAPON_COMBATSHOTGUN', 'Fusil à pompe de combat', 10, 0, 1),
('WEAPON_PUMPSHOTGUN_MK2', 'Fusil à pompe Mk II', 10, 0, 1),

-- ===============================
-- FUSILS D'ASSAUT
-- ===============================
('WEAPON_ASSAULTRIFLE', 'Fusil d''assaut', 10, 0, 1),
('WEAPON_CARBINERIFLE', 'Carabine', 10, 0, 1),
('WEAPON_ADVANCEDRIFLE', 'Fusil Avancé', 10, 0, 1),
('WEAPON_SPECIALCARBINE', 'Carabine Spéciale', 10, 0, 1),
('WEAPON_BULLPUPRIFLE', 'Fusil Bullpup', 10, 0, 1),
('WEAPON_COMPACTRIFLE', 'Fusil compact', 8, 0, 1),
('WEAPON_MILITARYRIFLE', 'Fusil militaire', 10, 0, 1),
('WEAPON_HEAVYRIFLE', 'Fusil lourd', 12, 0, 1),
('WEAPON_TACTICALRIFLE', 'Fusil tactique', 10, 0, 1),
('WEAPON_ASSAULTRIFLE_MK2', 'Fusil d''assaut Mk II', 10, 0, 1),
('WEAPON_CARBINERIFLE_MK2', 'Carabine Mk II', 10, 0, 1),
('WEAPON_SPECIALCARBINE_MK2', 'Carabine spéciale Mk II', 10, 0, 1),
('WEAPON_BULLPUPRIFLE_MK2', 'Fusil Bullpup Mk II', 10, 0, 1),

-- ===============================
-- MITRAILLEUSES LOURDES (LMG)
-- ===============================
('WEAPON_MG', 'Mitrailleuse', 15, 0, 1),
('WEAPON_COMBATMG', 'Mitrailleuse de combat', 15, 0, 1),
('WEAPON_COMBATMG_MK2', 'Mitrailleuse de combat Mk II', 15, 0, 1),

-- ===============================
-- FUSILS DE PRECISION (SNIPERS)
-- ===============================
('WEAPON_SNIPERRIFLE', 'Fusil de Sniper', 15, 0, 1),
('WEAPON_HEAVYSNIPER', 'Fusil de sniper lourd', 20, 0, 1),
('WEAPON_MARKSMANRIFLE', 'Fusil à lunette', 12, 0, 1),
('WEAPON_PRECISIONRIFLE', 'Fusil de précision', 15, 0, 1),
('WEAPON_HEAVYSNIPER_MK2', 'Sniper lourd Mk II', 20, 0, 1),
('WEAPON_MARKSMANRIFLE_MK2', 'Fusil à lunette Mk II', 12, 0, 1),

-- ===============================
-- ARMES LOURDES
-- ===============================
('WEAPON_RPG', 'Lance-roquettes', 20, 0, 1),
('WEAPON_GRENADELAUNCHER', 'Lance-grenades', 18, 0, 1),
('WEAPON_HOMINGLAUNCHER', 'Lance-missiles', 20, 0, 1),
('WEAPON_COMPACTLAUNCHER', 'Lance-grenades compact', 12, 0, 1),

-- ===============================
-- PROJECTILES (THROWABLES)
-- ===============================
('WEAPON_GRENADE', 'Grenade', 1, 0, 1),
('WEAPON_MOLOTOV', 'Cocktail Molotov', 1, 0, 1),

-- ===============================
-- CONSUMABLE
-- ===============================
('CONSUMABLE_BANDAGE', 'Bandage', 0.1, 0, 1),
('CONSUMABLE_MEDKIT', 'Medkit', 1.0, 0, 1),
('CONSUMABLE_BLUE_SYRINGE', 'Seringue Bleue', 0.1, 0, 1),
('CONSUMABLE_GREEN_SYRINGE', 'Seringue Verte', 0.1, 0, 1),
('CONSUMABLE_RED_SYRINGE', 'Seringue Rouge', 0.1, 0, 1),

-- ===============================
-- ÉQUIPEMENT
-- ===============================
('EQUIPMENT_KEVLAR', 'Kevlar', 2.0, 0, 1);