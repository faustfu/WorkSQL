if object_id('faust_log_01') is not null
  drop table faust_log_01
go
create table faust_log_01(
Id           int identity(1,1),
LogTime      datetime not null default getdate(),
LogContent   ntext not null)
go
alter table faust_log_01 add constraint PK_FAUST_LOG_01 primary key (Id)
go

