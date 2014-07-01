if object_id('pr_import_source') is not null
    drop procedure pr_import_source
go
create proc pr_import_source(
@Branch tinyint,
@Version int
) as
--select @branch_=1,@version_=1
/*
功能:
*/
set nocount on;

--宣告變數
declare
  @err varchar(100),
  @RootDir varchar(100),
  @Path varchar(100),
  @FileName varchar(50),
  @FileExt varchar(10),
  @FullCMD varchar(400),
  @Line int;
declare @sub_dir table(
path_ varchar(100)
);
declare @type table(
file_ext_ varchar(10)
);
declare @file_list table(
path_ varchar(100),
file_name_ varchar(50)
);
create table #tmp_output1 (      
file_name_ varchar(50)
);
create table #tmp_output2 (     
line_ int identity,
content_ nvarchar(255)
);
--設定初值
set @err = '';
--
select @RootDir='d:\FinancialAcc';
insert into @sub_dir values('Ana');
insert into @sub_dir values('basic');
insert into @sub_dir values('BO');
insert into @sub_dir values('bond');
insert into @sub_dir values('bondo');
insert into @sub_dir values('dev_basic_bnd');
insert into @sub_dir values('dev_bnd');
insert into @sub_dir values('dev_bo_bnd');
insert into @sub_dir values('dev_fx_bnd');
insert into @sub_dir values('dev_manacc_bnd');
insert into @sub_dir values('dev_stb_bnd');
insert into @sub_dir values('DownLoadCredit');
insert into @sub_dir values('EForm');
insert into @sub_dir values('future');
insert into @sub_dir values('FX');
insert into @sub_dir values('IRS');
insert into @sub_dir values('jxapp');
insert into @sub_dir values('jxcom');
insert into @sub_dir values('JxCrypt');
insert into @sub_dir values('JxFileMan');
insert into @sub_dir values('jxmsg');
insert into @sub_dir values('JxPwd');
insert into @sub_dir values('JxShell');
insert into @sub_dir values('JxUser');
insert into @sub_dir values('main');
insert into @sub_dir values('ManAcc');
insert into @sub_dir values('MarketPrice');
insert into @sub_dir values('MF');
insert into @sub_dir values('MsgServer');
insert into @sub_dir values('PM');
insert into @sub_dir values('position');
insert into @sub_dir values('rptStock');
insert into @sub_dir values('stb');
insert into @sub_dir values('stkbrw');
insert into @sub_dir values('stkcust');
insert into @sub_dir values('stkdiv');
insert into @sub_dir values('stock');
insert into @sub_dir values('TD');
insert into @sub_dir values('WorkFlow');
--
insert into @type values('pas');
insert into @type values('dfm');

declare DirCur cursor FAST_FORWARD for
select path_ from @sub_dir;
open DirCur;
fetch next from DirCur into @Path;
while @@fetch_status = 0
begin
  --
  ----
  declare TypeCur cursor FAST_FORWARD for
  select file_ext_ from @type;
  open TypeCur;
  fetch next from TypeCur into @FileExt;
  while @@fetch_status = 0
  begin
    --
    --select @Path,@FileExt;
    select @FullCMD = 'dir '+@RootDir+'\'+@Path+'\*.'+@FileExt+' /ar /b';
    delete from #tmp_output1;
    insert #tmp_output1 exec master.dbo.xp_cmdshell @FullCMD;
    insert into @file_list select @Path, file_name_ from #tmp_output1;
    --if @@error > 0 goto STOP_TYPE;
    --next record
    NEXT_TYPE:
    fetch next from TypeCur into @FileExt;
    continue;
    
    --stop the procedure and rollback
    STOP_TYPE:
    close TypeCur; deallocate TypeCur;
    --get system error msg description
    if @@error <> 0
    begin
      select @err = msg.description
        from master.dbo.sysmessages msg
        join master.dbo.syslanguages lang on msg.msglangID = lang.msglangid
       where msg.error = @@error
         and lang.langid = 28;
    end;
    goto ERROR_EXIT;
  end
  close TypeCur; deallocate TypeCur;
  ----
  
  --if @@error > 0 goto STOP_DIR;
  --next record
  NEXT_DIR:
  fetch next from DirCur into @Path;
  continue;
  
  --stop the procedure and rollback
  STOP_DIR:
  close DirCur; deallocate DirCur;
  --get system error msg description
  if @@error <> 0
  begin
    select @err = msg.description
      from master.dbo.sysmessages msg
      join master.dbo.syslanguages lang on msg.msglangID = lang.msglangid
     where msg.error = @@error
       and lang.langid = 28;
  end;
  goto ERROR_EXIT;
end
close DirCur; deallocate DirCur;
--
delete from source_code where branch_ = @Branch and version_ = @Version;
delete from @file_list where file_name_ is null or file_name_ ='找不到檔案';
--
declare FileCur cursor FAST_FORWARD for
select path_,file_name_ from @file_list;
open FileCur;
fetch next from FileCur into @Path,@FileName;
while @@fetch_status = 0
begin
  --
  delete from #tmp_output2;
  select @FullCMD = 'type '+@RootDir+'\'+@Path+'\'+@FileName;
  insert #tmp_output2 exec master.dbo.xp_cmdshell @FullCMD;
  insert into source_code
  select @Branch, @Version, @Path, @FileName, t.rank_, isnull(t.content_,''), ''
    from (select rank_ = count(*),
                 a1.content_
            from #tmp_output2 a1,
                 #tmp_output2 a2
           where a1.line_ >= a2.line_
           group by a1.line_,
                    a1.content_) t
   order by t.rank_;
  --if @@error > 0 goto STOP_DIR;
  --next record
  NEXT_FILE:
  fetch next from FileCur into @Path,@FileName;
  continue;
  
  --stop the procedure and rollback
  STOP_FILE:
  close FileCur; deallocate FileCur;
  --get system error msg description
  if @@error <> 0
  begin
    select @err = msg.description
      from master.dbo.sysmessages msg
      join master.dbo.syslanguages lang on msg.msglangID = lang.msglangid
     where msg.error = @@error
       and lang.langid = 28;
  end;
  goto ERROR_EXIT;
end
close FileCur; deallocate FileCur;

--select * from @file_list;
--
NORMAL_EXIT:
drop table #tmp_output1,#tmp_output2;
--
ERROR_EXIT:
if @err <> ''
begin
  raiserror(@err,16,-1);
end;

return 0;
go

