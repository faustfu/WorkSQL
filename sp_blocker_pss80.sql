if object_id('SequenceTbl') is not null
    drop table SequenceTbl
go
create table SequenceTbl(
SequenceName        varchar(30),
CurrentValue        bigint) on [PRIMARY]
go

