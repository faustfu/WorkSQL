if object_id('sp_grep_faust') is not null
    drop procedure sp_grep_faust
go
create procedure sp_grep_faust
(
@object varchar(255),
@ext1 varchar(255) = null,
@ext2 varchar(255) = null,
@ext3 varchar(255) = null
) as
--declare
declare @TempText table(
type nvarchar(30),
name nvarchar(255)
);
declare @tb table(
type nvarchar(30),
name nvarchar(255),
Lineid int,
Text nvarchar(255)
);
declare @my_type nvarchar(30),
        @my_name nvarchar(255);
declare @ext1_str varchar(255),
        @ext2_str varchar(255),
        @ext3_str varchar(255);
select @ext1_str = isnull(@ext1,''), @ext2_str = isnull(@ext2,''), @ext3_str = isnull(@ext3,'');
--get the objects that have key words
insert into @TempText
select distinct
       'type' = case type
                     when 'FN' then 'Scalar function'
                     when 'IF' then 'Inlined table-function'
                     when 'P' then 'Stored procedure'
                     when 'TF' then 'Table function'
                     when 'TR' then 'Trigger'
                     when 'V' then 'View'
                end,
       o.[name]
  from dbo.sysobjects o(NOLOCK)
 inner join dbo.syscomments c(NOLOCK) on o.id = c.id
 where 1 = 1
   and c.text like '%' + @object + '%'
   and c.text like '%' + @ext1_str + '%'
   and c.text like '%' + @ext2_str + '%'
   and c.text like '%' + @ext3_str + '%';
--
declare ms_crs_syscom1 cursor local for
select type, name from @TempText order by type, name for read only;
open ms_crs_syscom1;
fetch next from ms_crs_syscom1 into @my_type, @my_name;
while @@fetch_status >= 0
begin
    insert into @tb
    select @my_type, @my_name, t.Lineid, t.Text
      from fn_helptext_faust(@my_name, null) t
     where 1 = 1
       and t.Text like '%' + @object + '%'
       and t.Text like '%' + @ext1_str + '%'
       and t.Text like '%' + @ext2_str + '%'
       and t.Text like '%' + @ext3_str + '%';
    --
    fetch next from ms_crs_syscom1 into @my_type, @my_name;
end
close ms_crs_syscom1;
deallocate ms_crs_syscom1;
--display
declare ms_crs_syscom2 cursor local for
select type, name from @tb group by type, name for read only;
open ms_crs_syscom2;
fetch next from ms_crs_syscom2 into @my_type, @my_name;
while @@fetch_status >= 0
begin
    select @my_type, @my_name, t.Lineid, t.Text
      from @tb t
     where 1 = 1
       and t.type = @my_type
       and t.name = @my_name;
    --
    fetch next from ms_crs_syscom2 into @my_type, @my_name;
end
close ms_crs_syscom2;
deallocate ms_crs_syscom2;
--
--select * from @tb;
go

