if object_id('pr_cmn_transdata_2') is not null
    drop procedure pr_cmn_transdata_2
go
create proc [pr_cmn_transdata_2]
(
@Dt		datetime,		--作業日期
@UserName	varchar(20),	--使用者名稱
@FileNo int, --input file no
@InputData ntext, --input string
@ErrId		int		output,
@ErrMsg		nvarchar(500)	output
)
as
--declare tables
declare @RowValue table 
(
	Id int identity(1,1),
	Data nvarchar(4000)
);
declare @ColValue table 
(
	Id int identity(1,1),
	Data nvarchar(4000)
);
--declare variables
declare
  @ColNum int, @Cnt int, @RowSplit nvarchar(10), @ColSplit nvarchar(10),
  @FileType tinyint, @TableName varchar(30), @TitleNum int,
  @TargetType varchar(30), @TargetLen int, @Precision int, @Scale int,
  @TableSQL nvarchar(4000), @ColName varchar(10), @Id int,
  @Data nvarchar(4000), @ColSet nvarchar(4000), @InsertSQL nvarchar(4000),
  @RowPurfix varchar(10), @RowSurfix varchar(10),
  @CR char(1), @LF char(1);
--
set @ErrId = 0;
set @ErrMsg = '';
--

--create temp table:start
set @TableSQL = '';
set @ColSet = '';
--read table definition from cmn_imfile
select @TableName = table_name_, @TitleNum = title_num_, @FileType = file_type_,
       @RowPurfix = row_purfix_, @RowSurfix = row_surfix_
  from cmn_imfile where file_no_ = @FileNo;
if @TableName is null
begin
  set @ErrMsg = 'temp table name is empty!'; goto ERROR_EXIT;
end
if @FileType not in (1,3)
begin
  set @ErrMsg = 'file type=[' + @FileType + '] is not supported now!'; goto ERROR_EXIT;
end
--Table header
select @TableSQL = 'DROP TABLE ' + @TableName + ';CREATE TABLE ' + @TableName + '(Id INT IDENTITY(1,1)';
--parse row data
select @CR = char(13), @LF = char(10);
select @RowSplit = @CR + @LF;

insert into @RowValue(Data)
select isnull(s.STR,'') from dbo.fn_sys_splitstr_2(@InputData,@RowSplit) s order by s.Id;
--==debug start
--INSERT INTO faust_log_01 (LogContent) SELECT '['+Data+']' FROM @RowValue;
--GOTO NORMAL_EXIT;
--==debug end
--read column name from cmn_imfile_detail
set @Cnt = 1;
declare ColCur cursor FAST_FORWARD for
select target_type_,target_len_,precision_,scale_
  from cmn_imfile_detail where file_no_ = @FileNo order by col_no_ asc;
open ColCur;
fetch next from ColCur into @TargetType, @TargetLen, @Precision, @Scale;
while @@fetch_status = 0
begin
  --
  select @ColName = 'Col' + replace(str(@Cnt,2,0),' ','0');
  select @ColSet = @ColSet + @ColName + ',';
  if @TargetType = 1 --1:INT
    select @TableSQL = @TableSQL + ', ' + @ColName + ' INT'
  else if @TargetType = 2 --2:NUMERIC
    select @TableSQL = @TableSQL + ', ' + @ColName + ' NUMERIC(' + str(@Precision) + ',' + str(@Scale) + ')'
  else if @TargetType = 11 --11:VARCHAR
    select @TableSQL = @TableSQL + ', ' + @ColName + ' VARCHAR(' + str(@TargetLen) + ')'
  else if @TargetType = 21 --DATETIME
    select @TableSQL = @TableSQL + ', ' + @ColName + ' DATETIME'
  else if @TargetType = 31 --EMPTY
    select @TableSQL = @TableSQL + ', ' + @ColName + ' VARCHAR(1)'
  else
  begin
    close ColCur; deallocate ColCur;
    select @ErrMsg = 'target type=[' + replace(str(@TargetType),' ','') + '] is not supported now!'; goto ERROR_EXIT;
  end
  --next column
  select  @Cnt = @Cnt + 1;
  fetch next from ColCur into @TargetType, @TargetLen, @Precision, @Scale;
end
close ColCur;
deallocate ColCur;
select @ColNum = @Cnt - 1; --keep column number
--Table end
select @TableSQL = @TableSQL + ')';
select @ColSet = substring(@ColSet, 1 , len(@ColSet) - 1); --remove final comma
--
execute sp_executesql @TableSQL;
--==debug start
--INSERT INTO faust_log_01 (LogContent) VALUES (@TableSQL);
--==debug end
if @@error > 0
begin
  select @ErrMsg = msg.description
    from master.dbo.sysmessages msg
   inner join master.dbo.syslanguages lang
           on msg.msglangID = lang.msglangid
   where msg.error = @@error
     and lang.langid = 28;
  goto ERROR_EXIT;  
end;
--create temp table:end

--read row data by column:start
select @ColSplit = @RowSurfix + ',' + @RowPurfix;
declare RowCur cursor FAST_FORWARD for select Id,Data from @RowValue where Id > @TitleNum order by Id asc;
open RowCur;
fetch next from RowCur into @Id, @Data;
while @@fetch_status = 0
begin
  --skip empty data
  select @Data = replace(@Data,'　',' ');
  select @Data = rtrim(ltrim(@Data));
  if len(@Data) = 0 goto NEXT_ROW;
  if len(@RowPurfix) > 0
  begin
    select @Data = substring(@Data,len(@RowPurfix)+charindex(@RowPurfix,@Data,0),len(@Data)-len(@RowPurfix)-charindex(@RowPurfix,@Data,0)+1);
  end
  if len(@RowSurfix) > 0
  begin
    select @Data = substring(@Data,1,len(@Data)-charindex(reverse(@RowSurfix),reverse(@Data),0));
  end
  
  --parse col data from row data
  delete from @ColValue;
  insert into @ColValue(Data)
  select s.STR from dbo.fn_sys_splitstr_2(@Data,@ColSplit) s order by s.Id;
  --==debug start
  --INSERT INTO faust_log_01 (LogContent) values (@Data);
  --INSERT INTO faust_log_01 (LogContent) SELECT Data FROM @ColValue;
  --GOTO NEXT_ROW;
  --==debug end
  select @Cnt = count(1) from @ColValue;
  if @ColNum <> @Cnt
  begin
    close RowCur; deallocate RowCur;
    set @ErrMsg = str(@Id) + ':column number=[' + replace(str(@Cnt),' ','') + '][' + @Data + '] does not match the definition number=[' + replace(str(@ColNum),' ','') + ']!'; goto ERROR_EXIT;
  end
  --prepare insert SQL:start
  set @Cnt = 0;
  select @InsertSQL = 'INSERT INTO ' + @TableName + ' (' + @ColSet + ') VALUES (' ;
  declare ColCur cursor FAST_FORWARD for
  select target_type_,target_len_,precision_,scale_
    from cmn_imfile_detail where file_no_ = @FileNo order by col_no_ asc;
  open ColCur;
  fetch next from ColCur into @TargetType, @TargetLen, @Precision, @Scale;
  while @@fetch_status = 0
  begin
    --
    select @Data = Data from @ColValue where (Id-1) % @ColNum = @Cnt;
    --skip empty data
    select @Data = replace(@Data,'　',' '); --convert space
    select @Data = replace(replace(@Data,@CR,''),@LF,''); --remove carrage return
    select @Data = rtrim(ltrim(@Data));
    --
    if @TargetType in (1,2) --1:INT, 2:NUMERIC
    begin
      if len(@Data) = 0
        select @InsertSQL = @InsertSQL + '0,' --default=0
      else
      begin
        if isnumeric(@Data) = 1
          select @InsertSQL = @InsertSQL + @Data + ','
        else
          select @InsertSQL = @InsertSQL + '0,'; --Not a number=>0
      end;
    end
    else if @TargetType = 11 --11:VARCHAR
    begin
      --check string langth
      if len(@Data) <= @TargetLen
      begin
        select @Data =REPLACE(@Data,'''','''''');
        select @InsertSQL = @InsertSQL + '''' + @Data + ''',';
      end
      else
      begin
        close ColCur; deallocate ColCur;
        select @ErrMsg = 'Row=[' + replace(str(@Id),' ','') + '] Data=[' + @Data + '] length=[' + replace(str(len(@Data)),' ','') + '] is too long!'; goto ERROR_EXIT;        
      end;
    end
    else if @TargetType = 21 --21:DATETIME
      if len(@Data) = 0
        select @InsertSQL = @InsertSQL + '''1899/12/30'',' --default=1899/12/30
      else
        if isdate(@Data) = 1
          select @InsertSQL = @InsertSQL + '''' + @Data + ''','
        else
          select @InsertSQL = @InsertSQL + '''1899/12/30'',';
    else if @TargetType = 31 --31:EMPTY
      select @InsertSQL = @InsertSQL + ''''',';
    else
    begin
      close ColCur; deallocate ColCur;
      select @ErrMsg = 'target type=[' + replace(str(@TargetType),' ','') + '] is not supported now!'; goto ERROR_EXIT;
    end
    --next col
    select  @Cnt = @Cnt + 1;
    fetch next from ColCur into @TargetType, @TargetLen, @Precision, @Scale;
  end
  close ColCur;
  deallocate ColCur;
  select @InsertSQL = substring(@InsertSQL, 1 , len(@InsertSQL) - 1) + ')'; --remove final comma and append ')'
  --prepare insert SQL:end
  --==debug start
  --INSERT INTO faust_log_01 (LogContent) VALUES (@InsertSQL);
  --==debug end
  execute sp_executesql @InsertSQL; --insert row data to table
  if @@error > 0 goto STOP_DEAL;
  --next row
  NEXT_ROW:
  fetch next from RowCur into @Id, @Data;
  continue;
  STOP_DEAL:
  close RowCur; deallocate RowCur;
  --get system error msg description
  select @ErrMsg = msg.description
    from master.dbo.sysmessages msg
   inner join master.dbo.syslanguages lang
           on msg.msglangID = lang.msglangid
   where msg.error = @@error
     and lang.langid = 28;
  goto ERROR_EXIT;  
end
close RowCur;
deallocate RowCur;
--read row data by column:end
NORMAL_EXIT:
return 0;

ERROR_EXIT:
set @ErrId = 1;
return @@error;
go

