if object_id('sp_help_db_indexes') is not null
    drop procedure sp_help_db_indexes
go

CREATE procedure sp_help_db_indexes
AS
declare @empty varchar(1)
select @empty = ''

-- 35 is the lenght of the name field of the master.dbo.spt_values table
declare @IgnoreDuplicateKeys varchar(35),
        @Unique varchar(35),
        @IgnoreDuplicateRows varchar(35),
        @Clustered varchar(35),
        @Hypotethical varchar(35),
        @Statistics varchar(35),
        @PrimaryKey varchar(35),
        @UniqueKey varchar(35),
        @AutoCreate varchar(35),
        @StatsNoRecompute varchar(35);

select @IgnoreDuplicateKeys = name from master.dbo.spt_values 
  where type = 'I' and number = 1 --ignore duplicate keys
select @Unique = name from master.dbo.spt_values 
  where type = 'I' and number = 2 --unique
select @IgnoreDuplicateRows = name from master.dbo.spt_values 
  where type = 'I' and number = 4 --ignore duplicate rows
select @Clustered = name from master.dbo.spt_values 
  where type = 'I' and number = 16 --clustered
select @Hypotethical = name from master.dbo.spt_values 
  where type = 'I' and number = 32 --hypotethical
select @Statistics = name from master.dbo.spt_values 
  where type = 'I' and number = 64 --statistics
select @PrimaryKey = name from master.dbo.spt_values 
  where type = 'I' and number = 2048 --primary key
select @UniqueKey = name from master.dbo.spt_values 
  where type = 'I' and number = 4096 --unique key
select @AutoCreate = name from master.dbo.spt_values 
  where type = 'I' and number = 8388608 --auto create
select @StatsNoRecompute = name from master.dbo.spt_values 
  where type = 'I' and number = 16777216 --stats no recompute
select o.name,
 i.name,
 'index description' = convert(varchar(210), --bits 16 off, 1, 2, 16777216 on
   case when (i.status & 16)<>0 then @Clustered else 'non'+@Clustered end
   + case when (i.status & 1)<>0 then ', '+@IgnoreDuplicateKeys else @empty end
   + case when (i.status & 2)<>0 then ', '+@Unique else @empty end
   + case when (i.status & 4)<>0 then ', '+@IgnoreDuplicateRows else @empty end
   + case when (i.status & 64)<>0 then ', '+@Statistics else
   case when (i.status & 32)<>0 then ', '+@Hypotethical else @empty end end
   + case when (i.status & 2048)<>0 then ', '+@PrimaryKey else @empty end
   + case when (i.status & 4096)<>0 then ', '+@UniqueKey else @empty end
   + case when (i.status & 8388608)<>0 then ', '+@AutoCreate else @empty end
   + case when (i.status & 16777216)<>0 then ', '+@StatsNoRecompute else @empty end),
 'index column 1' = index_col(o.name,indid, 1),
 'index column 2' = index_col(o.name,indid, 2),
 'index column 3' = index_col(o.name,indid, 3)
from sysindexes i, sysobjects o
where i.id = o.id and
   indid > 0 and indid < 255 --all the clustered (=1), non clusterd (>1 and <251), and text or image (=255) 
   and o.type = 'U' --user table
   --ignore the indexes for the autostat
   and (i.status & 64) = 0 --index with duplicates
   and (i.status & 8388608) = 0 --auto created index
   and (i.status & 16777216)= 0 --stats no recompute
   order by o.name