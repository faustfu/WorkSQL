set nocount on
declare @tb_list table(
    tablename varchar(30)
);
declare @sql varchar(8000),
        @TABLE_NAME sysname;
insert into @tb_list
select TABLE_NAME
  from INFORMATION_SCHEMA.Tables
 where TABLE_TYPE = 'BASE TABLE'
   and TABLE_NAME in ('bnd_ticket','bnd_deal','bnd_settlement','bnd_cash','bnd_cashsum') -- put your table names here
--
declare MainCur cursor FAST_FORWARD for
select tablename
    from @tb_list;
open MainCur;
fetch next from MainCur into @TABLE_NAME;
while @@fetch_status = 0
begin
    --
    exec ('IF OBJECT_ID (''[' + @TABLE_NAME + '_ChangeTracking]'', ''TR'') IS NOT NULL DROP TRIGGER [' + @TABLE_NAME + '_ChangeTracking]');
    --
    fetch next from MainCur into @TABLE_NAME;
end
close MainCur; deallocate MainCur;
--
set nocount off