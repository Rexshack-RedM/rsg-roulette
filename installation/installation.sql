-- created automatically on resource start, provided here for manual installs
CREATE TABLE IF NOT EXISTS `rsg_roulette_tables` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `x` FLOAT NOT NULL,
    `y` FLOAT NOT NULL,
    `z` FLOAT NOT NULL,
    `heading` FLOAT NOT NULL DEFAULT 0,
    `room` BIGINT NOT NULL DEFAULT 0,
    `placed_by` VARCHAR(50) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
);
