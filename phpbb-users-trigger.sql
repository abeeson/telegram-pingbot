CREATE TRIGGER `username_to_pingbot_users` BEFORE INSERT ON `phpbb_users`
 FOR EACH ROW insert into pingbot_users values (NEW.username,'NULL')
