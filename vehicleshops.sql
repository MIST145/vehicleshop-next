-- vehicleshops.sql
-- FIXED: Removed DEFAULT ('[]') parentheses for MariaDB compatibility.
-- TEXT/LONGTEXT columns cannot have DEFAULT values in MariaDB; values are always set explicitly by the application.
CREATE TABLE IF NOT EXISTS `vehicle_shops` (
    `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `owner`     VARCHAR(100) DEFAULT NULL,
    `name`      VARCHAR(50)  NOT NULL,
    `locations` LONGTEXT     NOT NULL,
    `employees` LONGTEXT     NOT NULL,
    `stock`     LONGTEXT     NOT NULL,
    `displays`  LONGTEXT     NOT NULL,
    `funds`     INT          NOT NULL DEFAULT 0,
    `price`     INT          NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;