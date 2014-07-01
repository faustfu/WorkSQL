--create index
create nonclustered index stk_mp_i1 on stk_mp(stkno_,sno_,date_);
--drop index
drop index stk_mp.stk_mp_i1;
--get all table row count
SELECT A.name "TableName", B.rowcnt "RowCount"
  FROM sysobjects A, sysindexes B
 WHERE A.id = b.id AND A.type = 'u' AND indid < 2
 and A.name like 'bnd%'
 order by A.name;
--get table column definition
SELECT case data_type 
       when 'varchar' then column_name+' varchar('+LTRIM(STR(character_maximum_length))+'),'
       when 'int' then column_name+' int,'
       when 'datetime' then column_name+' datetime,'
       when 'numeric' then column_name+' numeric('+LTRIM(STR(numeric_precision))+','+LTRIM(STR(numeric_scale))+'),'
       when 'bit' then column_name+' bit,'
       when 'tinyint' then column_name+' tinyint,'
       when 'char' then column_name+' char('+LTRIM(STR(character_maximum_length))+'),'
       else 'unknown type'
       end
  FROM INFORMATION_SCHEMA.COLUMNS
 WHERE TABLE_NAME = UPPER ('bnd_bdeal')
ORDER BY ORDINAL_POSITION
--get table's PK
select  a.name from syscolumns a
 inner join sysindexkeys b on a.id=b.id and a.colid=b.colid
 inner join  sysindexes c on b.id=c.id and b.indid=c.indid
 inner join sysobjects  d on c.id=d.parent_obj  and d.xtype='PK' and c.name=d.name
 inner join sysobjects e on a.id=e.id
 where e.name='bnd_main';
--get table columns
SELECT
    a.TABLE_NAME                as 表格名稱,
    b.COLUMN_NAME               as 欄位名稱,
    b.DATA_TYPE                 as 資料型別,
    case b.data_type when 'numeric' then ltrim(str(b.numeric_precision)) when 'decimal' then ltrim(str(b.numeric_precision)) else b.CHARACTER_MAXIMUM_LENGTH end as 最大長度,
    b.COLUMN_DEFAULT            as 預設值,
    b.IS_NULLABLE               as 允許空值
FROM
    INFORMATION_SCHEMA.TABLES  a
    LEFT JOIN INFORMATION_SCHEMA.COLUMNS b ON ( a.TABLE_NAME=b.TABLE_NAME )
WHERE
    a.TABLE_TYPE='BASE TABLE'
    AND a.TABLE_NAME = 'pos_user'
    --AND b.COLUMN_NAME like '%fee_ind%'
ORDER BY
    a.TABLE_NAME, ordinal_position;
--get sp list
SELECT xtype,
       name
  FROM sysobjects
 WHERE xtype IN ('P', 'TF', 'FN')
 ORDER BY xtype, name;
--get tr list
select b.Name as TableName,
       a.name as TriggerName
  from sysobjects a,
       sysobjects b
 where a.xtype = 'TR'
   and a.parent_obj = b.id;