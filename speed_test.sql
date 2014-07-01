DBCC DROPCLEANBUFFERS	WITH NO_INFOMSGS	-- Clears the data cache
DBCC FREEPROCCACHE	WITH NO_INFOMSGS	-- Clears the procedure cache
GO

SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @starttime DATETIME
SELECT  @starttime = GetDate()

DECLARE @Counter INT
SELECT  @Counter = 0

DECLARE @Iterations INT
SELECT  @Iterations = 100  --Set to desired number of iterations

DECLARE @JUNK INT
DECLARE @ProfileID INT
SELECT @ProfileID

WHILE @Counter < @Iterations
BEGIN
	DBCC DROPCLEANBUFFERS	WITH NO_INFOMSGS	-- Clears the data cache

	--*********************************************************
	SELECT TOP 1 * FROM bnd_ticket;
	--********************************************************* 
        
	SELECT @Counter = @Counter + 1
        
END  --While loop
        
SELECT DateDiff(ms, @starttime, GetDate()) --Display elapsed Milliseconds 