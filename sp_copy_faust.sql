IF OBJECT_ID('sp_copy_faust') IS NOT NULL
    DROP PROCEDURE sp_copy_faust
GO
CREATE PROC sp_copy_faust(
@Type TINYINT,--1:count, 2:select, 3:delete, 4:insert
@ColumnName VARCHAR(30),
@ColumnValue VARCHAR(60)
) AS
--declare
DECLARE
  @TableName VARCHAR(128),
  @ResultCount INT,
  @CountSQL NVARCHAR(256),
  @CountParam NVARCHAR(256),
  @SelectSQL NVARCHAR(256),
  @DeleteSQL NVARCHAR(256);

DECLARE @tmp_table TABLE(
  TableName VARCHAR(128),
  CountSQL NVARCHAR(256),
  ResultCount INT,
  SelectSQL NVARCHAR(256),
  DeleteSQL NVARCHAR(256)
);

--golbal var
SELECT @CountParam = '@ResultCountOut INT OUTPUT';

--query table
INSERT
  INTO @tmp_table
SELECT a.TABLE_NAME,
       'SELECT @ResultCountOut=COUNT(1) FROM '+a.Table_NAME+' WHERE '+b.COLUMN_NAME+' = '''+@ColumnValue+'''' AS CountSQL,
       0 AS ResultCount,
       'SELECT * FROM '+a.Table_NAME+' WHERE '+b.COLUMN_NAME+' = '''+@ColumnValue+'''' AS SelectSQL,
       'DELETE FROM '+a.Table_NAME+' WHERE '+b.COLUMN_NAME+' = '''+@ColumnValue+'''' AS DeleteSQL
  FROM INFORMATION_SCHEMA.TABLES a
  LEFT JOIN INFORMATION_SCHEMA.COLUMNS b
         ON (a.TABLE_NAME = b.TABLE_NAME)
 WHERE 1 = 1
   AND a.TABLE_TYPE = 'BASE TABLE'
   AND b.COLUMN_NAME = @ColumnName
 ORDER BY a.TABLE_NAME,
          b.COLUMN_NAME;
--
--loop and function dispatch
DECLARE cur_ CURSOR FOR SELECT TableName,CountSQL,SelectSQL,DeleteSQL FROM @tmp_table;
OPEN cur_
FETCH NEXT FROM cur_ INTO @TableName,@CountSQL,@SelectSQL,@DeleteSQL;
WHILE @@FETCH_STATUS = 0
BEGIN
  --begin of loop
  EXECUTE sp_executesql @CountSQL,@CountParam, @ResultCountOut=@ResultCount OUTPUT;
  
  UPDATE @tmp_table SET ResultCount=@ResultCount WHERE TableName=@TableName;

  IF @ResultCount<=0
    GOTO NEXT_LOOP;
  --save result
  IF @ResultCount >0
  BEGIN
    IF @Type = 2
    BEGIN
      EXEC (@SelectSQL);
    END;
    IF @Type = 3
    BEGIN
      EXEC (@DeleteSQL);
    END;
  END;
  --end of loop
  NEXT_LOOP:
    FETCH NEXT FROM cur_ INTO @TableName,@CountSQL,@SelectSQL,@DeleteSQL;
END;
CLOSE cur_;
DEALLOCATE cur_;

--output
IF @Type = 1
  SELECT TableName,ResultCount FROM @tmp_table WHERE ResultCount>0;
--exit
RETURN 0;
GO

