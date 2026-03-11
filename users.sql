-- SQL Migration for az_inventory profile stats
-- Standard syntax for maximum compatibility

ALTER TABLE `users` ADD COLUMN `kills` INT(11) DEFAULT 0;
ALTER TABLE `users` ADD COLUMN `deaths` INT(11) DEFAULT 0;
ALTER TABLE `users` ADD COLUMN `assists` INT(11) DEFAULT 0;
ALTER TABLE `users` ADD COLUMN `kill_confirmed` INT(11) DEFAULT 0;
