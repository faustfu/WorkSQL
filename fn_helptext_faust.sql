if object_id('fn_helptext_faust') is not null
    drop function fn_helptext_faust
go
create function [dbo].[fn_helptext_faust]
(
@objname nvarchar(776)
,@columnname sysname = null
)
returns 
@CommentText table 
(
LineId	int
 ,text  nvarchar(255) collate database_default
)
as
begin
declare @dbname sysname
,@BlankSpaceAdded   int
,@BasePos       int
,@CurrentPos    int
,@TextLength    int
,@LineId        int
,@AddOnLen      int
,@LFCR          int --lengths of line feed carriage return
,@DefinedLength int
,@SyscomText	nvarchar(4000)
,@Line          nvarchar(255)

select @DefinedLength = 255
select @BlankSpaceAdded = 0 
select @dbname = parsename(@objname,3)

if @dbname is not null and @dbname <> db_name()
        begin
                return
        end

if (object_id(@objname) is null)
        begin
		select @dbname = db_name()
                return
        end

-- If second parameter was given.
if ( @columnname is not null)
    begin
        -- Check if it is a table
        if (select count(*) from sysobjects where id = object_id(@objname) and xtype in ('S ','U ','TF'))=0
            begin
                return
            end
        -- check if it is a correct column name
        if ((select 'count'=count(*) from syscolumns where name = @columnname and id = object_id(@objname) and number = 0) =0)
            begin
                return
            end
    if ((select iscomputed from syscolumns where name = @columnname and id = object_id(@objname) and number = 0) = 0)
		begin
			return
		end

        declare ms_crs_syscom  cursor local
        for select text from syscomments where id = object_id(@objname) and encrypted = 0 and number =
                        (select colid from syscolumns where name = @columnname and id = object_id(@objname) and number = 0)
                        order by number,colid
        for read only

    end
else
    begin
        /*
        **  Find out how many lines of text are coming back,
        **  and return if there are none.
        */
        if (select count(*) from syscomments c, sysobjects o where o.xtype not in ('S', 'U')
            and o.id = c.id and o.id = object_id(@objname)) = 0
                begin
                        return
                end

        if (select count(*) from syscomments where id = object_id(@objname)
            and encrypted = 0) = 0
                begin
                        return
                end

        declare ms_crs_syscom  cursor local
        for select text from syscomments where id = object_id(@objname) and encrypted = 0
                order by number, colid
        for read only
    end

/*
**  Else get the text.
*/
select @LFCR = 2
select @LineId = 1


open ms_crs_syscom

fetch next from ms_crs_syscom into @SyscomText

while @@fetch_status >= 0
begin

    select  @BasePos    = 1
    select  @CurrentPos = 1
    select  @TextLength = len(@SyscomText)

    while @CurrentPos  != 0
    begin
        --Looking for end of line followed by carriage return
        select @CurrentPos =   charindex(char(13)+char(10), @SyscomText, @BasePos)

        --If carriage return found
        if @CurrentPos != 0
        begin
            /*If new value for @Lines length will be > then the
            **set length then insert current contents of @line
            **and proceed.
            */
            while (isnull(len(@Line),0) + @BlankSpaceAdded + @CurrentPos-@BasePos + @LFCR) > @DefinedLength
            begin
                select @AddOnLen = @DefinedLength-(isnull(len(@Line),0) + @BlankSpaceAdded)
                insert @CommentText values
                ( @LineId,
                  isnull(@Line, N'') + isnull(substring(@SyscomText, @BasePos, @AddOnLen), N''))
                select @Line = null, @LineId = @LineId + 1,
                       @BasePos = @BasePos + @AddOnLen, @BlankSpaceAdded = 0
            end
            select @Line    = isnull(@Line, N'') + isnull(substring(@SyscomText, @BasePos, @CurrentPos-@BasePos + @LFCR), N'')
            select @BasePos = @CurrentPos+2
            insert @CommentText values( @LineId, @Line )
            select @LineId = @LineId + 1
            select @Line = null
        end
        else
        --else carriage return not found
        begin
            if @BasePos <= @TextLength
            begin
                /*If new value for @Lines length will be > then the
                **defined length
                */
                while (isnull(len(@Line),0) + @BlankSpaceAdded + @TextLength-@BasePos+1 ) > @DefinedLength
                begin
                    select @AddOnLen = @DefinedLength - (isnull(len(@Line),0)  + @BlankSpaceAdded )
                    insert @CommentText values
                    ( @LineId,
                      isnull(@Line, N'') + isnull(substring(@SyscomText, @BasePos, @AddOnLen), N''))
                    select @Line = null, @LineId = @LineId + 1,
                        @BasePos = @BasePos + @AddOnLen, @BlankSpaceAdded = 0
                end
                select @Line = isnull(@Line, N'') + isnull(substring(@SyscomText, @BasePos, @TextLength-@BasePos+1 ), N'')
                if charindex(' ', @SyscomText, @TextLength+1 ) > 0
                begin
                    select @Line = @Line + ' ', @BlankSpaceAdded = 1
                end
                break
            end
        end
    end

	fetch next from ms_crs_syscom into @SyscomText
end

if @Line is not null
    insert @CommentText values( @LineId, @Line )

close  ms_crs_syscom
deallocate 	ms_crs_syscom
	
	return 
end
go

