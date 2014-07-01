if object_id('sp_NextInSequence') is not null
    drop procedure sp_NextInSequence
go
create procedure [dbo].[sp_NextInSequence](
@SequenceName varchar(30) = 'Default',
@SkipCount bigint = 1) as
begin
    begin transaction;
    declare @NextInSequence bigint;
    if not exists (select CurrentValue
                     from SequenceTbl
                    where SequenceName = @SequenceName)
        insert
          into SequenceTbl(SequenceName,
                           CurrentValue)
        values (@SequenceName,
                0);
    select top 1 @NextInSequence = isnull(CurrentValue, 0) + 1
      from SequenceTbl with(holdlock)
     where SequenceName = @SequenceName;
    update SequenceTbl with(UPDLOCK)
       set CurrentValue = @NextInSequence + (@SkipCount - 1)
     where SequenceName = @SequenceName;
    commit transaction;
    return @NextInSequence;
end;
go

