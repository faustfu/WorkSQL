IF OBJECT_ID('pr_cmn_transdata_1') IS NOT NULL
    DROP PROCEDURE pr_cmn_transdata_1
GO
CREATE   PROC pr_cmn_transdata_1
(
@FileNo INT, --input file no
@ColSet NVARCHAR(4000)
)
AS
--declare tables
DECLARE @ColValue TABLE 
(
	Id INT IDENTITY(1,1),
	Description VARCHAR(100)
);
DECLARE @ColSetTable TABLE 
(
	Id INT IDENTITY(1,1),
	Description VARCHAR(100)
);
--declare variables
DECLARE
  @TableName VARCHAR(30), @SelectSQL NVARCHAR(4000), @ColDesc VARCHAR(100),
  @ColName VARCHAR(10), @ColSeq INT, @Cnt INT, @IsExist INT;

--seperate @ColSet into @ColSetTable
IF @ColSet <> '*'
BEGIN
  INSERT INTO @ColSetTable(Description)
  SELECT s.STR FROM dbo.fn_sys_splitstr_2(@ColSet,',') s ORDER BY s.Id;
END;
--
SET @SelectSQL = '';
SELECT @SelectSQL = 'SELECT ';
--read table definition from cmn_imfile
SELECT @TableName = table_name_ FROM cmn_imfile WHERE file_no_ = @FileNo;
--get column set
IF @TableName IS NULL
  RETURN 0;
INSERT INTO @ColValue (Description)
SELECT col_description_ FROM cmn_imfile_detail WHERE file_no_ = @FileNo ORDER BY col_no_ ASC;
--
SET @Cnt = 1;
DECLARE ColCur CURSOR FAST_FORWARD FOR SELECT Description FROM @ColValue ORDER BY Id ASC;
OPEN ColCur;
FETCH NEXT FROM ColCur INTO @ColDesc;
WHILE @@FETCH_STATUS = 0
BEGIN
  --排除未選擇之欄位
  IF @ColSet <> '*'
  BEGIN
    SET @IsExist = 0;
    SELECT @IsExist = COUNT(1) FROM @ColSetTable WHERE Description = @ColDesc;
    IF @IsExist <=0
      GOTO NEXT_LOOP;
  END;
  SELECT @ColName = 'Col' + REPLACE(STR(@Cnt,2,0),' ','0');
  SELECT @SelectSQL = @SelectSQL + ' ' + @ColName + ' AS ' + @ColDesc + ',';
  --next column
  NEXT_LOOP:
  SELECT @Cnt = @Cnt + 1;
  FETCH NEXT FROM ColCur INTO @ColDesc;
END
CLOSE ColCur;
DEALLOCATE ColCur;
--
SELECT @SelectSQL = SUBSTRING(@SelectSQL, 1 , LEN(@SelectSQL) - 1) + ' FROM ' + @TableName + ' ORDER BY Id ASC';
EXECUTE sp_executesql @SelectSQL;
RETURN 0;
GO

