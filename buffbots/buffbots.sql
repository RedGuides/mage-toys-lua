create table bots(
    buff_hash varchar(200) PRIMARY KEY, 
    buff_bot varchar(50), 
    buff_bot_class varchar(30), 
    buff_recipient varchar(60), 
    buff_list varchar(100), 
    buff_state int, 
    requested_item_count int
);

create table bot_chat(
    buff_bot varchar(50) PRIMARY KEY, 
    active int
);
