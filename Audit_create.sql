set nocount on

if not exists (select *
                 from INFORMATION_SCHEMA.TABLES
                where TABLE_NAME = 'Audit')
begin
    create table Audit(
    AuditID [int] identity (1, 1) not null,
    [Type] char(1),
    TableName varchar(128),
    PrimaryKeyField varchar(1000),
    PrimaryKeyValue varchar(1000),
    FieldName varchar(128),
    OldValue varchar(1000),
    NewValue varchar(1000),
    UpdateDate datetime default (getdate()),
    HostName varchar(128) default host_name(),
    UserName varchar(128))
    create nonclustered index idxAudit1 on Audit([Type], [TableName], [UpdateDate])
    create nonclustered index idxAudit2 on Audit([TableName], [Type], [UpdateDate])
end
go
alter table dbo.Audit add constraint AUDIT_PK primary key (AuditID)
go
declare @tb_list table(
    tablename varchar(30)
);
declare @sql varchar(8000),
        @sqllink varchar(1000),
        @TABLE_NAME sysname;
--
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
    select @sqllink = '1=1'
    select @sqllink = coalesce(@sqllink + ' and ', '') + 'm.[' + COLUMN_NAME + ']=l.[' + COLUMN_NAME +']'
      from INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk,
           INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
     where pk.TABLE_NAME = @TABLE_NAME
       and CONSTRAINT_TYPE = 'PRIMARY KEY'
       and c.TABLE_NAME = pk.TABLE_NAME
       and c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME;
    --
    exec ('IF OBJECT_ID (''[' + @TABLE_NAME + '_ChangeTracking]'', ''TR'') IS NOT NULL DROP TRIGGER [' + @TABLE_NAME + '_ChangeTracking]')
    select @sql = '
create trigger [' + @TABLE_NAME + '_ChangeTracking] on [' + @TABLE_NAME + '] for insert, update, delete
as
declare @bit int ,
@field int ,
@maxfield int ,
@char int ,
@fieldname varchar(128) ,
@TableName varchar(128) ,
@PKCols varchar(1000) ,
@sql varchar(2000),
@UpdateDate varchar(21) ,
@UserName varchar(128) ,
@Type char(1) ,
@PKFieldSelect varchar(1000),
@PKValueSelect varchar(1000),
@PKFieldJoin varchar(1000);
select @TableName = ''' + @TABLE_NAME + '''
-- date and user
select @UserName = system_user ,
@UpdateDate = convert(varchar(8), getdate(), 112) + '' '' + convert(varchar(12), getdate(), 114)
-- Get primary key columns for full outer join
select @PKCols = coalesce(@PKCols + '' and'', '' on'') + '' i.'' + c.COLUMN_NAME + '' = d.'' + c.COLUMN_NAME
  from INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,
       INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
 where pk.TABLE_NAME = @TableName
   and CONSTRAINT_TYPE = ''PRIMARY KEY''
   and c.TABLE_NAME = pk.TABLE_NAME
   and c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME
-- Get primary key fields select for insert
select @PKFieldSelect = coalesce(@PKFieldSelect+''+'','''') + '''''''' + COLUMN_NAME + ''''''''
  from INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,
       INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
 where pk.TABLE_NAME = @TableName
   and CONSTRAINT_TYPE = ''PRIMARY KEY''
   and c.TABLE_NAME = pk.TABLE_NAME
   and c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME;
select @PKValueSelect = coalesce(@PKValueSelect+''+'','''') + ''convert(varchar(100), coalesce(i.'' + COLUMN_NAME + '',d.'' + COLUMN_NAME + ''))''
  from INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,  
       INFORMATION_SCHEMA.KEY_COLUMN_USAGE c  
 where pk.TABLE_NAME = @TableName  
   and CONSTRAINT_TYPE = ''PRIMARY KEY''  
   and c.TABLE_NAME = pk.TABLE_NAME  
   and c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME;
if @PKCols is null
begin
    raiserror(''no PK on table %s'', 16, -1, @TableName)
    return
end
-- Action
if exists (select * from inserted)
    if exists (select * from deleted)
        select @Type = ''U''
    else
        select @Type = ''I''
else
    select @Type = ''D''
-- get list of columns
select m.* into #ins from ' + @TABLE_NAME + ' m join inserted l on ' + @sqllink + '
select m.* into #del from ' + @TABLE_NAME + ' m join deleted l on ' + @sqllink + '
--
select @field = 0, @maxfield = max(ORDINAL_POSITION) from INFORMATION_SCHEMA.COLUMNS
 where TABLE_NAME = @TableName
while @field < @maxfield
begin
    select @field = min(ORDINAL_POSITION) from INFORMATION_SCHEMA.COLUMNS
     where TABLE_NAME = @TableName
       and ORDINAL_POSITION > @field
    select @bit = (@field - 1 )% 8 + 1
    select @bit = power(2,@bit - 1)
    select @char = ((@field - 1) / 8) + 1
    if substring(COLUMNS_UPDATED(),@char, 1) & @bit > 0 or @Type in (''I'',''D'')
    begin
        select @fieldname = COLUMN_NAME from INFORMATION_SCHEMA.COLUMNS
         where TABLE_NAME = @TableName
           and ORDINAL_POSITION = @field
        select @sql = ''insert Audit (Type, TableName, PrimaryKeyField, PrimaryKeyValue, FieldName, OldValue, NewValue, UpdateDate, UserName)''
        select @sql = @sql + '' select '''''' + @Type + ''''''''
        select @sql = @sql + '','''''' + @TableName + ''''''''
        select @sql = @sql + '','' + @PKFieldSelect
        select @sql = @sql + '','' + @PKValueSelect
        select @sql = @sql + '','''''' + @fieldname + ''''''''
        select @sql = @sql + '',convert(varchar(1000),d.'' + @fieldname + '')''
        select @sql = @sql + '',convert(varchar(1000),i.'' + @fieldname + '')''
        select @sql = @sql + '','''''' + @UpdateDate + ''''''''
        select @sql = @sql + '','''''' + @UserName + ''''''''
        select @sql = @sql + '' from #ins i full outer join #del d''
        select @sql = @sql + @PKCols
        select @sql = @sql + '' where i.'' + @fieldname + '' <> d.'' + @fieldname
        select @sql = @sql + '' or (i.'' + @fieldname + '' is null and  d.'' + @fieldname + '' is not null)''
        select @sql = @sql + '' or (i.'' + @fieldname + '' is not null and  d.'' + @fieldname + '' is null)''
        exec (@sql)
    end
end
'
    --PRINT @sql;
    exec (@sql);
    --
    fetch next from MainCur into @TABLE_NAME;
end
close MainCur; deallocate MainCur;
--
set nocount off
