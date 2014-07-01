IF OBJECT_ID('fn_sys_splitstr_2') IS NOT NULL
    DROP FUNCTION fn_sys_splitstr_2
GO
CREATE FUNCTION dbo.fn_sys_splitstr_2(
@list NTEXT,
@delim NVARCHAR(10) = ',')
RETURNS @t TABLE(Id INT IDENTITY(1,1),STR NVARCHAR(4000),Remark NVARCHAR(10)) AS
BEGIN
  DECLARE @slices TABLE(
    slice NVARCHAR(4000),
    Remark NVARCHAR(10)
  );
  
  DECLARE @slice NVARCHAR(4000),
          @textpos INT,
          @maxlen INT,
          @delimLen INT,
          @stoppos INT,
          @delimpos INT;
  
  SELECT @delimLen = LEN(@delim);
  SELECT @textpos = 1,
         @maxlen = 4000 - @delimLen*2; --It is usually equal to 3998.
  
  WHILE DATALENGTH(@list) / 2 - (@textpos - 1) >= @maxlen
  BEGIN
    --read a slice
    SELECT @slice = SUBSTRING(@list, @textpos, @maxlen);
    --find the position of the final delim
    SELECT @delimpos = ISNULL(CHARINDEX(REVERSE(@delim), REVERSE(@slice)),0);
    IF @delimpos >0
    BEGIN
      SELECT @stoppos = @maxlen - @delimpos;
      --save this slice
      INSERT @slices(slice,Remark) VALUES (@delim + LEFT(@slice, @stoppos) + @delim,'');
      --next slice
      SELECT @textpos = @textpos - 1 + @stoppos + @delimLen; -- On the other side of the comma.
    END
    ELSE
    BEGIN
      SELECT @textpos = DATALENGTH(@list) / 2 + 1; --end of loop
    END;
  END
  
  INSERT @slices(slice,Remark)
  VALUES (@delim + SUBSTRING(@list, @textpos, @maxlen) + @delim,'');
  
  INSERT @t(STR)
  SELECT STR
    FROM (SELECT STR = LTRIM(RTRIM(SUBSTRING(s.slice, n.Number + @delimLen, CHARINDEX(@delim, s.slice, n.Number + @delimLen) - n.Number - @delimLen)))
            FROM Numbers n
                 JOIN @slices s
                   ON n.Number <= LEN(s.slice) - @delimLen
                  AND SUBSTRING(s.slice, n.Number, @delimLen) = @delim) AS x;
  
  RETURN;
END