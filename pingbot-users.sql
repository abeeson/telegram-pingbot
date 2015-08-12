CREATE TABLE IF NOT EXISTS `pingbot_users` (
  `user` text COLLATE utf8_unicode_ci NOT NULL,
  `chat_id` int(20) DEFAULT '0',
  `blocked` tinyint(1) NOT NULL DEFAULT '0',
  `muted` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

