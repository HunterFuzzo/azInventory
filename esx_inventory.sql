CREATE TABLE IF NOT EXISTS `user_inventory_custom` (
    `identifier` varchar(60) NOT NULL,
    `container` longtext DEFAULT '[]',
    `shortkeys` longtext DEFAULT '[]',
    PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
