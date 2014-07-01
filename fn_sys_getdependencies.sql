if object_id('fn_sys_getdependencies') is not null
    drop function fn_sys_getdependencies
go
--declare
create function fn_sys_getdependencies(
    @EntityId int,
    @Level int
) returns @tb table
(
    level_ int,
    referencing_id int,   
    referencing_name nvarchar(128),
    referenced_id int
)

/*
е\пр: get dependencies
*/
as
begin
    --
    declare @ChildId int,@Count int,@CurrentLevel int,@RowCnt int;
    declare @tb_tmp table (
        sn_ int identity(1,1),
        referencing_id int,
        referencing_name nvarchar(128),
        referenced_id int
    );
    --initial
    select @Count = 1,@CurrentLevel = isnull(@Level,0) + 1;
    --get children
    insert into @tb_tmp
    select d.referencing_id,o.name,d.referenced_id
      from sys.sql_expression_dependencies d
     inner join sys.sysobjects o on d.referencing_id = o.id
     where d.referenced_id=@EntityId;
    --
    set @RowCnt = @@rowcount;
    --
    while @Count <= @RowCnt
    begin
        --get the child id
        select @ChildId = referencing_id from @tb_tmp where sn_ = @Count;
        --insert the child record
        insert into @tb
        select @CurrentLevel,referencing_id,referencing_name,referenced_id
          from @tb_tmp
         where referencing_id=@ChildId;
        --get grandchildren
        insert into @tb
        select * from fn_sys_getdependencies(@ChildId,@CurrentLevel);
        --
        set @Count = @Count + 1;
    end;
    --select * from @tb;
    return;
end
go

