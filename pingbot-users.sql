CREATE TABLE IF NOT EXISTS `pingbot_users` (
  `user` text COLLATE utf8_unicode_ci NOT NULL,
  `chat_id` int(20) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

