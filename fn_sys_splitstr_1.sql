CREATE FUNCTION fn_sys_splitstr_1
(
	@RowData nvarchar(4000)
)  
RETURNS @RtnValue table 
(
	Id int identity(1,1),
	Data varchar(30)
) 
AS  
BEGIN 
	Declare @Cnt int,@SplitOn varchar(1);
	Set @Cnt = 1;
  Set @SplitOn = ',';

	While (Charindex(@SplitOn,@RowData)>0)
	Begin
		Insert Into @RtnValue (data)
		Select 
			Data = ltrim(rtrim(Substring(@RowData,1,Charindex(@SplitOn,@RowData)-1)));

		Set @RowData = Substring(@RowData,Charindex(@SplitOn,@RowData)+1,len(@RowData));
		Set @Cnt = @Cnt + 1;
	End;
	
	Insert Into @RtnValue (data)
	Select Data = ltrim(rtrim(@RowData));

	Return;
END
