if object_id('fn_table_faust') is not null
    drop function fn_table_faust
go
create function [dbo].[fn_table_faust](
@table varchar(100))
returns @sql table(s nvarchar(2000) collate database_default, id int identity) as
begin
    --
    declare @pkname nvarchar(128),@fkname nvarchar(128),@dfname nvarchar(128),@cnt int,@ftable varchar(100),
            @column_limit int,@column_name nvarchar(128),@columns nvarchar(1024),@column_default nvarchar(4000);
    --remove foreign keys
	declare MainCur cursor FAST_FORWARD for
    select distinct t1.CONSTRAINT_NAME
      from INFORMATION_SCHEMA.KEY_COLUMN_USAGE t1, INFORMATION_SCHEMA.TABLE_CONSTRAINTS t2
     where t2.TABLE_CATALOG = t1.TABLE_CATALOG
       and t2.TABLE_SCHEMA = t1.TABLE_SCHEMA
       and t2.TABLE_NAME = t1.TABLE_NAME
       and t2.CONSTRAINT_NAME = t1.CONSTRAINT_NAME
       and t1.TABLE_NAME = @table
       and CONSTRAINT_TYPE = 'FOREIGN KEY';
	open MainCur;
	fetch next from MainCur into @fkname;
	while @@fetch_status = 0
	begin
		--
		insert into @sql(s) values (N'IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N''[' + @fkname + ']'') AND type = ''F'')');
		insert into @sql(s) values (N'ALTER TABLE [' + @table + '] DROP CONSTRAINT [' + @fkname + ']');
		insert into @sql(s) values (N'GO');
		--
		fetch next from MainCur into @fkname;
	end
	--
	close MainCur; deallocate MainCur;
    --remove default constrains
	declare MainCur cursor FAST_FORWARD for
    select t2.name
      from sysobjects t1, sysobjects t2
     where t1.id = t2.parent_obj
       and t1.xtype = 'U'
       and t2.xtype = 'D'
       and t1.name = @table;
    open MainCur;
	fetch next from MainCur into @dfname;
	while @@fetch_status = 0
	begin
		--
		insert into @sql(s) values (N'IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N''[dbo].[' + @dfname + ']'') AND type = ''D'')');
		insert into @sql(s) values (N'BEGIN');
		insert into @sql(s) values (N'IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N''[' + @dfname + ']'') AND type = ''D'')');
		insert into @sql(s) values (N'BEGIN');
		insert into @sql(s) values (N'ALTER TABLE [' + @table + '] DROP CONSTRAINT [' + @dfname + ']');
		insert into @sql(s) values (N'END');
		insert into @sql(s) values (N'');
		insert into @sql(s) values (N'');
		insert into @sql(s) values (N'END');
		insert into @sql(s) values (N'GO');
		--
		fetch next from MainCur into @dfname;
	end
	--
	close MainCur; deallocate MainCur;
    --remove table
    insert into @sql(s) values (N'IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N''[' + @table + ']'') AND OBJECTPROPERTY(id, N''IsUserTable'') = 1)');
    insert into @sql(s) values (N'DROP TABLE [' + @table +']');
    insert into @sql(s) values (N'GO');
    insert into @sql(s) values (N'SET ANSI_NULLS ON');
    insert into @sql(s) values (N'GO');
    insert into @sql(s) values (N'SET QUOTED_IDENTIFIER ON');
    insert into @sql(s) values (N'GO');
    insert into @sql(s) values (N'SET ANSI_PADDING ON');
    insert into @sql(s) values (N'GO');
    insert into @sql(s) values (N'IF NOT EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N''[' + @table + ']'') AND OBJECTPROPERTY(id, N''IsUserTable'') = 1)');
    insert into @sql(s) values (N'BEGIN');
    -- create statement
    insert into @sql(s) values (N'CREATE TABLE [' + @table + '](');
    -- column list
    select @column_limit = count(1) + 1
      from INFORMATION_SCHEMA.columns
     where table_name = @table;
    
    insert into @sql(s)
    select N'    [' + column_name + '] [' + data_type + ']' +
           case
                when data_type = 'numeric'
                then coalesce('(' + cast(NUMERIC_PRECISION as varchar) + ', ' + cast(NUMERIC_SCALE as varchar) + ')', '')
                else coalesce('(' + cast(character_maximum_length as varchar) + ')', '')
           end + ' ' +
           case
                when exists (select id
                               from syscolumns
                              where object_name(id) = @table
                                and name = column_name
                                and columnproperty(id, name, 'IsIdentity') = 1)
                then 'IDENTITY(' + cast(ident_seed(@table) as varchar) + ',' + cast(ident_incr(@table) as varchar) + ')'
                else ''
           end +
           case
                when IS_NULLABLE = 'No' then 'NOT '
                else ''
           --end) + 'NULL ' + coalesce('DEFAULT ' + COLUMN_DEFAULT, '') + ','
           end + 'NULL,'
      from information_schema.columns
     where table_name = @table order by ordinal_position;
    -- primary key
    select @pkname = CONSTRAINT_NAME
      from INFORMATION_SCHEMA.TABLE_CONSTRAINTS
     where TABLE_NAME = @table
       and CONSTRAINT_TYPE = 'PRIMARY KEY';
    if (@pkname is not null)
    begin
        insert into @sql(s) values (N' CONSTRAINT [PK_' + upper(@table) + '] PRIMARY KEY CLUSTERED ');
        insert into @sql(s) values (N'(');
        insert into @sql(s)
        select N'    [' + COLUMN_NAME + '] ASC,'
          from INFORMATION_SCHEMA.KEY_COLUMN_USAGE
         where CONSTRAINT_NAME = @pkname order by ORDINAL_POSITION;
        -- remove trailing comma
        update @sql
           set s = left(s, len(s) - 1)
         where id = @@identity;
        insert into @sql(s) values (N')WITH FILLFACTOR = 90 ON [PRIMARY]');
    end
    else
    begin
        -- remove trailing comma
        update @sql
           set s = left(s, len(s) - 1)
         where id = @@identity;
    end
    -- closing bracket
    insert into @sql(s) values (N') ON [PRIMARY]');
    insert into @sql(s) values (N'END');
    insert into @sql(s) values (N'GO');
    insert into @sql(s) values (N'SET ANSI_PADDING OFF');
    insert into @sql(s) values (N'GO');
    --append indexs
	declare MainCur cursor FAST_FORWARD for
    select i.name
      from sysobjects o
           join sysindexes i on i.id = o.id
     where i.indid between 1 and 254
       and indexproperty(o.id, i.name, 'IsStatistics') = 0
       and indexproperty(o.id, i.name, 'IsHypothetical') = 0
       and indexproperty(o.id, i.name, 'IsClustered') = 0
       and o.name = @table;
	open MainCur;
	fetch next from MainCur into @fkname;
	while @@fetch_status = 0
	begin
		--
		insert into @sql(s) values (N'IF NOT EXISTS (SELECT * FROM dbo.sysindexes WHERE id = OBJECT_ID(N''[' + @table + ']'') AND name = N''' + @fkname + ''')');
		insert into @sql(s) values (N'CREATE NONCLUSTERED INDEX [' + @fkname + '] ON [' + @table + '] ');
		insert into @sql(s) values (N'(');
		--
        insert into @sql(s)
        select N'   [' + c.name + '] ASC,'
          from sysobjects o
               join sysindexes i on i.id = o.id
               join sysindexkeys ik on ik.id = i.id and ik.indid = i.indid
               join syscolumns c on c.id = ik.id and c.colid = ik.colid
         where i.indid between 1 and 254
           and indexproperty(o.id, i.name, 'IsStatistics') = 0
           and indexproperty(o.id, i.name, 'IsHypothetical') = 0
           and indexproperty(o.id, i.name, 'IsClustered') = 0
           and o.name = @table
           and i.name = @fkname;
        -- remove trailing comma
        update @sql
           set s = left(s, len(s) - 1)
         where id = @@identity;
		--
		insert into @sql(s) values (N')WITH FILLFACTOR = 90 ON [PRIMARY]');
		insert into @sql(s) values (N'GO');
		--
		fetch next from MainCur into @fkname;
	end
	--
	close MainCur; deallocate MainCur;
    --append comments
    /*
    ---column
    set @cnt = 1;
    while @cnt < @column_limit
    begin
        --get column name
        select @column_name = column_name
          from information_schema.columns
         where table_name = @table and ordinal_position = @cnt;
        --
        if exists(select * from fn_listextendedproperty(null, 'schema', 'dbo', 'table', @table, 'column', @column_name) where name = 'MS_Description')
        begin
            insert into @sql(s) values (N'IF NOT EXISTS (SELECT * FROM ::fn_listextendedproperty(null, N''schema'', N''dbo'', N''table'',N''' + @table + ''', N''column'', N''' + @column_name + '''))');
            insert into @sql(s)
            select N'EXEC dbo.sp_addextendedproperty @name=N''MS_Description'', @value=N''' + cast(value as nvarchar(200)) + ''' , @level0type=N''USER'', @level0name=N''dbo'', @level1type=N''TABLE'', @level1name=N''' + @table + ''', @level2type=N''COLUMN'', @level2name=N''' + @column_name + ''''
              from fn_listextendedproperty(null, 'schema', 'dbo', 'table', @table, 'column', @column_name)
             where name = 'MS_Description';
            insert into @sql(s) values (N'GO');
        end
        --
        select @cnt = @cnt + 1;
    end
    ---table
    if exists(select * from fn_listextendedproperty(null, 'schema', 'dbo', 'table', @table, default, default) where name = 'MS_Description')
    begin
        insert into @sql(s) values (N'IF NOT EXISTS (SELECT * FROM ::fn_listextendedproperty(null, N''schema'', N''dbo'', N''table'',N''' + @table + ''', null, null))');
        insert into @sql(s)
        select N'EXEC dbo.sp_addextendedproperty @name=N''MS_Description'', @value=N''' + cast(value as nvarchar(200)) + ''' , @level0type=N''USER'', @level0name=N''dbo'', @level1type=N''TABLE'', @level1name=N''' + @table + ''''
          from fn_listextendedproperty(null, 'schema', 'dbo', 'table', @table, default, default)
         where name = 'MS_Description';
        insert into @sql(s) values (N'GO');
    end
    */
    --append foreign keys
	declare MainCur cursor FAST_FORWARD for
    select t1.CONSTRAINT_NAME, max(t1.COLUMN_NAME)
      from INFORMATION_SCHEMA.KEY_COLUMN_USAGE t1, INFORMATION_SCHEMA.TABLE_CONSTRAINTS t2
     where t2.TABLE_CATALOG = t1.TABLE_CATALOG
       and t2.TABLE_SCHEMA = t1.TABLE_SCHEMA
       and t2.TABLE_NAME = t1.TABLE_NAME
       and t2.CONSTRAINT_NAME = t1.CONSTRAINT_NAME
       and t1.TABLE_NAME = @table
       and CONSTRAINT_TYPE = 'FOREIGN KEY'
     group by t1.CONSTRAINT_NAME;
	open MainCur;
	fetch next from MainCur into @fkname,@column_name;
	while @@fetch_status = 0
	begin
		--get columns
		set @columns = N'';
		select @columns = coalesce(@columns + ', ', '') + N'[' + COLUMN_NAME + ']'
          from INFORMATION_SCHEMA.KEY_COLUMN_USAGE t1, INFORMATION_SCHEMA.TABLE_CONSTRAINTS t2
         where t2.TABLE_CATALOG = t1.TABLE_CATALOG
           and t2.TABLE_SCHEMA = t1.TABLE_SCHEMA
           and t2.TABLE_NAME = t1.TABLE_NAME
           and t2.CONSTRAINT_NAME = t1.CONSTRAINT_NAME
           and t1.TABLE_NAME = @table
           and t1.CONSTRAINT_NAME = @fkname
           and CONSTRAINT_TYPE = 'FOREIGN KEY'
         order by ORDINAL_POSITION;
        select @columns = right(@columns, len(@columns) - 2);
        --get referenced table name
        select @ftable = r.Referenced_Object_name
          from (select Referenced_Column_Name = c.name,
                       Referenced_Object_name = o.name,
                       f.constid
                  from sysforeignkeys f, sysobjects o, syscolumns c
                 where f.rkeyid = o.id and c.id = o.id and c.colid = f.rkey) r,
               (select referencing_column_Name = c.name,
                       Referencing_Object_name = o.name,
                       f.constid
                  from sysforeignkeys f, sysobjects o, syscolumns c
                 where f.fkeyid = o.id and c.id = o.id and c.colid = f.fkey) f
         where r.Referenced_Column_Name = f.referencing_column_Name
           and r.constid = f.constid
           and f.Referencing_Object_name = @table
           and f.referencing_column_Name = @column_name;
   	    --
		insert into @sql(s) values (N'IF NOT EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N''[' + @fkname + ']'') AND type = ''F'')');
		insert into @sql(s) values (N'ALTER TABLE [' + @table + ']  WITH NOCHECK ADD  CONSTRAINT [' + @fkname + '] FOREIGN KEY(' + @columns + ')');
		insert into @sql(s) values (N'REFERENCES [' + @ftable + '] (' + @columns + ')');
		insert into @sql(s) values (N'NOT FOR REPLICATION');
		insert into @sql(s) values (N'GO');
		insert into @sql(s) values (N'IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N''[' + @fkname + ']'') AND type = ''F'')');
		insert into @sql(s) values (N'ALTER TABLE [' + @table + '] NOCHECK CONSTRAINT [' + @fkname + ']');
		insert into @sql(s) values (N'GO');
		--
		fetch next from MainCur into @fkname,@column_name;
	end
	--
	close MainCur; deallocate MainCur;
    --append default constrains
	declare MainCur cursor FAST_FORWARD for
    select t2.name,t3.name,t4.text from sysobjects t1, sysobjects t2, syscolumns t3, syscomments t4
     where t1.id = t2.parent_obj and t1.id = t3.id and t2.info = t3.colid and t2.id = t4.id and t1.xtype = 'U' and t2.xtype = 'D'
       and t1.name = @table;
    open MainCur;
	fetch next from MainCur into @dfname,@column_name,@column_default;
	while @@fetch_status = 0
	begin
		--
		insert into @sql(s) values (N'IF Not EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N''[dbo].[' + @dfname + ']'') AND type = ''D'')');
		insert into @sql(s) values (N'BEGIN');
		insert into @sql(s) values (N'IF NOT EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N''[' + @dfname + ']'') AND type = ''D'')');
		insert into @sql(s) values (N'BEGIN');
		insert into @sql(s) values (N'ALTER TABLE [' + @table + '] ADD  CONSTRAINT [' + @dfname + ']  DEFAULT ' + @column_default + ' FOR [' + @column_name + ']');
		insert into @sql(s) values (N'END');
		insert into @sql(s) values (N'');
		insert into @sql(s) values (N'');
		insert into @sql(s) values (N'END');
		insert into @sql(s) values (N'GO');
		--
		fetch next from MainCur into @dfname,@column_name,@column_default;
	end
    --
    return;
end
go

